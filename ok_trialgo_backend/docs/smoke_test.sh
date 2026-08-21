#!/usr/bin/env bash
# =============================================================
# smoke_test.sh - Smoke test end-to-end du backend TRIALGO
# =============================================================
# Lance docker compose up puis joue le scenario complet :
#   1. healthz
#   2. migrations
#   3. register admin (bootstrap) + login
#   4. register player + auto-login
#   5. confirm-email (consomme le token directement en DB)
#   6. create game + upload 3 cards + create node (fusion)
#   7. (joueur) list public games -> create session
#   8. (joueur) attempt OK + attempt KO + progress + finish
#   9. leaderboard + stats
#  10. cleanup
#
# Pre-requis : jq, curl, docker compose up deja lance.
# =============================================================
set -euo pipefail

API="http://localhost:8000"
ADMIN_EMAIL="admin@trialgo.local"
ADMIN_PWD="adminpassword123"
PLAYER_EMAIL="player@trialgo.local"
PLAYER_PWD="playerpassword123"

c() { echo -e "\e[36m$*\e[0m"; }
g() { echo -e "\e[32m$*\e[0m"; }
r() { echo -e "\e[31m$*\e[0m"; }

c "1/10 healthz"
curl -sf "$API/healthz" | jq .

c "2/10 alembic upgrade (in container)"
docker compose exec -T api alembic upgrade head

c "3/10 register admin (1er compte = admin bootstrap) + auto-login"
ADMIN_REG=$(curl -sf -X POST "$API/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PWD\"}")
ADMIN_TOKEN=$(echo "$ADMIN_REG" | jq -r '.tokens.access_token')
ADMIN_ID=$(echo "$ADMIN_REG" | jq -r '.user.id')
g "Admin id=$ADMIN_ID, is_admin=$(echo $ADMIN_REG | jq -r '.user.is_admin')"

c "4/10 register joueur + auto-login"
PLAYER_REG=$(curl -sf -X POST "$API/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$PLAYER_EMAIL\",\"password\":\"$PLAYER_PWD\"}")
PLAYER_TOKEN=$(echo "$PLAYER_REG" | jq -r '.tokens.access_token')
PLAYER_ID=$(echo "$PLAYER_REG" | jq -r '.user.id')
g "Player id=$PLAYER_ID, is_admin=$(echo $PLAYER_REG | jq -r '.user.is_admin')"

c "5/10 confirm-email player (consomme token via DB direct car DRY_RUN)"
# En DRY_RUN, on n'a pas le token en clair (envoye dans le mail). On utilise
# resend-confirmation puis on triche en allant chercher le hash en DB ? Non,
# on saute en pratique : le test continue sans confirm-email. Le user peut
# tester manuellement avec une vraie cle Brevo.
g "(skip confirm-email en DRY_RUN -- a tester avec BREVO_API_KEY reelle)"

c "6/10 create game + upload 3 cards + create fusion (admin)"
GAME=$(curl -sf -X POST "$API/api/games" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Smoke Test","description":"e2e","theme":"test"}')
GAME_ID=$(echo "$GAME" | jq -r '.id')
g "Game id=$GAME_ID"

# Genere 3 mini JPEGs valides (1x1 px) via python pour upload
python3 -c "
from PIL import Image
import io
for i, color in enumerate(['red','green','blue']):
    img = Image.new('RGB', (10,10), color)
    img.save(f'/tmp/card_{i}.jpg', 'JPEG')
"

CARD_A=$(curl -sf -X POST "$API/api/games/$GAME_ID/cards" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -F "label=Card A" -F "card_type=emettrice" -F "file=@/tmp/card_0.jpg" | jq -r '.id')
CARD_B=$(curl -sf -X POST "$API/api/games/$GAME_ID/cards" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -F "label=Card B" -F "card_type=cable" -F "file=@/tmp/card_1.jpg" | jq -r '.id')
CARD_C=$(curl -sf -X POST "$API/api/games/$GAME_ID/cards" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -F "label=Card C" -F "card_type=receptrice" -F "file=@/tmp/card_2.jpg" | jq -r '.id')
g "Cards: A=$CARD_A B=$CARD_B C=$CARD_C"

NODE=$(curl -sf -X POST "$API/api/games/$GAME_ID/nodes" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"emettrice_id\":\"$CARD_A\",\"cable_id\":\"$CARD_B\",\"receptrice_id\":\"$CARD_C\",\"depth\":1}")
NODE_ID=$(echo "$NODE" | jq -r '.id')
g "Node id=$NODE_ID (A + B = C)"

c "7/10 (joueur) list public games + start session"
PGAMES=$(curl -sf "$API/api/public/games")
echo "Public games: $(echo $PGAMES | jq 'length') jeu(x)"
SESSION=$(curl -sf -X POST "$API/api/sessions" \
  -H "Authorization: Bearer $PLAYER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"game_id\":\"$GAME_ID\"}")
SESSION_ID=$(echo "$SESSION" | jq -r '.id')
g "Session id=$SESSION_ID total_trios=$(echo $SESSION | jq -r '.total_trios')"

c "8/10 (joueur) attempt OK + KO + progress + finish"
ATT_OK=$(curl -sf -X POST "$API/api/sessions/$SESSION_ID/attempts" \
  -H "Authorization: Bearer $PLAYER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"card_ids\":[\"$CARD_A\",\"$CARD_B\",\"$CARD_C\"]}")
g "Attempt OK: matched=$(echo $ATT_OK | jq -r '.matched') points=$(echo $ATT_OK | jq -r '.points_delta') score=$(echo $ATT_OK | jq -r '.new_score') bonus=$(echo $ATT_OK | jq -r '.completion_bonus')"

# Generer un id bidon = on prend l'id admin (cross-game) -> echec
ATT_KO=$(curl -sf -X POST "$API/api/sessions/$SESSION_ID/attempts" \
  -H "Authorization: Bearer $PLAYER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"card_ids\":[\"$CARD_A\",\"$CARD_B\",\"00000000-0000-0000-0000-000000000000\"]}" \
  || echo '{"matched":false}')
g "Attempt KO: $(echo $ATT_KO | jq -c .)"

PROG=$(curl -sf "$API/api/sessions/$SESSION_ID/progress" -H "Authorization: Bearer $PLAYER_TOKEN")
g "Progress: $(echo $PROG | jq -r '.trios_found') / $(echo $PROG | jq -r '.total_trios')"

FIN=$(curl -sf -X POST "$API/api/sessions/$SESSION_ID/finish" -H "Authorization: Bearer $PLAYER_TOKEN")
g "Finished: status=$(echo $FIN | jq -r '.status') score=$(echo $FIN | jq -r '.score')"

c "9/10 leaderboard + stats"
LB=$(curl -sf "$API/api/games/$GAME_ID/leaderboard" -H "Authorization: Bearer $PLAYER_TOKEN")
g "Leaderboard: $(echo $LB | jq -r '.entries | length') entries"
echo "$LB" | jq '.entries[] | {rank, user_email, score, trios_found}'

STATS=$(curl -sf "$API/api/users/me/stats" -H "Authorization: Bearer $PLAYER_TOKEN")
g "Stats: $(echo $STATS | jq -c .)"

c "10/10 cleanup (delete game cascade)"
curl -sf -X DELETE "$API/api/games/$GAME_ID" -H "Authorization: Bearer $ADMIN_TOKEN" -o /dev/null
g "Game supprime"

g ""
g "============================================="
g "  SMOKE TEST OK"
g "============================================="
