// =============================================================
// FICHIER : vitrine/scripts/vitrine.js
// ROLE    : Tout ce qui bouge sur la vitrine MIXALGO
// =============================================================
//
// PRINCIPE QUI GOUVERNE TOUT LE FICHIER
// -------------------------------------
// La page doit etre COMPLETE sans ce script. L'eventail du hero,
// le bandeau, un exemple de partie, la regle, le deck et la FAQ
// sont tous dans le HTML, images comprises. Ce fichier ajoute le
// mouvement, le jeu et le contenu publie depuis le studio.
//
// Chaque bloc commence donc par verifier que ce dont il a besoin
// existe, et renonce en silence sinon. Un navigateur sans WebGL,
// une API injoignable ou un visiteur sans JavaScript voient une
// page correcte, jamais une page cassee.
//
// LES BLOCS, dans l'ordre du fichier
// ----------------------------------
//   0. outils communs
//   1. arrivees au defilement      7. la partie de demonstration
//   2. en-tete                     8. le deck et sa visionneuse
//   3. tiroir                      9. l'appareil (QR / APK)
//   4. curseur                    10. le contenu publie (studio)
//   5. ciel WebGL                 11. demarrage
//   6. eventail, reflet, regle
// =============================================================

(function () {
  'use strict';

  // ===========================================================
  // 0. OUTILS COMMUNS
  // ===========================================================

  // Mouvement reduit : un reglage systeme qui existe pour de vraies
  // raisons medicales (troubles vestibulaires, migraines). On ne
  // l'ignore pas parce que l'animation est jolie.
  var sobre = window.matchMedia &&
              window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Pointeur fin = souris ou trackpad. Sur tactile, il n'existe pas
  // d'etat "survole" : un effet au survol resterait fige apres le
  // doigt. Tout ce qui suit le pointeur est donc reserve a la souris.
  var souris = window.matchMedia && window.matchMedia('(pointer: fine)').matches;

  // L'API. En local (studio + API servis derriere le meme proxy de
  // developpement), on interroge l'origine courante. Jamais une URL
  // lue dans l'adresse de la page : n'importe qui pourrait alors
  // fabriquer un lien mixalgo.com affichant SON contenu.
  var locale = /^(localhost|127\.0\.0\.1|\[::1\])$/.test(location.hostname);
  var API = locale ? location.origin : 'https://api.mixalgo.com';
  var DELAI_API = 6000;

  function visuel(code, largeur) {
    return '/assets/originaux/' + code + '-' + (largeur || 480) + '.webp';
  }

  // Les noms connus des cartes. Les autres s'affichent par leur code,
  // qui est de toute facon ce qu'on prononce autour d'une table.
  var NOMS = {
    B3: 'KEZEU', M3: 'BABADJI', A4: 'BEMA', Z8: 'MILLA', L9: 'TUEKAM',
    C7: 'BIKOKO', N1: 'WAKAM', D9: 'NOTA', X1: 'EKAMBI', M8: 'FEKAM',
    K2: 'MAGNE', Y5: 'ETOO'
  };
  function nom(code) { return NOMS[code] || code; }

  // Toutes les illustrations originales embarquees dans assets/.
  var CODES = ['A4', 'A7', 'B3', 'C2', 'C7', 'D8', 'D9', 'E5', 'F1', 'F2',
               'G8', 'H4', 'K2', 'K4', 'L9', 'M3', 'M8', 'N1', 'P6', 'P7',
               'Q4', 'R5', 'T3', 'V6', 'W9', 'X1', 'Y5', 'Z8'];

  function melanger(liste) {
    // Fisher-Yates : le seul melange sans biais. Le classique
    // sort(() => Math.random() - .5) favorise certaines positions.
    var copie = liste.slice();
    for (var i = copie.length - 1; i > 0; i--) {
      var j = Math.floor(Math.random() * (i + 1));
      var t = copie[i]; copie[i] = copie[j]; copie[j] = t;
    }
    return copie;
  }

  // Reecrit une <figure class="illu"> pour une autre carte. `url`
  // est optionnelle : fournie par le studio, elle remplace le
  // visuel embarque (et le srcset, qui n'aurait plus de sens).
  function poserIllu(figure, code, url, libelle) {
    if (!figure) return;
    var image = figure.querySelector('img');
    if (image) {
      if (url) {
        image.removeAttribute('srcset');
        image.src = url;
      } else {
        image.srcset = visuel(code, 480) + ' 480w, ' + visuel(code, 960) + ' 960w';
        image.src = visuel(code, 480);
      }
      // Une image decorative (alt vide) le reste.
      if (image.getAttribute('alt') !== '') {
        image.alt = 'Carte ' + (libelle || nom(code)) + (code ? ' (' + code + ')' : '');
      }
    }
    var etiquette = figure.querySelector('.illu__code');
    if (etiquette) {
      etiquette.textContent = code || '';
      etiquette.hidden = !code;
    }
  }

  function recuperer(chemin) {
    // AbortController : une API lente ne doit pas laisser la page
    // dans un etat d'attente indefini. Au bout de six secondes, on
    // renonce proprement.
    var arret = new AbortController();
    var minuteur = setTimeout(function () { arret.abort(); }, DELAI_API);
    return fetch(API + chemin, { signal: arret.signal })
      .then(function (reponse) {
        clearTimeout(minuteur);
        if (!reponse.ok) throw new Error('HTTP ' + reponse.status);
        return reponse.json();
      });
  }

  // ===========================================================
  // 1. ARRIVEES AU DEFILEMENT
  // ===========================================================
  //
  // Passe EN PREMIER au demarrage. C'est la seule fonction capable
  // de confirmer la classe `anime` posee dans le <head> : tant
  // qu'elle n'a pas tranche, une partie de la page est a opacite
  // zero. Placee apres le ciel WebGL, une exception dans la scene
  // (pilote graphique capricieux) l'empecherait de s'executer.
  // ===========================================================
  function monterLesRevelations() {
    var racine = document.documentElement;
    if (!racine.classList.contains('anime') || !('IntersectionObserver' in window)) {
      racine.classList.remove('anime');
      return;
    }
    racine.classList.add('revele-actif');

    var observateur = new IntersectionObserver(function (entrees) {
      entrees.forEach(function (entree) {
        if (!entree.isIntersecting) return;
        entree.target.classList.add('est-visible');
        observateur.unobserve(entree.target);
      });
    }, { rootMargin: '0px 0px -8% 0px' });

    document.querySelectorAll('.montee').forEach(function (bloc) {
      observateur.observe(bloc);
    });
  }

  // ===========================================================
  // 2. EN-TETE
  // ===========================================================
  // Transparent sur le hero, vitre des qu'on defile. On n'ecrit
  // dans le DOM que lorsque l'etat CHANGE, pas a chaque pixel.
  function monterLEntete() {
    var entete = document.querySelector('.entete');
    if (!entete) return;
    var detachee = null;
    function verifier() {
      var doit = window.scrollY > 12;
      if (doit === detachee) return;
      detachee = doit;
      entete.classList.toggle('est-defilee', doit);
    }
    window.addEventListener('scroll', verifier, { passive: true });
    verifier();
  }

  // ===========================================================
  // 3. LE TIROIR
  // ===========================================================
  //
  // Sans script, le bouton est un lien vers le plan du pied de
  // page. Ici il devient un vrai bouton de dialogue :
  //   - aria-expanded tenu a jour (un lecteur d'ecran annonce l'etat)
  //   - le focus entre dans le panneau, et y reste (Tab boucle)
  //   - Echap, l'appui sur le fond ou sur un lien referment
  //   - le focus revient au bouton a la fermeture
  //   - la page dessous ne defile plus
  // ===========================================================
  function monterLeTiroir() {
    var bouton = document.getElementById('burger');
    var tiroir = document.getElementById('tiroir');
    if (!bouton || !tiroir) return;

    bouton.setAttribute('role', 'button');
    bouton.setAttribute('aria-expanded', 'false');
    var ouvert = false;

    // Le bouton fait partie du cycle : il reste visible au-dessus du
    // panneau (sous forme de croix), on doit pouvoir y revenir au
    // clavier pour fermer.
    function focusables() {
      return [bouton].concat(Array.prototype.slice.call(
        tiroir.querySelectorAll('a[href], button:not([tabindex="-1"])')));
    }

    function ouvrir() {
      ouvert = true;
      tiroir.hidden = false;
      document.documentElement.classList.add('tiroir-ouvert');
      document.body.style.overflow = 'hidden';
      bouton.setAttribute('aria-expanded', 'true');
      bouton.setAttribute('aria-label', 'Fermer le menu');
      // Une image d'ecart entre "visible" et "ouvert" : sans elle,
      // le navigateur fusionne les deux etats et la glissade ne se
      // joue pas.
      requestAnimationFrame(function () {
        requestAnimationFrame(function () {
          tiroir.classList.add('est-ouvert');
          var premier = focusables()[1];
          if (premier) premier.focus({ preventScroll: true });
        });
      });
    }

    function fermer(rendreLeFocus) {
      if (!ouvert) return;
      ouvert = false;
      tiroir.classList.remove('est-ouvert');
      document.documentElement.classList.remove('tiroir-ouvert');
      document.body.style.overflow = '';
      bouton.setAttribute('aria-expanded', 'false');
      bouton.setAttribute('aria-label', 'Ouvrir le menu');
      // `hidden` seulement APRES la glissade de sortie, sinon le
      // panneau disparaitrait d'un coup.
      setTimeout(function () { if (!ouvert) tiroir.hidden = true; }, sobre ? 0 : 550);
      if (rendreLeFocus) bouton.focus({ preventScroll: true });
    }

    bouton.addEventListener('click', function (e) {
      e.preventDefault();
      if (ouvert) fermer(true); else ouvrir();
    });

    tiroir.addEventListener('click', function (e) {
      if (e.target.closest('.tiroir__fond')) fermer(true);
      // Un lien : on ferme, et la navigation par ancre suit son cours.
      else if (e.target.closest('a')) fermer(false);
    });

    document.addEventListener('keydown', function (e) {
      if (!ouvert) return;
      if (e.key === 'Escape') { fermer(true); return; }
      if (e.key !== 'Tab') return;
      // Piege a focus : de la derniere cible on revient a la
      // premiere, et inversement. Sinon Tab sortirait du panneau
      // vers une page masquee par le fond.
      var liste = focusables();
      var premier = liste[0], dernier = liste[liste.length - 1];
      if (e.shiftKey && document.activeElement === premier) {
        e.preventDefault(); dernier.focus();
      } else if (!e.shiftKey && document.activeElement === dernier) {
        e.preventDefault(); premier.focus();
      }
    });

    // Passe en ecran large avec le tiroir ouvert : la navigation en
    // ligne prend le relais, on le referme.
    window.addEventListener('resize', function () {
      if (ouvert && window.innerWidth >= 1024) fermer(false);
    });
  }

  // ===========================================================
  // 4. LE CURSEUR
  // ===========================================================
  //
  // Un point qui suit la souris au pixel pres, et un anneau qui le
  // rejoint avec un leger retard. L'anneau change de forme selon ce
  // qu'il survole :
  //   lien / bouton  -> il s'ouvre et se remplit ;
  //   [data-curseur] -> il devient un losange plein portant l'action
  //                     ("Voir", "Choisir"). Le losange est la forme
  //                     du logo.
  //
  // Les positions sont ecrites en `transform` (composite seul, pas
  // de recalcul de mise en page) dans UNE boucle requestAnimationFrame,
  // et la boucle s'arrete d'elle-meme quand l'anneau a rejoint le
  // point : un curseur immobile ne coute rien.
  // ===========================================================
  function monterLeCurseur() {
    if (!souris || sobre) return;
    var curseur = document.querySelector('.curseur');
    if (!curseur) return;
    var point = curseur.querySelector('.curseur__point');
    var anneau = curseur.querySelector('.curseur__anneau');
    var libelle = curseur.querySelector('.curseur__libelle');

    // Cache tant que la souris n'a pas bouge : sinon l'anneau
    // attendrait, a moitie visible, dans le coin haut gauche.
    curseur.classList.add('est-cache');
    var cible = { x: -100, y: -100 };
    var actuel = { x: -100, y: -100 };
    var enCours = false;

    function boucle() {
      actuel.x += (cible.x - actuel.x) * 0.2;
      actuel.y += (cible.y - actuel.y) * 0.2;
      anneau.style.transform = 'translate3d(' + actuel.x + 'px,' + actuel.y + 'px,0)';
      if (Math.abs(cible.x - actuel.x) + Math.abs(cible.y - actuel.y) > 0.3) {
        requestAnimationFrame(boucle);
      } else {
        enCours = false;
      }
    }

    document.addEventListener('pointermove', function (e) {
      if (e.pointerType !== 'mouse') return;
      // Premiere apparition : l'anneau part de la souris, pas du coin.
      if (cible.x < 0) { actuel.x = e.clientX; actuel.y = e.clientY; }
      cible.x = e.clientX; cible.y = e.clientY;
      point.style.transform = 'translate3d(' + cible.x + 'px,' + cible.y + 'px,0)';
      curseur.classList.remove('est-cache');
      if (!enCours) { enCours = true; requestAnimationFrame(boucle); }
    }, { passive: true });

    // Delegation : un seul ecouteur pour toute la page, y compris
    // les cartes que le script ajoute plus tard (deck, studio).
    document.addEventListener('pointerover', function (e) {
      var carte = e.target.closest('[data-curseur]');
      var lien = !carte && e.target.closest('a, button, summary, [role="button"]');
      curseur.classList.toggle('est-carte', !!carte);
      curseur.classList.toggle('est-lien', !!lien);
      libelle.textContent = carte ? carte.getAttribute('data-curseur') : '';
    });

    document.addEventListener('pointerdown', function () { curseur.classList.add('est-presse'); });
    document.addEventListener('pointerup', function () { curseur.classList.remove('est-presse'); });
    document.documentElement.addEventListener('pointerleave', function () { curseur.classList.add('est-cache'); });

    // Le curseur systeme n'est masque (CSS) qu'une fois le notre
    // pret a le remplacer.
    document.documentElement.classList.add('curseur-actif');
  }

  // ===========================================================
  // 5. LE CIEL
  // ===========================================================
  //
  // De la PROFONDEUR derriere le hero : un champ d'etoiles, deux
  // diamants filaires (la forme du logo, en volume) et de vraies
  // illustrations du deck en orbite lointaine. Le premier plan
  // reste aux cartes de l'eventail.
  // ===========================================================
  var CARTES_ORBITE = ['Y5', 'X1', 'F2', 'K2', 'N1', 'H4'];

  function monterLeCiel() {
    var toile = document.getElementById('ciel');
    if (!toile || typeof THREE === 'undefined') return;

    var hote = toile.parentElement;
    var largeur = hote.clientWidth;
    var hauteur = hote.clientHeight;
    if (largeur === 0 || hauteur === 0) return;

    var rendu;
    try {
      rendu = new THREE.WebGLRenderer({ canvas: toile, alpha: true, antialias: true });
    } catch (e) {
      return; // Pas de WebGL : le degrade du CSS suffit.
    }

    // densite plafonnee : rendre trois fois trop de pixels pour un
    // decor vide la batterie d'un telephone sans rien apporter.
    rendu.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75));
    rendu.setSize(largeur, hauteur, false);

    var scene = new THREE.Scene();
    var camera = new THREE.PerspectiveCamera(52, largeur / hauteur, 0.1, 120);
    camera.position.z = 15;

    var etroit = largeur < 700;
    var nombreEtoiles = etroit ? 420 : 760;
    var positions = new Float32Array(nombreEtoiles * 3);
    for (var i = 0; i < nombreEtoiles; i++) {
      positions[i * 3] = (Math.random() - 0.5) * 46;
      positions[i * 3 + 1] = (Math.random() - 0.5) * 30;
      positions[i * 3 + 2] = (Math.random() - 0.5) * 34 - 6;
    }
    var geoEtoiles = new THREE.BufferGeometry();
    geoEtoiles.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    var etoiles = new THREE.Points(geoEtoiles, new THREE.PointsMaterial({
      color: 0x00d8f0, size: 0.075, transparent: true, opacity: 0.75, sizeAttenuation: true
    }));
    scene.add(etoiles);

    function diamant(rayon, couleur, opacite) {
      var maillage = new THREE.LineSegments(
        new THREE.EdgesGeometry(new THREE.OctahedronGeometry(rayon, 0)),
        new THREE.LineBasicMaterial({ color: couleur, transparent: true, opacity: opacite })
      );
      scene.add(maillage);
      return maillage;
    }
    var diamantLarge = diamant(9.5, 0x00d8f0, etroit ? 0.3 : 0.2);
    var diamantFin = diamant(6.2, 0xf0a800, etroit ? 0.18 : 0.12);

    var chargeur = new THREE.TextureLoader();
    var cartes = [];
    var nombreCartes = etroit ? 4 : CARTES_ORBITE.length;
    for (var j = 0; j < nombreCartes; j++) {
      var texture = chargeur.load(visuel(CARTES_ORBITE[j], 480));
      texture.anisotropy = rendu.capabilities.getMaxAnisotropy();
      var carte = new THREE.Mesh(
        new THREE.PlaneGeometry(1.6, 2.0), // rapport 4:5 des originaux
        new THREE.MeshBasicMaterial({
          map: texture, transparent: true, opacity: etroit ? 0.4 : 0.34,
          side: THREE.DoubleSide, depthWrite: false
        })
      );
      carte.userData = {
        angle: (j / nombreCartes) * Math.PI * 2,
        rayon: 11 + Math.random() * 3.5,
        hauteur: (Math.random() - 0.5) * 9,
        vitesse: 0.03 + Math.random() * 0.03,
        balancement: Math.random() * Math.PI * 2
      };
      cartes.push(carte);
      scene.add(carte);
    }

    // On bouge la CAMERA, pas les objets : c'est la perspective qui
    // travaille, et la profondeur se voit. Au doigt, pas de survol :
    // le defilement prend le relais comme source de mouvement.
    var visee = { x: 0, y: 0 }, actuel = { x: 0, y: 0 };
    if (!sobre && !souris) {
      window.addEventListener('scroll', function () {
        var h = hote.getBoundingClientRect();
        var avance = h.height ? (-h.top / h.height) : 0;
        visee.y = Math.max(-1, Math.min(1, avance * 2 - 0.2));
        visee.x = Math.sin(avance * Math.PI) * 0.55;
      }, { passive: true });
    } else if (!sobre) {
      window.addEventListener('pointermove', function (e) {
        visee.x = (e.clientX / window.innerWidth - 0.5) * 2;
        visee.y = (e.clientY / window.innerHeight - 0.5) * 2;
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
        cartes[k].position.set(Math.cos(a) * d.rayon,
          d.hauteur + Math.sin(t * 0.5 + d.balancement) * 0.7,
          Math.sin(a) * d.rayon * 0.55 - 8);
        cartes[k].rotation.y = -a + Math.PI / 2;
        cartes[k].rotation.z = Math.sin(t * 0.4 + d.balancement) * 0.14;
      }
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
    if (sobre) { dessiner(); setTimeout(dessiner, 1200); } else { boucle(); }

    // Ne pas faire tourner une scene que personne ne regarde.
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entrees) {
        enPause = !entrees[0].isIntersecting;
      }).observe(hote);
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
  // 6. L'EVENTAIL, LE REFLET, LA REGLE
  // ===========================================================

  // ---- L'eventail : entree en scene, puis inclinaison ---------
  function monterLEventail() {
    var eventail = document.getElementById('eventail');
    if (!eventail) return;

    // L'entree se joue quand les images sont la : jouee avant, on
    // verrait glisser des cadres vides. Plafond d'une seconde pour
    // ne jamais laisser l'eventail invisible sur un reseau lent.
    var images = eventail.querySelectorAll('img');
    var restantes = images.length;
    var jouee = false;
    function jouer() {
      if (jouee) return;
      jouee = true;
      requestAnimationFrame(function () { eventail.classList.add('est-jouee'); });
    }
    images.forEach(function (image) {
      if (image.complete) { if (--restantes === 0) jouer(); return; }
      image.addEventListener('load', function () { if (--restantes === 0) jouer(); });
      image.addEventListener('error', jouer);
    });
    setTimeout(jouer, 1000);

    if (!souris || sobre) return;
    // L'eventail s'incline vers la souris, sur tout le hero : la
    // carte "regarde" le visiteur ou qu'il soit sur le premier ecran.
    var hero = eventail.closest('.hero');
    var visee = { x: 0, y: 0 }, actuel = { x: 0, y: 0 }, enCours = false;
    function boucle() {
      actuel.x += (visee.x - actuel.x) * 0.08;
      actuel.y += (visee.y - actuel.y) * 0.08;
      eventail.style.transform = 'perspective(1400px) rotateY(' + (actuel.x * 9).toFixed(2) +
                                 'deg) rotateX(' + (-actuel.y * 7).toFixed(2) + 'deg)';
      if (Math.abs(visee.x - actuel.x) + Math.abs(visee.y - actuel.y) > 0.002) {
        requestAnimationFrame(boucle);
      } else { enCours = false; }
    }
    hero.addEventListener('pointermove', function (e) {
      var r = hero.getBoundingClientRect();
      visee.x = (e.clientX - r.left) / r.width - 0.5;
      visee.y = (e.clientY - r.top) / r.height - 0.5;
      if (!enCours) { enCours = true; requestAnimationFrame(boucle); }
    });
    hero.addEventListener('pointerleave', function () {
      visee.x = 0; visee.y = 0;
      if (!enCours) { enCours = true; requestAnimationFrame(boucle); }
    });
  }

  // ---- Le reflet : la lumiere suit la souris sur chaque carte --
  function monterLeReflet() {
    if (!souris || sobre) return;
    var courante = null, x = 0, y = 0, prevu = false;
    function ecrire() {
      prevu = false;
      if (!courante) return;
      var r = courante.getBoundingClientRect();
      courante.style.setProperty('--mx', ((x - r.left) / r.width * 100).toFixed(1) + '%');
      courante.style.setProperty('--my', ((y - r.top) / r.height * 100).toFixed(1) + '%');
    }
    document.addEventListener('pointermove', function (e) {
      var illu = e.target.closest && e.target.closest('.illu');
      if (illu !== courante && courante) {
        courante.style.removeProperty('--mx');
        courante.style.removeProperty('--my');
      }
      courante = illu;
      x = e.clientX; y = e.clientY;
      // Une ecriture par image au plus, quel que soit le nombre
      // d'evenements recus entre deux rafraichissements.
      if (courante && !prevu) { prevu = true; requestAnimationFrame(ecrire); }
    }, { passive: true });
  }

  // ---- La regle : trois fusions reelles a faire defiler --------
  // Trois noeuds du referentiel MIXALGO Savane (n25, n15, n35). Ils
  // partagent la meme emettrice, KEZEU : une carte identique, trois
  // cables differents, trois resultats. La lecon : le role n'est pas
  // dans la carte. L'ordre va du plus lisible au plus troublant ; le
  // dernier empeche de croire que le jeu se resume a des mots-cles.
  var LECONS = [
    { e: 'B3', c: 'M3', r: 'A4',
      lecture: "Le circuit rouge de BABADJI se pose sur l'armure de KEZEU : BEMA porte <strong>la maille</strong> des deux." },
    { e: 'B3', c: 'Z8', r: 'L9',
      lecture: "KEZEU donne <strong>l'armure</strong>, MILLA donne <strong>l'orage</strong>. TUEKAM hérite des deux." },
    { e: 'B3', c: 'C7', r: 'N1',
      lecture: "Ici, aucun mot-clé commun : le lien est <strong>dans l'image</strong>, et nulle part ailleurs." }
  ];

  function monterLaRegle() {
    var bloc = document.getElementById('fusion');
    var bouton = document.getElementById('relancer');
    var lecture = document.getElementById('fusion-lecture');
    var legende = document.getElementById('fusion-legende');
    if (!bloc || !bouton) return;
    var index = 0;

    bouton.addEventListener('click', function () {
      index = (index + 1) % LECONS.length;
      var lecon = LECONS[index];
      bloc.classList.remove('est-active');
      void bloc.offsetWidth; // relance l'animation CSS
      bloc.classList.add('est-active');
      // 280 ms : le changement d'image tombe au moment ou les cartes
      // sont de profil, donc invisible.
      setTimeout(function () {
        [['emettrice', lecon.e], ['cable', lecon.c], ['receptrice', lecon.r]].forEach(function (paire) {
          var figure = bloc.querySelector('[data-role="' + paire[0] + '"]');
          poserIllu(figure.querySelector('.illu'), paire[1]);
          figure.querySelector('.regle__nom').textContent = nom(paire[1]);
        });
        // innerHTML sur une chaine CONSTANTE de ce fichier, jamais
        // sur une donnee venue de l'exterieur.
        lecture.innerHTML = lecon.lecture;
        legende.textContent = 'Fusion ' + (index + 1) + ' sur ' + LECONS.length + ' · trios réels du deck';
      }, sobre ? 0 : 280);
    });
  }

  // ===========================================================
  // 7. LA PARTIE DE DEMONSTRATION
  // ===========================================================
  //
  // Une vraie partie, en cinq manches. Chaque manche montre deux
  // cartes ; le visiteur choisit la troisieme parmi quatre.
  //
  // LES TRIOS NE SONT PAS INVENTES
  // ------------------------------
  // Ce sont les noeuds du referentiel MIXALGO Savane
  // (ok_trialgo_backend/referentiels/mixalgo-savane.yml) dont les
  // trois cartes figurent parmi les originaux embarques. Plusieurs
  // s'enchainent (A7 + K4 = B3, puis B3 + M3 = A4) : c'est le
  // chainage du vrai jeu, visible des la demonstration.
  //
  // POURQUOI AUCUN LEURRE NE PEUT ETRE UNE BONNE REPONSE
  // ----------------------------------------------------
  // Une fusion est injective : deux parents donnes n'ont qu'UN
  // enfant (garanti par le referentiel et par la base). Tirer les
  // leurres parmi les autres cartes ne peut donc jamais tomber sur
  // une seconde reponse juste.
  //
  // LE SCORE
  // --------
  // 100 points par bonne reponse, plus 10 par seconde restante, le
  // tout multiplie par la serie en cours (x1, x1.25, x1.5...). La
  // vitesse recompense, mais c'est la regularite qui paie.
  // ===========================================================
  var TRIOS = [
    ['A7', 'K4', 'B3'], ['D9', 'E5', 'F1'], ['P6', 'D8', 'F2'],
    ['Z8', 'B3', 'L9'], ['H4', 'G8', 'W9'], ['B3', 'M3', 'A4'],
    ['B3', 'M8', 'C2'], ['B3', 'C7', 'N1'], ['F2', 'M8', 'Q4'],
    ['C2', 'D9', 'P7']
  ];
  var MANCHES = 5;
  var SECONDES = 20;

  function monterLaPartie() {
    var jeu = document.getElementById('jeu');
    if (!jeu) return;
    var el = {
      manche: document.getElementById('jeu-manche'),
      serie: document.getElementById('jeu-serie'),
      score: document.getElementById('jeu-score'),
      temps: document.getElementById('jeu-temps'),
      e: document.querySelector('#jeu-e .illu'),
      c: document.querySelector('#jeu-c .illu'),
      r: document.querySelector('#jeu-r .illu'),
      mystere: document.getElementById('jeu-mystere'),
      consigne: document.getElementById('jeu-consigne'),
      choix: Array.prototype.slice.call(document.querySelectorAll('#jeu-choix .choix')),
      fin: document.getElementById('jeu-fin'),
      finScore: document.getElementById('jeu-fin-score'),
      finTitre: document.getElementById('jeu-fin-titre'),
      finTexte: document.getElementById('jeu-fin-texte'),
      rejouer: document.getElementById('jeu-rejouer'),
      debut: document.getElementById('jeu-debut'),
      lancer: document.getElementById('jeu-lancer')
    };

    var etat = null;          // la partie en cours
    var minuteur = null;      // requestAnimationFrame du chronometre
    var visible = false;      // le plateau est-il a l'ecran ?

    function nouvellePartie() {
      etat = {
        trios: melanger(TRIOS).slice(0, MANCHES),
        manche: 0, score: 0, serie: 0, justes: 0,
        reponse: null, restant: SECONDES, depart: 0, repondu: false
      };
      el.fin.hidden = true;
      poserManche();
    }

    function poserManche() {
      var trio = etat.trios[etat.manche];
      etat.reponse = trio[2];
      etat.repondu = false;
      etat.restant = SECONDES;

      // Trois leurres, tires hors des trois cartes de la manche.
      var leurres = melanger(CODES.filter(function (c) {
        return trio.indexOf(c) === -1;
      })).slice(0, 3);
      var options = melanger(leurres.concat(trio[2]));

      jeu.classList.remove('est-repondu', 'est-gagne');
      el.mystere.classList.remove('est-revele');
      el.consigne.className = 'jeu__consigne';
      el.consigne.textContent = 'Quelle carte naît de cette fusion ?';
      poserIllu(el.e, trio[0]);
      poserIllu(el.c, trio[1]);

      el.choix.forEach(function (bouton, i) {
        bouton.disabled = false;
        bouton.classList.remove('est-juste', 'est-faux');
        bouton.setAttribute('data-code', options[i]);
        bouton.setAttribute('aria-label', 'Choix ' + (i + 1) + ' : carte ' + nom(options[i]));
        poserIllu(bouton.querySelector('.illu'), options[i]);
      });
      // La face cachee ne prend la reponse qu'APRES le retournement
      // de la manche precedente : sinon le dos laisserait voir, une
      // fraction de seconde, la bonne carte de la manche suivante.
      setTimeout(function () { poserIllu(el.r, trio[2]); }, sobre ? 0 : 450);

      el.manche.textContent = (etat.manche + 1) + ' / ' + MANCHES;
      afficherCompteurs();
      prechargerSuivante();
      demarrerChrono();
    }

    // Les images de la manche suivante se chargent pendant qu'on
    // reflechit a celle-ci : la suivante s'affiche d'un coup.
    function prechargerSuivante() {
      var suivante = etat.trios[etat.manche + 1];
      if (!suivante) return;
      suivante.forEach(function (code) { (new Image()).src = visuel(code, 480); });
    }

    function afficherCompteurs() {
      el.score.textContent = Math.round(etat.score);
      el.serie.textContent = etat.serie ? '×' + (1 + etat.serie * 0.25) : '0';
    }

    // ---- Le chronometre ----------------------------------------
    // Il ne tourne que si le plateau est a l'ecran : personne ne
    // perd une manche parce qu'il lisait la section du dessus.
    function demarrerChrono() {
      cancelAnimationFrame(minuteur);
      etat.depart = performance.now() - (SECONDES - etat.restant) * 1000;
      function tic(maintenant) {
        if (!etat || etat.repondu) return;
        if (!visible || document.hidden) {
          // En pause : on decale le depart pour ne rien decompter.
          etat.depart = maintenant - (SECONDES - etat.restant) * 1000;
          minuteur = requestAnimationFrame(tic);
          return;
        }
        etat.restant = Math.max(0, SECONDES - (maintenant - etat.depart) / 1000);
        el.temps.style.transform = 'scaleX(' + (etat.restant / SECONDES).toFixed(4) + ')';
        if (etat.restant <= 0) { repondre(null); return; }
        minuteur = requestAnimationFrame(tic);
      }
      minuteur = requestAnimationFrame(tic);
    }

    function repondre(bouton) {
      if (!etat || etat.repondu) return;
      etat.repondu = true;
      cancelAnimationFrame(minuteur);

      var choisi = bouton ? bouton.getAttribute('data-code') : null;
      var juste = choisi === etat.reponse;
      jeu.classList.add('est-repondu');
      el.choix.forEach(function (b) {
        b.disabled = true;
        if (b.getAttribute('data-code') === etat.reponse) b.classList.add('est-juste');
      });
      el.mystere.classList.add('est-revele');

      if (juste) {
        etat.justes++;
        etat.score += (100 + Math.round(etat.restant) * 10) * (1 + etat.serie * 0.25);
        etat.serie++;
        jeu.classList.add('est-gagne');
        el.consigne.className = 'jeu__consigne est-juste';
        el.consigne.textContent = 'Fusion trouvée : ' + nom(etat.reponse) + '.';
      } else {
        etat.serie = 0;
        if (bouton) bouton.classList.add('est-faux');
        el.consigne.className = 'jeu__consigne est-faux';
        el.consigne.textContent = (bouton ? 'Raté' : 'Temps écoulé') +
          ' : la réponse était ' + nom(etat.reponse) + '.';
      }
      afficherCompteurs();

      // Le temps de voir la bonne carte se retourner, puis la suite.
      setTimeout(function () {
        etat.manche++;
        if (etat.manche < MANCHES) poserManche(); else terminer();
      }, juste ? 1500 : 2300);
    }

    function terminer() {
      var j = etat.justes;
      el.finScore.textContent = Math.round(etat.score);
      el.finTitre.textContent = j === MANCHES ? 'Œil de lynx.' :
                                j >= 3 ? 'Bien vu.' :
                                j >= 1 ? 'Ça vient.' : "L'œil s'entraîne.";
      el.finTexte.textContent = j + ' fusion' + (j > 1 ? 's' : '') + ' trouvée' + (j > 1 ? 's' : '') +
        ' sur ' + MANCHES + '. Le deck complet en compte 46, sur cinq distances.';
      el.fin.hidden = false;
      el.rejouer.focus({ preventScroll: true });
    }

    el.choix.forEach(function (bouton) {
      bouton.addEventListener('click', function () { repondre(bouton); });
    });
    el.rejouer.addEventListener('click', nouvellePartie);
    el.lancer.addEventListener('click', function () {
      el.debut.hidden = true;
      nouvellePartie();
    });

    // Touches 1 a 4, seulement quand le plateau est a l'ecran : ces
    // chiffres ne doivent pas etre captures ailleurs dans la page.
    document.addEventListener('keydown', function (e) {
      if (!etat || !visible || e.ctrlKey || e.metaKey || e.altKey) return;
      var n = parseInt(e.key, 10);
      if (n >= 1 && n <= 4 && el.choix[n - 1] && !el.choix[n - 1].disabled) {
        repondre(el.choix[n - 1]);
      }
    });

    // La partie ne commence que sur un GESTE : le bouton « Lancer la
    // partie ». Un depart automatique a l'apparition du plateau avait
    // ete essaye, et c'etait un piege : le visiteur lisait encore le
    // titre que sa premiere manche etait deja perdue au chronometre.
    // Le plateau garde en attendant l'exemple pose dans le HTML.
    el.choix.forEach(function (b) { b.disabled = true; });
    el.debut.hidden = false;

    // `visible` ne sert plus qu'a suspendre le chronometre quand le
    // plateau sort de l'ecran en pleine partie.
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entrees) {
        visible = entrees[0].isIntersecting;
      }, { threshold: 0.35 }).observe(jeu);
    } else {
      visible = true;
    }
  }

  // ===========================================================
  // 8. LE DECK ET SA VISIONNEUSE
  // ===========================================================
  //
  // Douze illustrations visibles, les autres repliees derriere un
  // bouton : la page ne s'allonge que pour qui le demande. Un clic
  // ouvre la visionneuse (<dialog>), qui sait de base piéger le
  // focus, se fermer a Echap et rendre le reste de la page inerte.
  // ===========================================================
  function monterLeDeck() {
    var grille = document.getElementById('grille-deck');
    var plus = document.getElementById('deck-plus');
    var dialogue = document.getElementById('visionneuse');
    if (!grille) return;

    if (plus && grille.querySelector('.est-replie')) {
      plus.hidden = false;
      plus.addEventListener('click', function () {
        grille.querySelectorAll('.est-replie').forEach(function (li) { li.classList.remove('est-replie'); });
        plus.hidden = true;
      });
    }

    if (!dialogue || typeof dialogue.showModal !== 'function') return;
    var image = document.getElementById('visionneuse-image');
    var legende = document.getElementById('visionneuse-legende');
    var index = 0;

    // La liste est relue a chaque ouverture : le studio a pu
    // remplacer la grille entre-temps.
    function vignettes() {
      return Array.prototype.slice.call(grille.querySelectorAll('.vignette'))
        .filter(function (v) { return !v.closest('.est-replie'); });
    }

    function montrer(i) {
      var liste = vignettes();
      index = (i + liste.length) % liste.length;
      var v = liste[index];
      var code = v.getAttribute('data-code');
      var url = v.getAttribute('data-url');
      image.src = url || visuel(code, 960);
      var libelle = v.getAttribute('data-nom') || nom(code);
      image.alt = 'Carte ' + libelle + (code ? ' (' + code + ')' : '');
      legende.textContent = libelle + (code && code !== libelle ? ' · ' + code : '') +
                            ' — ' + (index + 1) + ' / ' + liste.length;
    }

    grille.addEventListener('click', function (e) {
      var v = e.target.closest('.vignette');
      if (!v) return;
      montrer(vignettes().indexOf(v));
      dialogue.showModal();
    });
    dialogue.addEventListener('click', function (e) {
      if (e.target.closest('[data-fermer]')) { dialogue.close(); return; }
      var pas = e.target.closest('[data-pas]');
      if (pas) { montrer(index + parseInt(pas.getAttribute('data-pas'), 10)); return; }
      // Un appui hors de l'image et des boutons = sur le fond.
      if (!e.target.closest('img, .rond')) dialogue.close();
    });
    dialogue.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowRight') montrer(index + 1);
      if (e.key === 'ArrowLeft') montrer(index - 1);
    });
    // Glisser au doigt : un geste horizontal franc change de carte.
    var depart = null;
    dialogue.addEventListener('pointerdown', function (e) { depart = e.clientX; });
    dialogue.addEventListener('pointerup', function (e) {
      if (depart === null) return;
      var ecart = e.clientX - depart;
      depart = null;
      if (Math.abs(ecart) > 60) montrer(index + (ecart < 0 ? 1 : -1));
    });

    // La taille reelle du deck en ligne : une information vivante
    // qu'une page statique ne peut pas connaitre. Sans reponse, la
    // legende du HTML reste, et elle reste vraie.
    var etat = document.getElementById('deck-etat');
    recuperer('/api/public/games').then(function (jeux) {
      if (!jeux || !jeux.length) return;
      return recuperer('/api/public/games/' + jeux[0].id + '/cards?limite=500').then(function (cartes) {
        if (!cartes || !cartes.length || !etat) return;
        etat.textContent = vignettes().length + ' illustrations · ' + cartes.length +
                           ' cartes dans le deck ' + (jeux[0].name || 'en ligne');
      });
    }).catch(function () { /* L'API dort : on garde le texte du HTML. */ });
  }

  // ===========================================================
  // 9. L'APPAREIL
  // ===========================================================
  // Le QR code est VISIBLE PAR DEFAUT et retire ici quand
  // l'appareil est deja un Android. Dans ce sens, un visiteur sans
  // script voit un QR de trop (sans gravite) plutot qu'un pont
  // manquant (qui lui couterait le parcours).
  function adapterAuTerminal() {
    var marque = (navigator.userAgentData && navigator.userAgentData.platform) ||
                 navigator.userAgent || '';
    if (!/android/i.test(marque)) return;
    var pont = document.getElementById('pont');
    var bouton = document.getElementById('bouton-apk');
    if (pont) pont.remove();
    if (bouton) bouton.lastChild.textContent = ' Installer sur cet appareil';
  }

  // ===========================================================
  // 10. LE CONTENU PUBLIE DEPUIS LE STUDIO
  // ===========================================================
  //
  // GET /api/public/site/accueil renvoie ce que l'admin a publie
  // dans l'ecran « Vitrine » du studio. TOUT EST OPTIONNEL : un champ
  // absent ou vide laisse le texte du HTML en place. C'est ce qui
  // permet a la page de rester juste si l'API est injoignable, ou
  // si rien n'a jamais ete publie.
  //
  // SECURITE
  // --------
  // Le contenu vient d'un compte admin, mais il transite par le
  // reseau et une base : on le traite comme une donnee, jamais comme
  // du code. Textes poses par textContent (aucun HTML interprete),
  // images acceptees seulement en http(s) -- le serveur le verifie
  // deja, on ne s'en remet pas a lui seul.
  // ===========================================================
  function urlSure(url) {
    return typeof url === 'string' && /^https?:\/\//i.test(url) ? url : null;
  }

  function lire(objet, chemin) {
    return chemin.split('.').reduce(function (o, cle) {
      return o && typeof o === 'object' ? o[cle] : undefined;
    }, objet);
  }

  function appliquerTextes(contenu) {
    document.querySelectorAll('[data-cms]').forEach(function (noeud) {
      var valeur = lire(contenu, noeud.getAttribute('data-cms'));
      if (typeof valeur === 'string' && valeur.trim()) noeud.textContent = valeur.trim();
    });
  }

  function figureIllu(element) {
    // Fabrique une <figure class="illu"> pour une image du studio.
    var figure = document.createElement('figure');
    figure.className = 'illu';
    var image = document.createElement('img');
    image.src = element.url;
    image.width = 480; image.height = 600;
    image.loading = 'lazy'; image.decoding = 'async';
    image.alt = 'Carte ' + (element.nom || element.code || '');
    figure.appendChild(image);
    if (element.code) {
      var code = document.createElement('span');
      code.className = 'illu__code';
      code.textContent = element.code;
      figure.appendChild(code);
    }
    return figure;
  }

  function appliquerGalerie(galerie) {
    var elements = (Array.isArray(galerie) ? galerie : [])
      .map(function (g) {
        return g && { url: urlSure(g.image_url), nom: (g.nom || '').trim(), code: (g.code || '').trim() };
      })
      .filter(function (g) { return g && g.url; });
    if (!elements.length) return;

    // -- L'eventail : les trois premieres images ------------------
    if (elements.length >= 3) {
      ['e', 'c', 'r'].forEach(function (role, i) {
        var figure = document.querySelector('.eventail__carte--' + role + ' .illu');
        poserIllu(figure, elements[i].code, elements[i].url, elements[i].nom || elements[i].code);
      });
    }

    // -- Le bandeau : la galerie repartie sur deux rangees ---------
    var rangees = document.querySelectorAll('[data-cms="galerie-rangee"]');
    if (rangees.length === 2 && elements.length >= 4) {
      var moitie = Math.ceil(elements.length / 2);
      [elements.slice(0, moitie), elements.slice(moitie)].forEach(function (lot, i) {
        var rangee = rangees[i];
        rangee.textContent = '';
        // Trop peu d'images pour remplir la largeur : on repete le
        // lot jusqu'a au moins dix, sinon la boucle laisserait un trou.
        var plein = lot.slice();
        while (plein.length < 10) plein = plein.concat(lot);
        plein.forEach(function (g) { rangee.appendChild(decor(figureIllu(g))); });
        var copie = document.createElement('div');
        copie.style.display = 'contents';
        copie.setAttribute('aria-hidden', 'true');
        plein.forEach(function (g) { copie.appendChild(decor(figureIllu(g))); });
        rangee.appendChild(copie);
      });
    }

    // -- La grille du deck ------------------------------------------
    var grille = document.getElementById('grille-deck');
    if (grille) {
      grille.textContent = '';
      elements.forEach(function (g) {
        var li = document.createElement('li');
        var bouton = document.createElement('button');
        bouton.type = 'button';
        bouton.className = 'vignette';
        bouton.setAttribute('data-curseur', 'Voir');
        bouton.setAttribute('data-code', g.code);
        bouton.setAttribute('data-url', g.url);
        bouton.setAttribute('data-nom', g.nom || g.code);
        bouton.appendChild(figureIllu(g));
        li.appendChild(bouton);
        grille.appendChild(li);
      });
      var plus = document.getElementById('deck-plus');
      if (plus) plus.hidden = true;
    }
  }

  // Une image du bandeau est decorative : alt vide.
  function decor(figure) {
    var image = figure.querySelector('img');
    if (image) image.alt = '';
    return figure;
  }

  function monterLeContenu() {
    recuperer('/api/public/site/accueil').then(function (reponse) {
      var contenu = reponse && reponse.contenu;
      if (!contenu || typeof contenu !== 'object') return;
      appliquerTextes(contenu);
      appliquerGalerie(contenu.galerie);
    }).catch(function () { /* Rien de publie, ou API injoignable. */ });
  }

  // ===========================================================
  // 11. DEMARRAGE
  // ===========================================================
  function demarrer() {
    // Les revelations d'abord (voir le bloc 1), puis tout ce qui
    // conditionne la navigation, puis le decor. Chaque bloc est
    // isole : une erreur dans l'un n'empeche pas les suivants.
    [monterLesRevelations, monterLEntete, monterLeTiroir, monterLeCurseur,
     monterLEventail, monterLeReflet, monterLaRegle, monterLaPartie,
     monterLeDeck, adapterAuTerminal, monterLeContenu, monterLeCiel
    ].forEach(function (bloc) {
      try { bloc(); } catch (e) {
        if (window.console) console.error('[vitrine] ' + bloc.name, e);
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', demarrer);
  } else {
    demarrer();
  }
})();
