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
                             ', catalogue lu en direct sur l\'API MIXALGO';
        }
      })
      .catch(function () {
        // L'API est injoignable, ou aucun jeu n'est encore publie.
        // Le HTML annonce deja "Douze cartes sur les soixante-seize
        // du deck Savane", ce qui reste vrai : on ne touche a rien.
      });
  }

  // ===========================================================
  // 5. LE RELIEF AU POINTEUR
  // ===========================================================
  //
  // Une carte qui s'incline vers le curseur, avec un reflet qui
  // suit la meme lumiere. C'est le seul effet de la page qui
  // demande une boucle de rendu par mouvement, donc le seul qui
  // merite qu'on se preoccupe de son cout.
  //
  // TROIS CONDITIONS AVANT D'ARMER QUOI QUE CE SOIT
  // -----------------------------------------------
  //   - mouvement reduit demande : on ne monte rien ;
  //   - pointeur grossier (doigt) : on ne monte rien non plus.
  //     Sur tactile il n'existe pas d'etat "survole" : la carte
  //     resterait inclinee apres le doigt, figee de travers,
  //     jusqu'au prochain toucher ailleurs ;
  //   - pas de survol reel : meme raison.
  //
  // POURQUOI LE CADRE EST MESURE UNE SEULE FOIS
  // -------------------------------------------
  // getBoundingClientRect force le navigateur a recalculer la
  // mise en page. L'appeler a chaque mouvement de souris, alors
  // qu'on ecrit dans la foulee des styles, provoque le va et
  // vient lecture/ecriture qui fait tomber le defilement sous les
  // soixante images par seconde. Le cadre est donc pris a
  // l'entree du pointeur et garde jusqu'a sa sortie : pendant ce
  // temps la carte ne bouge pas de place, seule sa surface
  // s'incline.
  // ===========================================================

  var POINTEUR_FIN = window.matchMedia &&
                     window.matchMedia('(hover: hover) and (pointer: fine)').matches;

  /**
   * Traduit une position de pointeur en angles et en position de
   * reflet, puis les ecrit comme variables CSS sur la cible.
   *
   * Le signe compte : deplacer la souris vers la DROITE doit
   * faire pivoter la carte de sorte que son bord droit RECULE.
   * L'inverse donne un objet qui fuit le curseur, et l'oeil le
   * lit immediatement comme une erreur sans savoir pourquoi.
   */
  function poserInclinaison(cible, cadre, x, y, amplitude) {
    var px = (x - cadre.left) / cadre.width;    // 0 a gauche, 1 a droite
    var py = (y - cadre.top) / cadre.height;    // 0 en haut,  1 en bas
    px = Math.max(0, Math.min(1, px));
    py = Math.max(0, Math.min(1, py));

    var style = cible.style;
    style.setProperty('--incl-y', ((px - 0.5) * 2 * amplitude).toFixed(2) + 'deg');
    style.setProperty('--incl-x', ((0.5 - py) * 2 * amplitude).toFixed(2) + 'deg');
    // Le reflet, lui, va DANS le sens du pointeur : c'est la
    // source de lumiere qu'on suit, pas la surface.
    style.setProperty('--lux-x', (px * 100).toFixed(1) + '%');
    style.setProperty('--lux-y', (py * 100).toFixed(1) + '%');
  }

  function oublierInclinaison(cible) {
    ['--incl-x', '--incl-y', '--lux-x', '--lux-y'].forEach(function (nom) {
      cible.style.removeProperty(nom);
    });
  }

  /**
   * Branche l'inclinaison sur un couple hote/cible.
   * L'hote recoit les evenements et la classe d'etat ; la cible
   * porte les variables. Les deux different parce que la zone
   * sensible est souvent plus large que la surface qui bouge.
   */
  function brancherInclinaison(hote, cible, amplitude) {
    if (!hote || !cible) return;

    var cadre = null;
    var enAttente = false;
    var dernierX = 0, dernierY = 0;

    hote.addEventListener('pointerenter', function (evenement) {
      // Un stylet ou un doigt qui declenche pointerenter ne doit
      // pas armer le suivi : il n'y aura pas de pointerleave
      // fiable pour le desarmer.
      if (evenement.pointerType !== 'mouse') return;
      cadre = cible.getBoundingClientRect();
      hote.classList.add('incline');
    });

    hote.addEventListener('pointermove', function (evenement) {
      if (!cadre) return;
      dernierX = evenement.clientX;
      dernierY = evenement.clientY;
      // Une seule ecriture par image affichee, quelle que soit la
      // cadence d'evenements de la souris -- qui peut monter a
      // plusieurs centaines par seconde sur un pointeur rapide.
      if (enAttente) return;
      enAttente = true;
      requestAnimationFrame(function () {
        enAttente = false;
        if (!cadre) return;
        poserInclinaison(cible, cadre, dernierX, dernierY, amplitude);
      });
    }, { passive: true });

    hote.addEventListener('pointerleave', function () {
      cadre = null;
      hote.classList.remove('incline');
      oublierInclinaison(cible);
    });
  }

  function monterLeRelief() {
    if (sobre || !POINTEUR_FIN) return;

    // Les cartes. L'hote est la figure entiere -- nom et attributs
    // compris -- pour que l'inclinaison ne se coupe pas quand le
    // curseur descend sur le libelle.
    document.querySelectorAll('.carte').forEach(function (figure) {
      brancherInclinaison(figure, figure.querySelector('.carte__face'), 10);
    });

    // La grande carte de la section Anatomie. Amplitude plus
    // faible : elle est deja inclinee au repos, et la somme des
    // deux angles depasserait vite le vraisemblable.
    var anatomie = document.querySelector('.anatomie__carte');
    if (anatomie) brancherInclinaison(anatomie, anatomie.querySelector('img'), 6);
  }

  // ===========================================================
  // 6. LES ARRIVEES AU DEFILEMENT
  // ===========================================================
  //
  // Les blocs visuels montent de quelques pixels en apparaissant.
  // Le CSS decrit les deux etats ; ce bloc ne fait que poser la
  // classe au bon moment, et surtout DESARMER proprement quand
  // les conditions ne sont pas reunies.
  //
  // Le desarmement est la partie importante. La classe `anime`
  // est posee tres tot, dans le <head>, avant de savoir si on
  // saura l'honorer. Si IntersectionObserver manque, ou si le
  // visiteur a demande moins de mouvement, il faut la retirer :
  // la laisser laisserait une page dont la moitie du contenu est
  // a opacite zero, pour toujours.
  // ===========================================================

  var MARGE_OBSERVATION = '0px 0px -12% 0px';

  function monterLesRevelations() {
    var racine = document.documentElement;
    var blocs = document.querySelectorAll('.montee');

    if (sobre || !('IntersectionObserver' in window)) {
      racine.classList.remove('anime');
      // Les compteurs ne sont pas perdus pour autant : les
      // valeurs finales sont deja ecrites dans le HTML.
      return;
    }

    // Signale au garde-fou du <head> que la releve est assuree.
    // Sans cela il desarmerait tout au bout de 2,5 secondes.
    racine.classList.add('revele-actif');

    // La cascade dans les grilles. Le retard est plafonne : sur
    // douze cartes, un pas regulier ferait arriver la derniere
    // presque une seconde apres la premiere, et le visiteur
    // aurait deja fini de lire.
    document.querySelectorAll('.grille-deck .carte, .etapes .etape')
      .forEach(function (element, rang) {
        element.style.setProperty('--retard', Math.min(rang * 45, 400) + 'ms');
      });

    document.querySelectorAll('.distances .distance').forEach(function (ligne, rang) {
      var jauge = ligne.querySelector('.distance__jauge i');
      if (jauge) jauge.style.setProperty('--retard', (rang * 90) + 'ms');
    });

    var observateur = new IntersectionObserver(function (entrees) {
      entrees.forEach(function (entree) {
        if (entree.isIntersecting) reveler(entree.target);
      });
    }, { threshold: 0.12, rootMargin: MARGE_OBSERVATION });

    function reveler(bloc) {
      if (bloc.classList.contains('est-vue')) return;
      bloc.classList.add('est-vue');
      // Une arrivee ne se joue qu'une fois. La rejouer a chaque
      // passage transformerait la page en manege.
      observateur.unobserve(bloc);
      compterDans(bloc);
    }

    blocs.forEach(function (bloc) { observateur.observe(bloc); });

    // -------------------------------------------------------
    // LE FILET
    // -------------------------------------------------------
    // IntersectionObserver ne signale que les CHANGEMENTS d'etat
    // d'intersection. Un bloc traverse entierement entre deux
    // images affichees passe de "sous la fenetre" a "au dessus de
    // la fenetre" sans jamais avoir ete "dedans" : l'intersection
    // vaut zero avant et zero apres, elle n'a donc pas change, et
    // AUCUNE entree n'est emise.
    //
    // Ce n'est pas un cas d'ecole. Il suffit d'une molette lancee,
    // d'un clic sur un lien d'ancrage, d'une recherche dans la
    // page ou d'un retour a une position memorisee. Le bloc reste
    // alors a opacite zero pour toujours, a moins que le visiteur
    // ne remonte -- ce qu'il n'a aucune raison de faire, puisqu'il
    // ne sait pas qu'il a rate quelque chose.
    //
    // Ce controle rattrape le cas : tout bloc dont le haut est
    // deja passe sous la limite de la fenetre est revele, qu'il
    // ait ete signale ou non. Il coute une lecture de position par
    // image au plus, uniquement pendant le defilement, et il se
    // DEBRANCHE des que le dernier bloc est arrive.
    // -------------------------------------------------------
    var restants = [].slice.call(blocs);
    var enAttente = false;

    function rattraper() {
      restants = restants.filter(function (bloc) {
        if (bloc.classList.contains('est-vue')) return false;
        if (bloc.getBoundingClientRect().top > window.innerHeight) return true;
        reveler(bloc);
        return false;
      });
      if (!restants.length) {
        window.removeEventListener('scroll', auDefilement);
      }
    }

    function auDefilement() {
      if (enAttente) return;
      enAttente = true;
      requestAnimationFrame(function () { enAttente = false; rattraper(); });
    }

    window.addEventListener('scroll', auDefilement, { passive: true });
    rattraper();   // et pour une page ouverte deja defilee, des maintenant
  }

  // ===========================================================
  // 7. LES COMPTEURS
  // ===========================================================
  //
  // Les nombres de la page montent de zero a leur valeur quand
  // leur bloc arrive. C'est le seul endroit ou une animation
  // porte une information : elle dit que ces chiffres ont ete
  // COMPTES, pas choisis.
  //
  // La valeur cible est LUE DANS LA PAGE, jamais dupliquee dans
  // un attribut. Deux sources pour un meme nombre finissent
  // toujours par diverger, et c'est alors la vitrine qui ment.
  // Un contenu non numerique -- "D1 a D5" -- n'est simplement pas
  // reconnu et reste tel quel.
  // ===========================================================

  var DUREE_COMPTE = 1100;

  function animerNombre(element) {
    // Le premier enfant est le noeud de texte : "76", suivi du
    // <small> qui porte la legende. On ne touche qu'a lui, sans
    // quoi la legende disparaitrait a la premiere image.
    var noeud = element.firstChild;
    if (!noeud || noeud.nodeType !== 3) return;

    var brut = noeud.nodeValue.trim();
    if (!/^\d+$/.test(brut)) return;
    var cible = parseInt(brut, 10);
    if (cible < 2) return;              // compter jusqu'a 1 ne montre rien

    var depart = null;
    function pas(instant) {
      if (depart === null) depart = instant;
      var avance = Math.min((instant - depart) / DUREE_COMPTE, 1);
      // Sortie cubique : le nombre part vite et se pose. Une
      // progression lineaire donne un compteur de station service.
      var lisse = 1 - Math.pow(1 - avance, 3);
      noeud.nodeValue = String(Math.round(cible * lisse));
      if (avance < 1) requestAnimationFrame(pas);
      else noeud.nodeValue = brut;      // la valeur exacte, au caractere pres
    }
    requestAnimationFrame(pas);
  }

  function compterDans(bloc) {
    if (sobre) return;
    bloc.querySelectorAll('.chiffre dd, .distance__valeur').forEach(animerNombre);
  }

  // ===========================================================
  // 8. L'ENTETE QUI SE DETACHE
  // ===========================================================
  //
  // Tant que la page est en haut, la barre fait partie du decor.
  // Des que du contenu passe dessous, elle doit s'en detacher,
  // sinon le texte semble traverser le verre.
  //
  // L'ecoute est passive et ne fait qu'une comparaison ; on
  // n'ecrit dans le DOM que lorsque l'etat CHANGE reellement,
  // pas a chaque pixel de defilement.
  // ===========================================================
  function monterLEntete() {
    var entete = document.querySelector('.entete');
    if (!entete) return;
    var detachee = false;

    function verifier() {
      var doit = window.scrollY > 8;
      if (doit === detachee) return;
      detachee = doit;
      entete.classList.toggle('est-defilee', doit);
    }

    window.addEventListener('scroll', verifier, { passive: true });
    verifier();     // au cas ou la page s'ouvre deja defilee (ancre, retour)
  }

  // ===========================================================
  // 9. LA FERMETURE DU MENU
  // ===========================================================
  //
  // <details> ne se referme pas tout seul. Apres un clic sur « Les
  // distances » le panneau resterait donc ouvert, pose par dessus
  // la section qu'on vient justement de demander a voir.
  //
  // C'est le SEUL comportement du menu qui ne soit pas deja dans le
  // navigateur, et donc le seul qui justifie du script. Tout le
  // reste -- ouvrir, fermer, annoncer l'etat a un lecteur d'ecran,
  // repondre a Entree et a la barre d'espace -- vient du balisage.
  // Sans ce bloc le menu fonctionne encore, il se referme
  // simplement d'un second appui.
  //
  // On ecoute sur le <details> et non sur chaque lien : un seul
  // ecouteur, et les liens qu'on ajouterait plus tard sont pris en
  // charge sans y penser.
  // ===========================================================
  function monterLeMenu() {
    var menu = document.getElementById('menu');
    if (!menu) return;

    menu.addEventListener('click', function (evenement) {
      if (evenement.target.closest('.menu__liste a')) menu.open = false;
    });

    // Echap ferme, comme tout panneau transitoire.
    //
    // L'ecoute est posee sur le DOCUMENT, pas sur le <details>. Sur
    // celui-ci elle ne recevrait que les touches frappees alors que
    // le focus est a l'interieur du menu -- or on peut tres bien
    // l'avoir ouvert a la souris, le focus restant sur le corps de
    // page. Echap ne ferait alors rien, sans que rien n'explique
    // pourquoi.
    //
    // Le focus revient sur le bouton : le laisser sur un lien qui
    // vient de disparaitre perdrait la navigation au clavier.
    document.addEventListener('keydown', function (evenement) {
      if (evenement.key !== 'Escape' || !menu.open) return;
      menu.open = false;
      var bascule = menu.querySelector('summary');
      if (bascule) bascule.focus();
    });
  }

  // ===========================================================
  // DEMARRAGE
  // ===========================================================
  function demarrer() {
    // monterLesRevelations() PASSE EN PREMIER, et ce n'est pas un
    // detail de style. C'est la seule fonction capable de retirer
    // la classe `anime` posee dans le <head> : tant qu'elle n'a
    // pas tranche, une partie de la page est a opacite zero.
    // Placee apres monterLeCiel(), une exception inattendue dans
    // la scene WebGL -- un pilote graphique capricieux, une
    // texture refusee -- interromprait demarrer() avant elle et
    // laisserait la vitrine a moitie vide pendant deux secondes
    // et demie, le temps que le minuteur de secours agisse.
    // On ne se repose pas sur un filet quand on peut ne pas
    // tomber.
    monterLesRevelations();
    monterLEntete();
    monterLeMenu();

    monterLeCiel();
    monterLaFusion();
    adapterAuTerminal();
    monterLeDeck();
    monterLeRelief();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', demarrer);
  } else {
    demarrer();
  }
})();
