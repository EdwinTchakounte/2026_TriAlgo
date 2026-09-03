// =============================================================
// FICHIER : vitrine/scripts/vitrine.js
// ROLE    : Le relief de la vitrine MIXALGO
// =============================================================
//
// Trois choses, dans cet ordre de priorite :
//
//   1. LE CIEL      une scene WebGL derriere le hero
//   2. LA FUSION    la demonstration E + C = R, pilotable
//   3. LE DECK      les vraies cartes, lues sur l'API publique
//
// PRINCIPE QUI GOUVERNE TOUT LE FICHIER
// -------------------------------------
// La page doit etre COMPLETE sans ce script. Le hero, la regle,
// les distances, les cartes de demonstration et la FAQ sont tous
// dans le HTML. Ce fichier n'ajoute que du relief : une scene
// animee, une transition, et le remplacement des cartes de
// demonstration par les vraies images du deck.
//
// Consequence pratique : chaque bloc ci dessous commence par
// verifier que ce dont il a besoin existe, et renonce en silence
// sinon. Un navigateur sans WebGL, une API injoignable ou un
// visiteur qui a desactive JavaScript voient une page correcte,
// jamais une page cassee.
// =============================================================

(function () {
  'use strict';

  // -----------------------------------------------------------
  // Le visiteur a t il demande moins de mouvement ?
  // -----------------------------------------------------------
  // Ce reglage systeme existe pour de vraies raisons medicales
  // (troubles vestibulaires, migraines). On ne l'ignore pas parce
  // que l'animation est jolie.
  var sobre = window.matchMedia &&
              window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ===========================================================
  // 1. LE CIEL
  // ===========================================================
  //
  // Ce qu'on cherche : de la PROFONDEUR derriere le logo, pas un
  // second logo. Le logo contient deja un diamant, des etoiles et
  // des cartes ; une scene qui les redessinerait au centre entrerait
  // en concurrence avec lui.
  //
  // La scene reste donc a la PERIPHERIE : un champ d'etoiles en
  // profondeur, un diamant filaire assez large pour que le logo
  // s'inscrive dedans plutot que devant, et quelques cartes qui
  // derivent sur une orbite lointaine. Le centre de l'image reste
  // vide, parce que c'est la que le logo est pose.
  // ===========================================================
  function monterLeCiel() {
    var toile = document.getElementById('ciel');
    if (!toile || typeof THREE === 'undefined') return;

    var hote = toile.parentElement;
    var largeur = hote.clientWidth;
    var hauteur = hote.clientHeight;
    if (largeur === 0 || hauteur === 0) return;

    var rendu;
    try {
      rendu = new THREE.WebGLRenderer({
        canvas: toile,
        alpha: true,
        antialias: true
      });
    } catch (e) {
      // Pas de WebGL : le fond degrade du CSS suffit amplement.
      return;
    }

    // Plafonner la densite de pixels. Sur un telephone recent,
    // devicePixelRatio vaut 3 : rendre trois fois trop de pixels
    // pour un decor vide la batterie sans rien apporter.
    rendu.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
    rendu.setSize(largeur, hauteur, false);

    var scene = new THREE.Scene();
    var camera = new THREE.PerspectiveCamera(52, largeur / hauteur, 0.1, 120);
    camera.position.z = 15;

    var CYAN = 0x00d8f0;
    var AMBRE = 0xf0a800;

    // ---- Le champ d'etoiles ---------------------------------
    // Reparties dans un volume, pas sur un plan : c'est la
    // dispersion en Z qui donne la sensation de profondeur quand
    // la camera bouge de quelques degres.
    var nombreEtoiles = largeur < 700 ? 340 : 720;
    var positions = new Float32Array(nombreEtoiles * 3);
    for (var i = 0; i < nombreEtoiles; i++) {
      positions[i * 3]     = (Math.random() - 0.5) * 46;
      positions[i * 3 + 1] = (Math.random() - 0.5) * 30;
      positions[i * 3 + 2] = (Math.random() - 0.5) * 34 - 6;
    }
    var geoEtoiles = new THREE.BufferGeometry();
    geoEtoiles.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    var etoiles = new THREE.Points(geoEtoiles, new THREE.PointsMaterial({
      color: CYAN,
      size: 0.075,
      transparent: true,
      opacity: 0.75,
      sizeAttenuation: true
    }));
    scene.add(etoiles);

    // ---- Les diamants filaires ------------------------------
    // Un octaedre vu de face EST un losange. C'est la forme du
    // logo, reprise en volume plutot qu'imitee a plat.
    function diamant(rayon, couleur, opacite) {
      var maillage = new THREE.LineSegments(
        new THREE.EdgesGeometry(new THREE.OctahedronGeometry(rayon, 0)),
        new THREE.LineBasicMaterial({
          color: couleur, transparent: true, opacity: opacite
        })
      );
      scene.add(maillage);
      return maillage;
    }
    var diamantLarge = diamant(9.5, CYAN, 0.22);
    var diamantFin   = diamant(6.2, AMBRE, 0.13);

    // ---- Les cartes en orbite -------------------------------
    // Texture dessinee au vol : aucun fichier a telecharger, et
    // le rendu suit la palette de la page sans risque de derive.
    function textureDeCarte() {
      var c = document.createElement('canvas');
      c.width = 128; c.height = 176;
      var ctx = c.getContext('2d');

      var fond = ctx.createLinearGradient(0, 0, 0, 176);
      fond.addColorStop(0, '#141046');
      fond.addColorStop(1, '#06041A');
      ctx.fillStyle = fond;
      ctx.fillRect(0, 0, 128, 176);

      ctx.strokeStyle = 'rgba(0, 216, 240, 0.55)';
      ctx.lineWidth = 2;
      ctx.strokeRect(1, 1, 126, 174);

      // Le losange, encore : c'est la signature graphique.
      ctx.save();
      ctx.translate(64, 88);
      ctx.rotate(Math.PI / 4);
      ctx.strokeStyle = 'rgba(0, 216, 240, 0.32)';
      ctx.lineWidth = 1.5;
      ctx.strokeRect(-26, -26, 52, 52);
      ctx.restore();

      var texture = new THREE.CanvasTexture(c);
      // Sans cela, la carte vue de biais devient une bouillie de
      // pixels : le filtrage par defaut n'anticipe pas l'angle.
      texture.anisotropy = rendu.capabilities.getMaxAnisotropy();
      return texture;
    }

    var texture = textureDeCarte();
    var cartes = [];
    var nombreCartes = largeur < 700 ? 4 : 7;
    for (var j = 0; j < nombreCartes; j++) {
      var carte = new THREE.Mesh(
        new THREE.PlaneGeometry(1.5, 2.06),
        new THREE.MeshBasicMaterial({
          map: texture, transparent: true, opacity: 0.5,
          side: THREE.DoubleSide, depthWrite: false
        })
      );
      // Rangees sur une orbite LARGE : elles passent sur les cotes
      // de l'image, jamais derriere le logo.
      carte.userData = {
        angle: (j / nombreCartes) * Math.PI * 2,
        rayon: 11 + Math.random() * 3.5,
        hauteur: (Math.random() - 0.5) * 9,
        vitesse: 0.035 + Math.random() * 0.03,
        balancement: Math.random() * Math.PI * 2
      };
      cartes.push(carte);
      scene.add(carte);
    }

    // ---- La parallaxe a la souris ---------------------------
    // On ne bouge pas les objets, on bouge la CAMERA. Deplacer la
    // scene donnerait un glissement plat ; deplacer le point de vue
    // fait travailler la perspective, et la profondeur se voit.
    var visee = { x: 0, y: 0 };
    var actuel = { x: 0, y: 0 };
    if (!sobre) {
      window.addEventListener('pointermove', function (evenement) {
        visee.x = (evenement.clientX / window.innerWidth - 0.5) * 2;
        visee.y = (evenement.clientY / window.innerHeight - 0.5) * 2;
      }, { passive: true });
    }

    var horloge = new THREE.Clock();
    var enPause = false;

    function dessiner() {
      var t = horloge.getElapsedTime();

      diamantLarge.rotation.y = t * 0.055;
      diamantLarge.rotation.x = Math.sin(t * 0.16) * 0.14;
      diamantFin.rotation.y = -t * 0.085;
      diamantFin.rotation.z = t * 0.03;

      etoiles.rotation.y = t * 0.012;

      for (var k = 0; k < cartes.length; k++) {
        var d = cartes[k].userData;
        var a = d.angle + t * d.vitesse;
        cartes[k].position.set(
          Math.cos(a) * d.rayon,
          d.hauteur + Math.sin(t * 0.5 + d.balancement) * 0.7,
          Math.sin(a) * d.rayon * 0.55 - 8
        );
        cartes[k].rotation.y = -a + Math.PI / 2;
        cartes[k].rotation.z = Math.sin(t * 0.4 + d.balancement) * 0.14;
      }

      // Lissage : la camera rejoint la visee par petites touches.
      // Sans cela le moindre mouvement de souris donne un a coup.
      actuel.x += (visee.x - actuel.x) * 0.045;
      actuel.y += (visee.y - actuel.y) * 0.045;
      camera.position.x = actuel.x * 1.6;
      camera.position.y = -actuel.y * 1.1;
      camera.lookAt(0, 0, -4);

      rendu.render(scene, camera);
    }

    function boucle() {
      if (!enPause) dessiner();
      requestAnimationFrame(boucle);
    }

    if (sobre) {
      // Une seule image fixe : le decor existe, il ne bouge pas.
      dessiner();
    } else {
      boucle();
    }

    // Ne pas faire tourner une scene que personne ne regarde :
    // un onglet en arriere plan ou un hero sorti de l'ecran.
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entrees) {
        enPause = !entrees[0].isIntersecting;
      }, { threshold: 0 }).observe(hote);
    }

    var minuteurRedim;
    window.addEventListener('resize', function () {
      clearTimeout(minuteurRedim);
      minuteurRedim = setTimeout(function () {
        var l = hote.clientWidth, h = hote.clientHeight;
        if (!l || !h) return;
        camera.aspect = l / h;
        camera.updateProjectionMatrix();
        rendu.setSize(l, h, false);
        if (sobre) dessiner();
      }, 160);
    });
  }

  // ===========================================================
  // 2. LA FUSION
  // ===========================================================
  //
  // Les quatre trios ci dessous ne sont pas inventes pour la
  // demonstration : ce sont les noeuds n01, n06, n10 et n13 du
  // referentiel MIXALGO Savane. Montrer de fausses fusions sur la
  // page d'accueil d'un jeu de logique serait un mauvais depart.
  // ===========================================================
  var TRIOS = [
    { emettrice: 'R4', cable: 'S8', receptrice: 'A3' },
    { emettrice: 'B4', cable: 'D9', receptrice: 'E7' },
    { emettrice: 'Y7', cable: 'W9', receptrice: 'G1' },
    { emettrice: 'M8', cable: 'G5', receptrice: 'K6' }
  ];

  var indexTrio = 0;

  // Libelle de carte -> URL de vignette, rempli par monterLeDeck().
  // La demonstration de fusion en a besoin : quand on passe au trio
  // suivant, il ne suffit pas de changer les trois codes, il faut
  // aussi changer les trois images. Sans cet index partage, la carte
  // afficherait le code de la nouvelle et le visuel de l'ancienne.
  var INDEX_IMAGES = {};

  function monterLaFusion() {
    var bloc = document.getElementById('fusion');
    var bouton = document.getElementById('relancer');
    var legende = document.getElementById('fusion-legende');
    if (!bloc || !bouton) return;

    bouton.addEventListener('click', function () {
      indexTrio = (indexTrio + 1) % TRIOS.length;
      var trio = TRIOS[indexTrio];

      bloc.classList.add('est-active');

      // 260 ms : le temps que les deux parents aient fini de se
      // pencher. Changer les images avant donnerait l'impression
      // que la fusion se joue apres coup.
      setTimeout(function () {
        ecrireCarte(bloc.querySelector('[data-role="emettrice"]'),
                    trio.emettrice, INDEX_IMAGES[trio.emettrice]);
        ecrireCarte(bloc.querySelector('[data-role="cable"]'),
                    trio.cable, INDEX_IMAGES[trio.cable]);
        ecrireCarte(bloc.querySelector('[data-role="receptrice"]'),
                    trio.receptrice, INDEX_IMAGES[trio.receptrice]);
        if (legende) {
          legende.textContent = 'Fusion ' + (indexTrio + 1) + ' sur ' +
                                TRIOS.length + ', extraite du deck Savane';
        }
      }, 260);

      setTimeout(function () { bloc.classList.remove('est-active'); }, 760);
    });
  }

  // ===========================================================
  // 3. LE DECK
  // ===========================================================
  //
  // L'API publique de MIXALGO existe deja et ne demande aucune
  // authentification : elle a ete concue pour cet usage. On lui
  // demande le premier jeu actif, puis ses cartes.
  //
  // On lit thumb_url en priorite. La grille affiche des cartes de
  // 140 px de large ; leur envoyer les images pleines de 1024 px
  // multiplierait par quarante le poids de la page pour un rendu
  // identique a l'oeil.
  // ===========================================================
  var API = 'https://api.mixalgo.com';
  var DELAI_API = 6000;

  function recuperer(chemin) {
    // AbortController plutot qu'une promesse qui tourne : une API
    // lente ne doit pas laisser la page dans un etat d'attente
    // indefini. Au bout de six secondes, on renonce proprement.
    var arret = new AbortController();
    var minuteur = setTimeout(function () { arret.abort(); }, DELAI_API);
    return fetch(API + chemin, { signal: arret.signal })
      .then(function (reponse) {
        clearTimeout(minuteur);
        if (!reponse.ok) throw new Error('HTTP ' + reponse.status);
        return reponse.json();
      });
  }

  /** Pose une image et un libelle dans une carte deja presente. */
  function ecrireCarte(figure, code, url) {
    if (!figure) return;
    var face = figure.querySelector('.carte__face');
    var etiquette = figure.querySelector('.carte__code');
    if (etiquette) etiquette.textContent = code;
    if (!face) return;

    var image = face.querySelector('img');

    if (!url) {
      // La carte demandee n'a pas de visuel connu. Laisser l'ancienne
      // image en place afficherait un code et une illustration qui ne
      // se correspondent plus : mieux vaut revenir au dos de carte.
      if (image) image.remove();
      face.classList.remove('est-chargee');
      return;
    }

    if (!image) {
      image = document.createElement('img');
      image.loading = 'lazy';
      image.decoding = 'async';
      // Le libelle d'une carte est un code interne ; le lire a voix
      // haute n'apprendrait rien. L'information utile est portee par
      // le texte de la section.
      image.alt = '';
      face.insertBefore(image, face.firstChild);
    }
    image.src = url;
    face.classList.add('est-chargee');
  }

  function monterLeDeck() {
    var grille = document.getElementById('grille-deck');
    var etat = document.getElementById('deck-etat');
    if (!grille) return;

    recuperer('/api/public/games')
      .then(function (jeux) {
        if (!jeux || !jeux.length) throw new Error('aucun jeu actif');
        return recuperer('/api/public/games/' + jeux[0].id + '/cards?limite=60')
          .then(function (cartes) {
            return { jeu: jeux[0], cartes: cartes || [] };
          });
      })
      .then(function (donnees) {
        if (!donnees.cartes.length) throw new Error('deck vide');

        // Index par libelle : la demonstration de fusion cite des
        // cartes precises, il faut pouvoir les retrouver.
        donnees.cartes.forEach(function (c) {
          INDEX_IMAGES[c.label] = c.thumb_url || c.image_url;
        });

        // --- La grille -------------------------------------
        var emplacements = grille.querySelectorAll('.carte');
        emplacements.forEach(function (figure, rang) {
          var carte = donnees.cartes[rang % donnees.cartes.length];
          ecrireCarte(figure, carte.label, carte.thumb_url || carte.image_url);
        });

        // --- La demonstration et la table du mode collectif --
        document.querySelectorAll('.carte').forEach(function (figure) {
          var etiquette = figure.querySelector('.carte__code');
          if (!etiquette) return;
          var code = etiquette.textContent.trim();
          if (INDEX_IMAGES[code]) ecrireCarte(figure, code, INDEX_IMAGES[code]);
        });

        if (etat) {
          etat.textContent = donnees.cartes.length + ' cartes dans le deck ' +
                             (donnees.jeu.name || 'actif') +
                             ', images servies en direct par l’API MIXALGO';
        }
      })
      .catch(function () {
        // L'API est injoignable, ou aucun jeu n'est encore publie.
        // Les cartes de demonstration du HTML restent affichees :
        // la section garde du sens, elle perd seulement les visuels.
        if (etat) {
          etat.textContent = 'Apercu du deck. Les visuels s’affichent ' +
                             'des que le catalogue est en ligne.';
        }
      });
  }

  // ===========================================================
  // DEMARRAGE
  // ===========================================================
  function demarrer() {
    monterLeCiel();
    monterLaFusion();
    monterLeDeck();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', demarrer);
  } else {
    demarrer();
  }
})();
