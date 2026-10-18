# La vitrine MIXALGO

Le site public de `mixalgo.com`. Aucune compilation, aucun gestionnaire de
paquets : ce dossier se recopie tel quel sur le serveur.

```
vitrine/
├── index.html            la page, autonome et complete sans JavaScript
├── styles/vitrine.css    l'habillage (curseur, tiroir, eventail, demo...)
├── scripts/vitrine.js    le mouvement, la partie de demo, le contenu publie
├── assets/
│   ├── originaux/        les illustrations SANS cadre (480 et 960 px)
│   └── cartes/           les cartes imprimees, cadre compris (mode collectif)
├── robots.txt
├── sitemap.xml
└── outils/
    ├── recuperer_originaux.py  rapatrie les illustrations depuis l'API
    ├── detourer_logo.py        logo transparent + favicon + image de partage
    ├── extraire_cartes.py      les cartes imprimees, depuis le PDF
    └── generer_qr.py           le QR code de telechargement
```

## L'ordre de la page : l'image d'abord

La premiere version posait logo, titre, paragraphe, boutons et chiffres AVANT la
premiere illustration : sur telephone, trois ecrans de texte pour voir une carte.
MIXALGO est un jeu d'observation ; c'est ce qu'on voit qui doit convaincre.

1. **Hero** : une vraie fusion du deck en grand (KEZEU + BABADJI = BEMA). Sur
   telephone, l'eventail passe AU-DESSUS du titre.
2. **Double bandeau** d'illustrations qui defile.
3. **Partie de demonstration** : cinq manches, vingt secondes chacune, sur les
   dix trios du referentiel entierement illustres par les originaux. Elle ne
   demarre que sur un clic (« Lancer la partie ») : un depart automatique a
   l'apparition du plateau faisait perdre la premiere manche a qui lisait encore.
4. La regle, le deck (visionneuse plein ecran), les distances, le mode
   collectif, le telechargement : peu de mots.
5. La FAQ en bas, pour qui la cherche (et pour le referencement).

Curseur neon (souris uniquement, jamais sous « mouvement reduit »), tiroir de
navigation (piege a focus, Echap, croix toujours visible), visionneuse en
`<dialog>`.

## Le contenu editable depuis le studio

L'ecran **« Vitrine du site »** du studio publie un document dans
`GET /api/public/site/accueil` (module `site` du backend). La page le lit au
chargement et remplace :

- les textes portant `data-cms="..."` (hero, titres et chapeaux de section) ;
- avec la **galerie** : les trois premieres images forment l'eventail du hero,
  la galerie entiere alimente le bandeau et la grille du deck.

Tout est optionnel : un champ vide laisse le texte du HTML en place, et une API
injoignable laisse la page intacte. Les textes sont poses par `textContent`
(jamais interpretes comme du HTML), les images n'acceptent que http(s) - le
serveur le verifie aussi.

La partie de demonstration, elle, reste sur ses trios embarques : ils doivent
etre de vraies fusions, ce qu'une galerie libre ne garantit pas.

## Les originaux

`assets/originaux/` contient les illustrations SANS le cadre imprime, rognees
au format 4:5. Elles viennent du jeu « MixAlgo Puzzle 1 » en production, via
l'API publique :

```bash
python3 vitrine/outils/recuperer_originaux.py            # jeu par defaut
python3 vitrine/outils/recuperer_originaux.py --jeu "..." # un autre jeu
```

Elles sont figees dans le depot pour que le premier rendu ne depende d'aucun
appel reseau.

## Le parti pris

**Un monde sombre unique, assume.** Pas de theme clair. Le logo est une lumiere
neon sur du noir ; le poser sur du blanc reviendrait a l'eteindre.

**La palette n'est pas inventee.** Elle est echantillonnee dans le logo lui meme :
le cyan `#00D8F0` en est la teinte dominante apres le blanc, l'ambre `#F0A800`
vient du mot « Mix », le bleu `#001878` des profondeurs du diamant, et la braise
`#F01800` de la fleche basse, seule couleur chaude saturee de tout le logo. Elle
est donc traitee comme telle sur la page : rarissime.

**La page est complete sans JavaScript.** Le hero, la regle, la premiere fusion,
l'anatomie d'une carte, les distances, les douze cartes du deck et la FAQ sont
dans le HTML, images comprises. Le script n'ajoute que du relief : la scene WebGL,
la transition entre fusions, l'adaptation au terminal et le chiffre reel du deck.
Un robot d'indexation, un navigateur sans WebGL et une API injoignable voient tous
une page correcte.

**Le texte courant est justifie**, au dela de 620 px seulement. Sur une colonne
etroite, justifier un texte francais creuse des rivieres de blanc entre les mots.
`hyphens: auto` est indissociable de la justification : il s'appuie sur le
`lang="fr"` de `<html>` pour couper les mots aux bons endroits.

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

## Les cartes imprimees

> Depuis la refonte « l'image d'abord », ces visuels encadres ne servent plus
> qu'a la section du mode collectif, la ou l'on montre la carte telle qu'on la
> tient. Partout ailleurs, ce sont les originaux (voir plus haut).

Les douze visuels de `assets/cartes/` sont extraits de
**`TRIALGO_15_cartes_A4_63x88mm-1.pdf`**, la planche d'impression au format
63 x 88 mm. Ce sont les cartes definitives, celles qu'on tient en main.

```bash
python3 vitrine/outils/extraire_cartes.py
```

La planche contient quinze images pour douze cartes : KEZEU (B3) y figure trois
fois et MILLA (Z8) deux fois. Ce n'est pas une erreur de mise en page. KEZEU est
l'emettrice partagee des trois trios que la planche permet de composer, et on ne
peut pas poser trois trios simultanement sur une table avec un seul exemplaire de
la carte commune :

```
B3 + Z8 = L9      KEZEU + MILLA    = TUEKAM
B3 + M3 = A4      KEZEU + BABADJI  = BEMA
B3 + C7 = N1      KEZEU + BIKOKO   = WAKAM
```

Ce sont exactement les trois trios de la demonstration de fusion, et les seuls du
referentiel MIXALGO Savane entierement illustres par cette planche.

> **Le PDF n'est pas versionne** : il pese 47 Mo, et git garderait chaque revision
> pour toujours. Ce sont les WebP produits, environ 480 Ko en tout, qui sont dans
> le depot. Regenerer les visuels demande donc d'avoir la planche sous la main.

Le script associe chaque image a son code par une **table ecrite a la main**
(`ORDRE`), parce que les cartes ne portent aucune metadonnee : le code est peint
dans le pixel. Si la planche change, cette table doit changer avec elle, sinon les
codes seront attribues aux mauvais dessins. Le script refuse de tourner si le
nombre d'images ne correspond plus.

---

## Ce que la vitrine demande a l'API

> Trois appels, tous publics : `GET /api/public/site/accueil` (contenu publie
> depuis le studio), puis `GET /api/public/games` et `.../cards` pour la taille
> reelle du deck. Le detail historique ci-dessous reste valable pour les deux
> derniers.

`GET /api/public/games` puis `GET /api/public/games/{id}/cards`, deux endpoints
**sans authentification** concus pour cet usage.

Ce qu'ils servent : le **nom** et la **taille reelle** du deck en ligne, deux
informations vivantes qu'une page statique ne peut pas connaitre.

Ce qu'ils ne servent pas : les visuels. Les douze cartes affichees viennent de la
planche d'impression. Les ecraser par ce que le catalogue contient a un instant
donne serait un pari sur l'etat du serveur, et un pari perdant tant que le
catalogue n'est pas complet. Une carte **sans** visuel local, elle, se laisse
remplir par l'API : c'est ce qui rendra la grille extensible sans toucher au code.

Quand l'API repond, la page lit `thumb_url` en priorite et retombe sur
`image_url`. L'appel est borne a six secondes par un `AbortController` ; sans
reponse, la legende du HTML reste affichee, et elle reste vraie.

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

### L'APK et le QR code

Le telechargement vise un **telephone Android**, alors qu'une bonne part des
visiteurs arrivent sur un ordinateur. Le QR code de `assets/qr-telechargement.png`
resout ce decalage : il ouvre la page sur le telephone, et le telechargement part
du bon appareil.

Il est **visible par defaut dans le HTML** et retire par le script quand l'agent
utilisateur annonce Android. Ce sens est important : un visiteur sans JavaScript
voit un QR de trop, ce qui ne coute rien, plutot qu'un pont manquant, ce qui lui
coute le parcours.

```bash
python3 vitrine/outils/generer_qr.py
```

Le QR est noir sur blanc, sur une pastille blanche. L'habiller aux couleurs de la
page serait plus joli et moins fiable : un code inverse reste lisible par beaucoup
de scanners, mais pas par tous.

### Le fichier APK

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
