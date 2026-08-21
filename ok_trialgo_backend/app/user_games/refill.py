# =============================================================
# FICHIER : app/user_games/refill.py
# ROLE    : Logique pure de refill des vies (30 min/vie)
# =============================================================
#
# Algorithme (memes principes que regen stars cote Supabase) :
#   delta = floor((now - lives_last_refill) / 30min)
#   new_lives = min(lives + delta, max_lives)
#   new_last  = lives_last_refill + delta * 30min
#
# Le delta n'est applique que si new_lives > old (sinon on ne
# bouge pas le timestamp pour eviter de "perdre" du temps regen).
#
# Note : si lives == max_lives au depart, aucun refill ne s'applique.
# C'est intentionnel : pas besoin de "recharger" un compteur deja plein.
# =============================================================

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


# Constante metier : 30 minutes par vie regagnee.
# (cf decision user : standard mobile gaming).
LIFE_REFILL_INTERVAL = timedelta(minutes=30)


@dataclass(frozen=True)
class RefillResult:
    """Resultat du calcul de refill : nouvelles valeurs + flag."""
    # Vies apres refill.
    new_lives: int
    # Nouveau timestamp lives_last_refill.
    new_last_refill: datetime
    # Nombre de vies ajoutees (0 si pas de refill).
    lives_added: int
    # Si non None : temps en secondes avant la prochaine vie.
    seconds_to_next_life: int | None


def apply_refill(
    *,
    current_lives: int,
    max_lives: int,
    last_refill: datetime,
    now: datetime | None = None,
) -> RefillResult:
    """Calcule le refill applicable et retourne le nouvel etat.

    PURE : aucun IO, aucune DB. Testable a part.

    Parameters
    ----------
    current_lives, max_lives, last_refill
        Etat actuel issu de user_games.
    now
        Override pour tests (utilise UTC en prod).
    """
    if now is None:
        now = datetime.now(timezone.utc)

    # Si deja au max, pas de refill mais on ne bouge pas le timestamp
    # (sinon la prochaine perte de vie devrait re-attendre 30 min).
    if current_lives >= max_lives:
        return RefillResult(
            new_lives=current_lives,
            new_last_refill=last_refill,
            lives_added=0,
            seconds_to_next_life=None,
        )

    # Calcul du nombre de vies regagnees depuis last_refill.
    elapsed = now - last_refill
    # Si elapsed negatif (horloge serveur revenue en arriere), no-op.
    if elapsed.total_seconds() <= 0:
        return RefillResult(
            new_lives=current_lives,
            new_last_refill=last_refill,
            lives_added=0,
            seconds_to_next_life=int(LIFE_REFILL_INTERVAL.total_seconds()),
        )
    delta_lives = int(elapsed // LIFE_REFILL_INTERVAL)

    if delta_lives == 0:
        # Pas encore une vie complete. On calcule le temps restant.
        seconds_done = int(elapsed.total_seconds())
        seconds_to_next = (
            int(LIFE_REFILL_INTERVAL.total_seconds()) - seconds_done
        )
        return RefillResult(
            new_lives=current_lives,
            new_last_refill=last_refill,
            lives_added=0,
            seconds_to_next_life=max(0, seconds_to_next),
        )

    # On ajoute delta_lives, en clampant a max_lives.
    new_lives = min(current_lives + delta_lives, max_lives)
    actually_added = new_lives - current_lives
    # Le nouveau last_refill avance de actually_added * 30 min
    # (pas delta_lives, qui pourrait depasser le plafond).
    new_last = last_refill + LIFE_REFILL_INTERVAL * actually_added

    # Calcul temps avant prochaine vie (si pas au max).
    if new_lives < max_lives:
        elapsed_since_new = now - new_last
        seconds_done = int(elapsed_since_new.total_seconds())
        seconds_to_next = (
            int(LIFE_REFILL_INTERVAL.total_seconds()) - seconds_done
        )
        next_in = max(0, seconds_to_next)
    else:
        next_in = None

    return RefillResult(
        new_lives=new_lives,
        new_last_refill=new_last,
        lives_added=actually_added,
        seconds_to_next_life=next_in,
    )
