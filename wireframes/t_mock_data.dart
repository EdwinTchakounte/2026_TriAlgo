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
  // TRIOS COMPLETS (E + C = R)
  // ---------------------------------------------------------------
  // Chaque trio est une combinaison valide emettrice + cable = receptrice.
  // Le wireframe utilise ces trios pour generer des questions jouables.
  // ---------------------------------------------------------------

  /// Les 3 trios du wireframe (1 par question type).
  static const List<Map<String, dynamic>> mockTrios = [
    {'emettrice': 'e1', 'cable': 'c1', 'receptrice': 'r1'},  // Lion + Miroir = Lion Miroir
    {'emettrice': 'e2', 'cable': 'c2', 'receptrice': 'r2'},  // Aigle + Rotation = Aigle Rotation
    {'emettrice': 'e3', 'cable': 'c3', 'receptrice': 'r3'},  // Requin + Couleur = Requin Couleur
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
}
