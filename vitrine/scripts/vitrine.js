// =============================================================
// FICHIER : vitrine/scripts/vitrine.js
// ROLE    : Le relief de la vitrine MIXALGO
// =============================================================
//
// Quatre choses, dans cet ordre de priorite :
//
//   1. LE CIEL      une scene WebGL derriere le hero
//   2. LA FUSION    la demonstration E + C = R, pilotable
//   3. L'APPAREIL   adapter le telechargement au terminal
//   4. LE DECK      le nom et la taille du deck, lus sur l'API
//
// PRINCIPE QUI GOUVERNE TOUT LE FICHIER
// -------------------------------------
// La page doit etre COMPLETE sans ce script. Le hero, la regle, la
// premiere fusion, l'anatomie d'une carte, les distances, les douze
// cartes du deck et la FAQ sont tous dans le HTML, images comprises.
// Ce fichier n'ajoute que du relief.
//
// Chaque bloc commence donc par verifier que ce dont il a besoin
// existe, et renonce en silence sinon. Un navigateur sans WebGL,
// une API injoignable ou un visiteur qui a desactive JavaScript
// voient une page correcte, jamais une page cassee.
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

  // Les cartes servies par la vitrine. Le chemin est construit une
  // fois pour toutes ici : c'est le seul endroit a changer si les
  // visuels demenagent.
  function visuel(code) { return '/assets/cartes/' + code + '.webp'; }

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
  // profondeur, deux diamants filaires assez larges pour que le logo
  // s'inscrive dedans plutot que devant, et de vraies cartes du jeu
  // qui derivent sur une orbite lointaine. Le centre de l'image
  // reste vide, parce que c'est la que le logo est pose.
  // ===========================================================

  // Six cartes reelles, choisies pour leurs dominantes tres
  // differentes : le jaune d'EKAMBI, le bleu de MILLA, le rouge de
  // KEZEU, l'or de MAGNE. Vues de loin et a demi transparentes, ce
  // sont ces masses de couleur qui se lisent, pas les details.
  var CARTES_ORBITE = ['X1', 'Z8', 'B3', 'K2', 'C7', 'N1'];

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
    // De VRAIES cartes du jeu, chargees comme textures. Une carte
    // dessinee au vol aurait ete plus legere, mais elle aurait
    // aussi ete un rectangle generique : c'est le deck qui doit
    // tourner autour du logo, pas un motif.
    var chargeur = new THREE.TextureLoader();
    var cartes = [];
    var nombreCartes = largeur < 700 ? 3 : CARTES_ORBITE.length;

    for (var j = 0; j < nombreCartes; j++) {
      var texture = chargeur.load(visuel(CARTES_ORBITE[j]));
      // Sans cela, une carte vue de biais devient une bouillie de
      // pixels : le filtrage par defaut n'anticipe pas l'angle.
      texture.anisotropy = rendu.capabilities.getMaxAnisotropy();

      var carte = new THREE.Mesh(
        // Le rapport exact des visuels, 380 x 540.
        new THREE.PlaneGeometry(1.5, 2.13),
        new THREE.MeshBasicMaterial({
          map: texture, transparent: true, opacity: 0.42,
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
      // Les textures arrivent en differe, d'ou un second rendu.
      dessiner();
      setTimeout(dessiner, 1200);
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
  // Les trois trios ci dessous ne sont pas inventes pour la
  // demonstration : ce sont les noeuds n25, n15 et n35 du
  // referentiel MIXALGO Savane, et ce sont les SEULS entierement
  // illustres par la planche d'impression de quinze cartes.
  //
  // Ils partagent tous les trois la meme emettrice, KEZEU. C'est
  // une coincidence heureuse et c'est aussi la meilleure lecon
  // possible : une carte identique, trois cables differents, trois
  // resultats differents. Le role n'est pas dans la carte.
  //
  // L'ORDRE EST DELIBERE. Il va du plus lisible au plus troublant :
  //   1. un attribut traverse les trois cartes
  //   2. l'enfant prend un attribut a chaque parent
  //   3. les attributs ne disent rien, tout est dans l'image
  //
  // La troisieme est la plus importante. Elle empeche le visiteur
  // de repartir en croyant que le jeu se resume a apparier des
  // mots cles, ce qui serait faux.
  // ===========================================================
  var TRIOS = [
    {
      lecture: "<strong>Maille</strong> traverse les trois cartes. KEZEU la porte, " +
               "BABADJI la porte, BEMA en herite.",
      cartes: [
        { role: 'emettrice',  code: 'B3', nom: 'KEZEU',
          attributs: ['Humain augmenté', 'Maille', 'Biotech'], partages: ['Maille'] },
        { role: 'cable',      code: 'M3', nom: 'BABADJI',
          attributs: ['Électrique', 'Maille'], partages: ['Maille'] },
        { role: 'receptrice', code: 'A4', nom: 'BEMA',
          attributs: ['Duo', 'Maille', 'Afro'], partages: ['Maille'] }
      ]
    },
    {
      lecture: "KEZEU donne l'<strong>humain augmenté</strong>, MILLA donne " +
               "l'<strong>électrique</strong>. TUEKAM hérite des deux.",
      cartes: [
        { role: 'emettrice',  code: 'B3', nom: 'KEZEU',
          attributs: ['Humain augmenté', 'Maille', 'Biotech'], partages: ['Humain augmenté'] },
        { role: 'cable',      code: 'Z8', nom: 'MILLA',
          attributs: ['Mystique', 'Électrique', 'Biotech'], partages: ['Électrique'] },
        { role: 'receptrice', code: 'L9', nom: 'TUEKAM',
          attributs: ['Humain augmenté', 'Électrique', 'Afro'],
          partages: ['Humain augmenté', 'Électrique'] }
      ]
    },
    {
      lecture: "Ici les attributs ne suffisent pas : BIKOKO n'en partage aucun " +
               "avec WAKAM. Le lien est <strong>dans l'image</strong>, et nulle part ailleurs.",
      cartes: [
        { role: 'emettrice',  code: 'B3', nom: 'KEZEU',
          attributs: ['Humain augmenté', 'Maille', 'Biotech'], partages: ['Humain augmenté'] },
        { role: 'cable',      code: 'C7', nom: 'BIKOKO',
          attributs: ['Fantaisiste', 'Chapeau', 'Groupe'], partages: [] },
        { role: 'receptrice', code: 'N1', nom: 'WAKAM',
          attributs: ['Humain augmenté', 'Rouge', 'Ailes'], partages: ['Humain augmenté'] }
      ]
    }
  ];

  var indexTrio = 0;

  /** Reecrit une figure de carte a partir d'une description. */
  function poserCarte(figure, donnees) {
    if (!figure) return;

    figure.setAttribute('data-code', donnees.code);

    var image = figure.querySelector('img');
    if (image) {
      image.src = visuel(donnees.code);
      image.alt = 'Carte ' + donnees.nom + ', code ' + donnees.code +
                  '. Attributs : ' + donnees.attributs.join(', ').toLowerCase() + '.';
    }

    var etiquette = figure.querySelector('.carte__code');
    if (etiquette) etiquette.textContent = donnees.code;

    var nom = figure.querySelector('.carte__nom');
    if (nom) nom.textContent = donnees.nom;

    var liste = figure.querySelector('.attributs');
    if (!liste) return;
    // On reconstruit la liste plutot que de la modifier : le nombre
    // d'attributs varie d'une carte a l'autre (BABADJI en a deux,
    // KEZEU en a trois), et un element residuel afficherait un
    // attribut qui n'appartient pas a la carte affichee.
    liste.textContent = '';
    donnees.attributs.forEach(function (attribut) {
      var puce = document.createElement('li');
      puce.className = 'attribut';
      if (donnees.partages.indexOf(attribut) !== -1) {
        puce.classList.add('est-partage');
      }
      puce.textContent = attribut;
      liste.appendChild(puce);
    });
  }

  function monterLaFusion() {
    var bloc = document.getElementById('fusion');
    var bouton = document.getElementById('relancer');
    var legende = document.getElementById('fusion-legende');
    var lecture = document.getElementById('fusion-lecture');
    if (!bloc || !bouton) return;

    bouton.addEventListener('click', function () {
      indexTrio = (indexTrio + 1) % TRIOS.length;
      var trio = TRIOS[indexTrio];

      bloc.classList.add('est-active');

      // 260 ms : le temps que les deux parents aient fini de se
      // pencher. Changer les images avant donnerait l'impression
      // que la fusion se joue apres coup.
      setTimeout(function () {
        trio.cartes.forEach(function (donnees) {
          poserCarte(bloc.querySelector('[data-role="' + donnees.role + '"]'), donnees);
        });
        if (lecture) lecture.innerHTML = trio.lecture;
        if (legende) {
          legende.textContent = 'Fusion ' + (indexTrio + 1) + ' sur ' +
                                TRIOS.length + ', trios réels du deck Savane';
        }
      }, 260);

      setTimeout(function () { bloc.classList.remove('est-active'); }, 760);
    });
  }

  // ===========================================================
  // 3. L'APPAREIL
  // ===========================================================
  //
  // MIXALGO s'installe sur un telephone Android. Une bonne part des
  // visiteurs decouvrent pourtant le site sur un ordinateur : ils
  // cliquent, recuperent un APK sur une machine qui ne peut rien en
  // faire, et le parcours s'arrete la.
  //
  // Le QR code est donc VISIBLE PAR DEFAUT dans le HTML, et retire
  // ici quand l'appareil est deja le bon. Ce sens est important : un
  // visiteur sans JavaScript voit un QR de trop, ce qui ne coute
  // rien, plutot qu'un pont manquant, ce qui lui coute le parcours.
  // ===========================================================
  function adapterAuTerminal() {
    var pont = document.getElementById('pont');
    var bouton = document.getElementById('bouton-apk');

    // userAgentData quand il existe, chaine d'agent sinon. On ne
    // cherche pas a etre exhaustif : se tromper ne casse rien, cela
    // laisse seulement un QR code inutile sur un telephone.
    var marque = (navigator.userAgentData && navigator.userAgentData.platform) ||
                 navigator.userAgent || '';
    if (!/android/i.test(marque)) return;

    if (pont) pont.remove();
    if (bouton) bouton.textContent = 'Installer sur cet appareil';
  }

  // ===========================================================
  // 4. LE DECK
  // ===========================================================
  //
  // L'API publique de MIXALGO ne demande aucune authentification :
  // elle a ete concue pour cet usage.
  //
  // CE QU'ELLE SERT ICI, ET CE QU'ELLE NE SERT PAS
  // ----------------------------------------------
  // Elle fournit le NOM et la TAILLE reelle du deck en ligne, deux
  // informations vivantes qu'une page statique ne peut pas connaitre.
  //
  // Elle ne remplace PAS les visuels. Les douze cartes affichees
  // viennent de la planche d'impression : ce sont les cartes
  // definitives, celles qu'on tient en main. Les ecraser par ce que
  // le catalogue contient a un instant donne serait un pari sur
  // l'etat du serveur, et un pari perdant tant que le catalogue
  // n'est pas complet.
  //
  // Une carte SANS visuel local, elle, se laisse remplir par l'API :
  // c'est ce qui rendra la grille extensible sans toucher au code.
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

  function monterLeDeck() {
    var grille = document.getElementById('grille-deck');
    var etat = document.getElementById('deck-etat');
    if (!grille) return;

    recuperer('/api/public/games')
      .then(function (jeux) {
        if (!jeux || !jeux.length) throw new Error('aucun jeu actif');
        return recuperer('/api/public/games/' + jeux[0].id + '/cards?limite=200')
          .then(function (cartes) {
            return { jeu: jeux[0], cartes: cartes || [] };
          });
      })
      .then(function (donnees) {
        if (!donnees.cartes.length) throw new Error('deck vide');

        var parLibelle = {};
        donnees.cartes.forEach(function (c) {
          parLibelle[c.label] = c.thumb_url || c.image_url;
        });

        // Ne remplir que les emplacements DEPOURVUS de visuel local.
        grille.querySelectorAll('.carte').forEach(function (figure) {
          if (figure.querySelector('img')) return;
          var code = figure.getAttribute('data-code');
          var url = parLibelle[code];
          if (!url) return;

          var face = figure.querySelector('.carte__face');
          var image = document.createElement('img');
          image.loading = 'lazy';
          image.decoding = 'async';
          image.alt = '';
          image.src = url;
          face.insertBefore(image, face.firstChild);
          face.classList.add('est-chargee');
        });

        var montrees = grille.querySelectorAll('.carte').length;
        if (etat) {
          etat.textContent = montrees + ' cartes sur les ' + donnees.cartes.length +
                             ' du deck ' + (donnees.jeu.name || 'actif') +
                             ', catalogue lu en direct sur l’API MIXALGO';
        }
      })
      .catch(function () {
        // L'API est injoignable, ou aucun jeu n'est encore publie.
        // Le HTML annonce deja "Douze cartes sur les soixante-seize
        // du deck Savane", ce qui reste vrai : on ne touche a rien.
      });
  }

  // ===========================================================
  // DEMARRAGE
  // ===========================================================
  function demarrer() {
    monterLeCiel();
    monterLaFusion();
    adapterAuTerminal();
    monterLeDeck();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', demarrer);
  } else {
    demarrer();
  }
})();
