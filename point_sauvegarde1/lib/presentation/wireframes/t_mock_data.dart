// =============================================================
// FICHIER : lib/presentation/wireframes/t_mock_data.dart
// ROLE   : Donnees fictives COMPLETES pour le wireframe jouable
// COUCHE : Presentation > Wireframes
// =============================================================
//
// CE FICHIER ALIMENTE TOUT LE WIREFRAME.
// ----------------------------------------
// Il contient des URLs d'images REELLES pour simuler les cartes
// du jeu (emettrices, cables, receptrices) et permettre de jouer
// une vraie partie dans le wireframe.
//
// Les images viennent de picsum.photos (service d'images placeholder).
// Chaque "seed" genere toujours la MEME image, ce qui garantit
// la coherence visuelle entre les sessions.
//
// CONVENTION DES SEEDS :
//   - "lion", "tiger", "eagle"... -> emettrices (animaux)
//   - "mirror", "rotate", "color" -> cables (transformations)
//   - "lion-mirror", "tiger-rotate" -> receptrices (resultats)
// =============================================================

/// Donnees fictives pour le wireframe jouable de TRIALGO.
///
/// Contient des URLs d'images, des profils joueurs, des niveaux
/// et toutes les donnees necessaires pour simuler l'application
/// complete sans backend.
class MockData {

  // ---------------------------------------------------------------
  // CHEMIN DES ASSETS LOCAUX (mascottes)
  // ---------------------------------------------------------------
  // Les mascottes du jeu sont dans le dossier statics/.
  // Enregistrees dans pubspec.yaml sous la cle "assets".
  // ---------------------------------------------------------------

  /// Chemin vers la mascotte principale (trio de personnages).
  static const String mascotMain = 'statics/img1.jpeg';

  /// Chemin vers la mascotte secondaire (duo de personnages).
  static const String mascotDuo = 'statics/img2.jpeg';

  /// Chemin vers le logo officiel TRIALGO.
  static const String logo = 'statics/logo.png';

  // ---------------------------------------------------------------
  // UTILISATEUR FICTIF
  // ---------------------------------------------------------------

  /// Profil du joueur fictif connecte.
  static const Map<String, dynamic> mockUser = {
    'id': 'mock-uuid-001',
    'username': 'LionMaster',
    'totalScore': 4250,
    'currentLevel': 7,
    'lives': 3,
    'maxLives': 5,
    'livesLastRefill': '2026-03-23T14:00:00Z',
  };

  // ---------------------------------------------------------------
  // CARTES DU JEU AVEC URLS D'IMAGES REELLES
  // ---------------------------------------------------------------
  // Chaque carte a une URL d'image reseau (picsum.photos).
  // Le parametre "seed" garantit que l'image est toujours la meme.
  //
  // Format URL : https://picsum.photos/seed/{seed}/{largeur}/{hauteur}
  //
  // EMETTRICES : images de base (animaux, nature)
  // CABLES     : images abstraites (patterns, textures)
  // RECEPTRICES : images transformees (variantes des emettrices)
  // ---------------------------------------------------------------

  // --- EMETTRICES (images de base) ---

  /// Emettrice 1 : image de base "Lion".
  static const Map<String, dynamic> emettrice1 = {
    'id': 'e1',
    'label': 'Lion',
    'type': 'emettrice',
    'imageUrl': 'https://picsum.photos/seed/trialgo-lion/200/200',
  };

  /// Emettrice 2 : image de base "Aigle".
  static const Map<String, dynamic> emettrice2 = {
    'id': 'e2',
    'label': 'Aigle',
    'type': 'emettrice',
    'imageUrl': 'https://picsum.photos/seed/trialgo-eagle/200/200',
  };

  /// Emettrice 3 : image de base "Requin".
  static const Map<String, dynamic> emettrice3 = {
    'id': 'e3',
    'label': 'Requin',
    'type': 'emettrice',
    'imageUrl': 'https://picsum.photos/seed/trialgo-shark/200/200',
  };

  // --- CABLES (images de transformation) ---

  /// Cable 1 : transformation "Miroir".
  static const Map<String, dynamic> cable1 = {
    'id': 'c1',
    'label': 'Miroir',
    'type': 'cable',
    'imageUrl': 'https://picsum.photos/seed/trialgo-mirror/200/200',
  };

  /// Cable 2 : transformation "Rotation".
  static const Map<String, dynamic> cable2 = {
    'id': 'c2',
    'label': 'Rotation',
    'type': 'cable',
    'imageUrl': 'https://picsum.photos/seed/trialgo-rotate/200/200',
  };

  /// Cable 3 : transformation "Couleur".
  static const Map<String, dynamic> cable3 = {
    'id': 'c3',
    'label': 'Couleur',
    'type': 'cable',
    'imageUrl': 'https://picsum.photos/seed/trialgo-color/200/200',
  };

  // --- RECEPTRICES (images resultat) ---

  /// Receptrice 1 : "Lion + Miroir" = Lion Miroir.
  static const Map<String, dynamic> receptrice1 = {
    'id': 'r1',
    'label': 'Lion Miroir',
    'type': 'receptrice',
    'imageUrl': 'https://picsum.photos/seed/trialgo-lionmirror/200/200',
  };

  /// Receptrice 2 : "Aigle + Rotation" = Aigle Rotation.
  static const Map<String, dynamic> receptrice2 = {
    'id': 'r2',
    'label': 'Aigle Rotation',
    'type': 'receptrice',
    'imageUrl': 'https://picsum.photos/seed/trialgo-eaglerot/200/200',
  };

  /// Receptrice 3 : "Requin + Couleur" = Requin Couleur.
  static const Map<String, dynamic> receptrice3 = {
    'id': 'r3',
    'label': 'Requin Couleur',
    'type': 'receptrice',
    'imageUrl': 'https://picsum.photos/seed/trialgo-sharkcolor/200/200',
  };

  // ---------------------------------------------------------------
  // CARTES SUPPLEMENTAIRES (pour enrichir le graphe D2)
  // ---------------------------------------------------------------
  // Receptrices supplementaires qui servent de resultats dans les
  // chaines D2. En D2, la receptrice d'un noeud devient l'emettrice
  // du noeud suivant, creant une relation entre les noeuds.
  // ---------------------------------------------------------------

  /// Receptrice 4 : resultat de la chaine "Lion Miroir + Rotation".
  static const Map<String, dynamic> receptrice4 = {
    'id': 'r4',
    'label': 'Lion Spirale',
    'type': 'receptrice',
    'imageUrl': 'https://picsum.photos/seed/trialgo-lionspiral/200/200',
  };

  /// Receptrice 5 : resultat de la chaine "Aigle Rotation + Couleur".
  static const Map<String, dynamic> receptrice5 = {
    'id': 'r5',
    'label': 'Aigle Prisme',
    'type': 'receptrice',
    'imageUrl': 'https://picsum.photos/seed/trialgo-eagleprism/200/200',
  };

  /// Receptrice 6 : resultat de la chaine "Requin Couleur + Miroir".
  static const Map<String, dynamic> receptrice6 = {
    'id': 'r6',
    'label': 'Requin Reflet',
    'type': 'receptrice',
    'imageUrl': 'https://picsum.photos/seed/trialgo-sharkreflet/200/200',
  };

  // ---------------------------------------------------------------
  // GRAPHE DE NOEUDS (structure fondamentale du jeu)
  // ---------------------------------------------------------------
  //
  // UN NOEUD = un trio de 3 cartes : E + C = R
  //
  // Chaque noeud a un index unique et contient les IDs des 3 cartes.
  // Les noeuds sont relies entre eux pour former le graphe :
  //   - En D1 : on utilise un noeud isole (E + C = R)
  //   - En D2 : on chaine 2 noeuds ou la R du noeud N devient
  //             la E du noeud N+1
  //
  // Exemple de chaine D2 :
  //   Noeud 0 : E1 + C1 = R1     (Lion + Miroir = Lion Miroir)
  //   Noeud 3 : R1 + C2 = R4     (Lion Miroir + Rotation = Lion Spirale)
  //   => En D2, le trio presente est (R1, C2, R4) avec R1 = lien
  //
  // Le champ 'parentNodeIndex' indique quel noeud fournit la E
  // (via sa R). null = noeud racine (pas de parent, utilisable en D1).
  // ---------------------------------------------------------------

  /// Les 6 noeuds du graphe mock.
  ///
  /// Noeuds 0-2 : noeuds racines (D1) — pas de parent.
  /// Noeuds 3-5 : noeuds chaines (D2) — leur E est la R d'un parent.
  static const List<Map<String, dynamic>> mockNodes = [
    // --- NOEUDS RACINES (D1) ---
    // Index 0 : Lion + Miroir = Lion Miroir
    {
      'index': 0,
      'emettriceId': 'e1',
      'cableId': 'c1',
      'receptriceId': 'r1',
      'parentNodeIndex': null,  // Noeud racine, pas de parent.
    },
    // Index 1 : Aigle + Rotation = Aigle Rotation
    {
      'index': 1,
      'emettriceId': 'e2',
      'cableId': 'c2',
      'receptriceId': 'r2',
      'parentNodeIndex': null,
    },
    // Index 2 : Requin + Couleur = Requin Couleur
    {
      'index': 2,
      'emettriceId': 'e3',
      'cableId': 'c3',
      'receptriceId': 'r3',
      'parentNodeIndex': null,
    },

    // --- NOEUDS CHAINES (D2) ---
    // Index 3 : R1 + Rotation = Lion Spirale
    //   Parent = Noeud 0 (R1 = Lion Miroir devient E de ce noeud)
    {
      'index': 3,
      'emettriceId': 'r1',   // E = R du parent (Lion Miroir)
      'cableId': 'c2',       // Cable = Rotation
      'receptriceId': 'r4',  // R = Lion Spirale
      'parentNodeIndex': 0,  // Chaine depuis le noeud 0.
    },
    // Index 4 : R2 + Couleur = Aigle Prisme
    //   Parent = Noeud 1 (R2 = Aigle Rotation devient E)
    {
      'index': 4,
      'emettriceId': 'r2',   // E = R du parent (Aigle Rotation)
      'cableId': 'c3',       // Cable = Couleur
      'receptriceId': 'r5',  // R = Aigle Prisme
      'parentNodeIndex': 1,  // Chaine depuis le noeud 1.
    },
    // Index 5 : R3 + Miroir = Requin Reflet
    //   Parent = Noeud 2 (R3 = Requin Couleur devient E)
    {
      'index': 5,
      'emettriceId': 'r3',   // E = R du parent (Requin Couleur)
      'cableId': 'c1',       // Cable = Miroir
      'receptriceId': 'r6',  // R = Requin Reflet
      'parentNodeIndex': 2,  // Chaine depuis le noeud 2.
    },
  ];

  // ---------------------------------------------------------------
  // TABLE DES NOEUDS DEJA UTILISES
  // ---------------------------------------------------------------
  // Simule la table Supabase qui tracke les noeuds deja joues
  // par le joueur. Dans la vraie app, cette liste viendra de la BDD.
  // Les index correspondent aux noeuds dans mockNodes.
  // ---------------------------------------------------------------

  /// Index des noeuds que le joueur a deja utilises/joues.
  /// Mutable car le jeu ajoute des index au fil des parties.
  static final List<int> mockUsedNodeIndices = [0, 1];

  // ---------------------------------------------------------------
  // TRIOS COMPLETS (E + C = R) — compatibilite ascendante
  // ---------------------------------------------------------------
  // Conserve pour compatibilite avec le code existant.
  // Les nouveaux ecrans utilisent mockNodes a la place.
  // ---------------------------------------------------------------

  /// Les 3 trios de base (noeuds racines).
  static const List<Map<String, dynamic>> mockTrios = [
    {'emettrice': 'e1', 'cable': 'c1', 'receptrice': 'r1'},
    {'emettrice': 'e2', 'cable': 'c2', 'receptrice': 'r2'},
    {'emettrice': 'e3', 'cable': 'c3', 'receptrice': 'r3'},
  ];

  // ---------------------------------------------------------------
  // DISTRACTEURS (mauvaises reponses avec images)
  // ---------------------------------------------------------------
  // 9 images differentes qui servent de mauvaises reponses.
  // Elles doivent etre visuellement plausibles.
  // ---------------------------------------------------------------

  /// Les 9 distracteurs avec images.
  static const List<Map<String, dynamic>> mockDistractors = [
    {'id': 'd1', 'label': 'Tigre',     'imageUrl': 'https://picsum.photos/seed/trialgo-d1/200/200'},
    {'id': 'd2', 'label': 'Renard',    'imageUrl': 'https://picsum.photos/seed/trialgo-d2/200/200'},
    {'id': 'd3', 'label': 'Panda',     'imageUrl': 'https://picsum.photos/seed/trialgo-d3/200/200'},
    {'id': 'd4', 'label': 'Dauphin',   'imageUrl': 'https://picsum.photos/seed/trialgo-d4/200/200'},
    {'id': 'd5', 'label': 'Loup',      'imageUrl': 'https://picsum.photos/seed/trialgo-d5/200/200'},
    {'id': 'd6', 'label': 'Ours',      'imageUrl': 'https://picsum.photos/seed/trialgo-d6/200/200'},
    {'id': 'd7', 'label': 'Serpent',   'imageUrl': 'https://picsum.photos/seed/trialgo-d7/200/200'},
    {'id': 'd8', 'label': 'Faucon',    'imageUrl': 'https://picsum.photos/seed/trialgo-d8/200/200'},
    {'id': 'd9', 'label': 'Tortue',    'imageUrl': 'https://picsum.photos/seed/trialgo-d9/200/200'},
  ];

  // ---------------------------------------------------------------
  // TOUTES LES CARTES (pour lookup rapide par ID)
  // ---------------------------------------------------------------

  /// Map de toutes les cartes indexees par ID.
  /// Permet de retrouver une carte rapidement : allCards['e1']
  static const Map<String, Map<String, dynamic>> allCards = {
    'e1': emettrice1, 'e2': emettrice2, 'e3': emettrice3,
    'c1': cable1,     'c2': cable2,     'c3': cable3,
    'r1': receptrice1, 'r2': receptrice2, 'r3': receptrice3,
    'r4': receptrice4, 'r5': receptrice5, 'r6': receptrice6,
  };

  // ---------------------------------------------------------------
  // CLASSEMENT FICTIF
  // ---------------------------------------------------------------

  /// Top 10 des meilleurs joueurs.
  static const List<Map<String, dynamic>> mockLeaderboard = [
    {'rank': 1, 'username': 'DragonSlayer',  'score': 12500, 'level': 15, 'isCurrentUser': false},
    {'rank': 2, 'username': 'PixelQueen',    'score': 9800,  'level': 12, 'isCurrentUser': false},
    {'rank': 3, 'username': 'CodeNinja',     'score': 7600,  'level': 10, 'isCurrentUser': false},
    {'rank': 4, 'username': 'LionMaster',    'score': 4250,  'level': 7,  'isCurrentUser': true},
    {'rank': 5, 'username': 'StarGazer',     'score': 3900,  'level': 6,  'isCurrentUser': false},
    {'rank': 6, 'username': 'MoonWalker',    'score': 3200,  'level': 5,  'isCurrentUser': false},
    {'rank': 7, 'username': 'ThunderBolt',   'score': 2800,  'level': 5,  'isCurrentUser': false},
    {'rank': 8, 'username': 'IcePhoenix',    'score': 2100,  'level': 4,  'isCurrentUser': false},
    {'rank': 9, 'username': 'ShadowFox',     'score': 1500,  'level': 3,  'isCurrentUser': false},
    {'rank': 10, 'username': 'NovaStar',     'score': 900,   'level': 2,  'isCurrentUser': false},
  ];

  // ---------------------------------------------------------------
  // HISTORIQUE DES SESSIONS
  // ---------------------------------------------------------------

  /// Dernieres sessions jouees.
  static const List<Map<String, dynamic>> mockSessionHistory = [
    {'level': 7, 'score': 180, 'correct': 6, 'wrong': 2, 'passed': true,  'date': '23 mars'},
    {'level': 6, 'score': 210, 'correct': 8, 'wrong': 2, 'passed': true,  'date': '22 mars'},
    {'level': 6, 'score': 90,  'correct': 4, 'wrong': 6, 'passed': false, 'date': '22 mars'},
    {'level': 5, 'score': 150, 'correct': 7, 'wrong': 1, 'passed': true,  'date': '21 mars'},
    {'level': 4, 'score': 175, 'correct': 8, 'wrong': 2, 'passed': true,  'date': '20 mars'},
  ];

  // ---------------------------------------------------------------
  // CARTE DES NIVEAUX
  // ---------------------------------------------------------------

  /// Configuration des 12 premiers niveaux.
  static const List<Map<String, dynamic>> mockLevels = [
    {'level': 1,  'unlocked': true,  'completed': true,  'stars': 3, 'label': 'Decouverte',     'distance': 'D1', 'configs': 'A'},
    {'level': 2,  'unlocked': true,  'completed': true,  'stars': 3, 'label': 'Premiers pas',   'distance': 'D1', 'configs': 'A'},
    {'level': 3,  'unlocked': true,  'completed': true,  'stars': 2, 'label': 'En route',       'distance': 'D1', 'configs': 'A'},
    {'level': 4,  'unlocked': true,  'completed': true,  'stars': 3, 'label': 'Le Cable',       'distance': 'D1', 'configs': 'A+B'},
    {'level': 5,  'unlocked': true,  'completed': true,  'stars': 2, 'label': 'Double defi',    'distance': 'D1', 'configs': 'A+B'},
    {'level': 6,  'unlocked': true,  'completed': true,  'stars': 2, 'label': 'Confirmation',   'distance': 'D1', 'configs': 'A+B'},
    {'level': 7,  'unlocked': true,  'completed': false, 'stars': 0, 'label': 'Quintettes',     'distance': 'D2', 'configs': 'A+B'},
    {'level': 8,  'unlocked': false, 'completed': false, 'stars': 0, 'label': 'Chaines',        'distance': 'D2', 'configs': 'A+B'},
    {'level': 9,  'unlocked': false, 'completed': false, 'stars': 0, 'label': 'Complexite',     'distance': 'D2', 'configs': 'A+B'},
    {'level': 10, 'unlocked': false, 'completed': false, 'stars': 0, 'label': 'Expert D2',      'distance': 'D2', 'configs': 'A+B'},
    {'level': 11, 'unlocked': false, 'completed': false, 'stars': 0, 'label': 'Cable pur',      'distance': 'D2', 'configs': 'B'},
    {'level': 12, 'unlocked': false, 'completed': false, 'stars': 0, 'label': 'Transformation', 'distance': 'D2', 'configs': 'B'},
  ];

  // ---------------------------------------------------------------
  // DECKS DE CARTES (boites physiques)
  // ---------------------------------------------------------------

  /// Les 6 decks disponibles dans l'univers TRIALGO.
  static const List<Map<String, dynamic>> mockDecks = [
    {
      'id': 'deck-savane',
      'name': 'Savane',
      'description': 'Lions, aigles et elephants de la savane africaine',
      'cardCount': 50,
      'imageUrl': 'https://picsum.photos/seed/deck-savane/300/400',
      'color': 0xFFFF6B35,
      'isUnlocked': true,
    },
    {
      'id': 'deck-ocean',
      'name': 'Ocean',
      'description': 'Requins, baleines et dauphins des profondeurs',
      'cardCount': 50,
      'imageUrl': 'https://picsum.photos/seed/deck-ocean/300/400',
      'color': 0xFF42A5F5,
      'isUnlocked': false,
    },
    {
      'id': 'deck-foret',
      'name': 'Foret',
      'description': 'Renards, cerfs et hiboux de la foret enchantee',
      'cardCount': 50,
      'imageUrl': 'https://picsum.photos/seed/deck-foret/300/400',
      'color': 0xFF66BB6A,
      'isUnlocked': false,
    },
    {
      'id': 'deck-arctique',
      'name': 'Arctique',
      'description': 'Ours polaires, phoques et pingouins du grand nord',
      'cardCount': 50,
      'imageUrl': 'https://picsum.photos/seed/deck-arctique/300/400',
      'color': 0xFF80DEEA,
      'isUnlocked': false,
    },
    {
      'id': 'deck-jungle',
      'name': 'Jungle',
      'description': 'Singes, perroquets et jaguars de la jungle tropicale',
      'cardCount': 50,
      'imageUrl': 'https://picsum.photos/seed/deck-jungle/300/400',
      'color': 0xFFF7C948,
      'isUnlocked': false,
    },
    {
      'id': 'deck-desert',
      'name': 'Desert',
      'description': 'Scorpions, fennecs et chameaux du desert brulant',
      'cardCount': 50,
      'imageUrl': 'https://picsum.photos/seed/deck-desert/300/400',
      'color': 0xFFFF8A65,
      'isUnlocked': false,
    },
  ];

  /// Le deck actuellement actif pour le joueur mock.
  static const String activeDeckId = 'deck-savane';
}
