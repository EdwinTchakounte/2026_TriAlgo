# La vitrine MIXALGO

Le site public de `mixalgo.com`. Trois fichiers, aucune compilation, aucun
gestionnaire de paquets : ce dossier se recopie tel quel sur le serveur.

```
vitrine/
├── index.html          la page, autonome (HTML + CSS + donnees structurees)
├── scripts/vitrine.js  la scene 3D, la demonstration de fusion, l'appel a l'API
├── assets/             logo detoure, image de partage, favicon
├── robots.txt
├── sitemap.xml
└── outils/
    └── detourer_logo.py  regenere tout le contenu de assets/ depuis ok_logo.jpeg
```

---

## Le parti pris

**Un monde sombre unique, assume.** Pas de theme clair. Le logo est une lumiere
neon sur du noir ; le poser sur du blanc reviendrait a l'eteindre.

**La palette n'est pas inventee.** Elle est echantillonnee dans le logo lui meme :
le cyan `#00D8F0` en est la teinte dominante apres le blanc, l'ambre `#F0A800`
vient du mot « Mix », le bleu `#001878` des profondeurs du diamant, et la braise
`#F01800` de la fleche basse, seule couleur chaude saturee de tout le logo. Elle
est donc traitee comme telle sur la page : rarissime.

**La page est complete sans JavaScript.** Le hero, la regle, les distances, les
douze cartes du deck et la FAQ sont dans le HTML. Le script n'ajoute que du
relief : la scene WebGL, la transition de fusion, et le remplacement des cartes
de demonstration par les vraies images. Un robot d'indexation, un navigateur sans
WebGL et une API injoignable voient tous une page correcte.

---

## Le logo detoure

Le fichier source `ok_logo.jpeg` a un fond **noir opaque**. Pose tel quel, il
affiche un rectangle noir au milieu de la page.

Le detourage n'utilise pas un seuil de luminosite, qui couperait net les halos du
logo et laisserait un contour en patatoide visible sur tout fond clair. Il traite
l'image comme ce qu'elle est, une **lumiere additive** : l'opacite de chaque pixel
est son intensite lumineuse, et sa couleur est celle qu'il aurait sans le noir.

```
alpha = max(R, G, B)
RGB'  = RGB x 255 / alpha
```

Recompose sur du noir, le resultat est strictement identique a l'original. Sur
tout autre fond, le halo se comporte comme une vraie lumiere : il eclaircit ce
qu'il y a derriere au lieu de le salir.

```bash
python3 vitrine/outils/detourer_logo.py
```

Cela regenere **tout** le dossier `assets/` : deux largeurs de logo en WebP, un
PNG de repli, l'image de partage social au format impose par les reseaux, et la
favicon. Rien n'est retouche a la main, donc rien n'est a refaire si le logo change.

> Le script a besoin de `pillow` et `numpy`.

---

## Les cartes viennent de l'API

La grille du deck est remplie par `GET /api/public/games` puis
`GET /api/public/games/{id}/cards`, deux endpoints **sans authentification**
concus pour cet usage.

La page lit `thumb_url` en priorite, et retombe sur `image_url` quand la vignette
n'existe pas. La grille affiche des cartes de 140 px de large : leur envoyer les
images pleines de 1024 px multiplierait par quarante le poids de la page pour un
rendu identique a l'oeil.

L'appel est borne a six secondes par un `AbortController`. Si l'API ne repond
pas, les douze cartes de demonstration du HTML restent affichees et la legende
sous la grille le dit sans dramatiser.

**Pour pointer ailleurs qu'en production**, changer la constante en tete de
`scripts/vitrine.js` :

```js
var API = 'https://api.mixalgo.com';
```

---

## Mise en ligne

```bash
# 1. Les fichiers
sudo mkdir -p /srv/vitrine
sudo rsync -a --delete vitrine/ /srv/vitrine/
sudo chown -R www-data:www-data /srv/vitrine

# 2. Le vhost
sudo cp ok_trialgo_backend/docker/nginx/mixalgo.com.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/mixalgo.com.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 3. Le certificat
sudo certbot --nginx -d mixalgo.com -d www.mixalgo.com
```

**Prerequis DNS** : `mixalgo.com` et `www.mixalgo.com` doivent pointer sur l'IP du
serveur avant de lancer certbot, qui refuse d'emettre un certificat pour un
domaine qui ne le designe pas encore.

### L'APK

Le bouton de telechargement pointe vers `/telechargements/mixalgo.apk`. **Ce
fichier n'est pas dans le depot** et doit etre depose a la main :

```bash
cd trialgo && flutter build apk --release
sudo mkdir -p /srv/vitrine/telechargements
sudo cp build/app/outputs/flutter-apk/app-release.apk \
        /srv/vitrine/telechargements/mixalgo.apk
```

⚠️ Sans `android/key.properties`, Gradle retombe sur la cle de debug. Ce binaire
s'installe, mais il n'est pas publiable et ne pourra jamais etre mis a jour par
une version signee correctement. Voir la section « Signature Android » du
`CLAUDE.md`.

Le vhost force le type MIME `application/vnd.android.package-archive` sur ce
dossier. Sans lui, nginx annonce `application/octet-stream` et certains
navigateurs Android refusent d'ouvrir le fichier avec l'installateur : le
telechargement reussit, et rien ne se passe au clic.

---

## Referencement

Ce qui est en place :

| Element | Ou |
|---|---|
| `lang="fr"`, titre, description, `canonical` | en tete de `index.html` |
| Open Graph et Twitter Card, avec image 1200x630 | idem |
| Donnees structurees `Organization`, `WebSite`, `VideoGame`, `FAQPage` | bloc `application/ld+json` |
| Titres hierarchises, un seul `h1` | corps de la page |
| Contenu reel dans le HTML, pas injecte par script | corps de la page |
| `robots.txt` et `sitemap.xml` | racine |
| Redirection `www` vers l'apex | vhost nginx |
| Compression, cache et en-tetes de securite | vhost nginx |

Les cinq questions de la FAQ sont **repetees a l'identique** dans le bloc
`FAQPage` et dans le HTML visible. C'est volontaire, et c'est une exigence des
moteurs : des donnees structurees qui decrivent un contenu absent de la page sont
traitees comme une tentative de manipulation. **Modifier une reponse impose donc
de la modifier aux deux endroits.**

Le plan de site ne declare **que** l'URL racine. Les ancres (`#regle`,
`#distances`) ne sont pas des documents distincts : en lister plusieurs pointant
vers la meme page est lu comme du contenu duplique.
