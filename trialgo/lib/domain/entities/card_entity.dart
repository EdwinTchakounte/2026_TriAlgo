// =============================================================
// FICHIER : lib/domain/entities/card_entity.dart
// ROLE   : Definir la structure d'une CARTE dans le jeu TRIALGO
// COUCHE : Domain > Entities
// =============================================================
//
// QU'EST-CE QU'UNE ENTITE ?
// -------------------------
// Une entite est un objet metier PUR. Elle represente un concept
// du monde reel (ici, une carte du jeu) sous forme de code.
//
// Regles d'une entite dans Clean Architecture :
//   1. Elle ne depend de RIEN (pas de Flutter, pas de Supabase)
//   2. Elle ne sait PAS comment elle est stockee (pas de fromJson)
//   3. Elle contient uniquement des DONNEES et des GETTERS
//   4. Elle est IMMUABLE (toutes les proprietes sont "final")
//
// DANS TRIALGO :
// --------------
// Une carte est une IMAGE. Il existe 3 types de cartes :
//   - Emettrice (E) : image de base (ex: dessin d'un lion)
//   - Cable (C)     : image de transformation (ex: fleches de miroir)
//   - Receptrice (R) : image resultat (ex: lion en miroir)
//
// La formule fondamentale est : E (+) C = R
// Les trois sont des images reelles dessinees par un artiste.
//
// REFERENCE : Recueil de conception v3.0, sections 1 et 3.2
// =============================================================

// On importe StorageConstants pour construire l'URL publique
// a partir du chemin relatif stocke en base de donnees.
// C'est le SEUL import autorise dans une entite (car c'est du Core).
import 'package:trialgo/core/constants/storage_constants.dart';

// =============================================================
// ENUM : CardType
// =============================================================
// Un "enum" (enumeration) est un type qui ne peut prendre que
// des valeurs PREDEFINIES. C'est comme une liste fermee de choix.
//
// Pourquoi un enum plutot qu'un String ?
//   - String : on pourrait ecrire "emetrice" (faute de frappe) sans erreur
//   - Enum   : le compilateur refuse toute valeur non listee
//   - Enum   : autocompletion dans l'IDE (CardType. -> liste les 3 choix)
//   - Enum   : switch exhaustif (le compilateur oblige a gerer les 3 cas)
//
// Les 3 valeurs correspondent aux 3 types de cartes du jeu :
// =============================================================

/// Les trois types de cartes possibles dans TRIALGO.
///
/// Chaque carte du jeu est exactement UN de ces types.
/// Le type determine :
///   - Ou l'image est stockee dans Supabase Storage
///   - Quelles colonnes de la table "cards" sont remplies
///   - Comment la carte est utilisee dans le gameplay
enum CardType {
  /// **Emettrice** : image de base, le point de depart d'un trio.
  ///
  /// Exemples : dessin d'un lion, d'un requin, d'un renard.
  /// Stockage : `emettrices/{theme}/{sujet}_base.webp`
  /// En base  : `parent_emettrice_id` est NULL (c'est la racine)
  ///            sauf si c'est une Receptrice jouant le role d'Emettrice en D2/D3
  emettrice,

  /// **Cable** : image de transformation, le lien entre E et R.
  ///
  /// Exemples : fleches de miroir, palette de couleur rouge, cercle fragmente.
  /// Stockage : `cables/{categorie}/{transformation}.webp`
  /// En base  : `cable_category` est rempli (geometrique, couleur, dimension, complexe)
  /// Particularite : le dessin du Cable EST l'algorithme.
  ///                 Pas de code texte, l'image elle-meme represente la transformation.
  cable,

  /// **Receptrice** : image resultat, produite visuellement par E (+) C.
  ///
  /// Exemples : lion en miroir, lion en miroir rouge, lion en miroir rouge fragmente.
  /// Stockage : `receptrices/{theme}/d{distance}/{sujet}_{transformations}.webp`
  /// En base  : `parent_emettrice_id` et `parent_cable_id` sont remplis
  receptrice,
}

// =============================================================
// CLASSE : CardEntity
// =============================================================
// C'est la classe principale de tout le jeu. Elle represente
// UNE carte (= UNE image) avec toutes ses metadonnees.
//
// "const" dans le constructeur : permet de creer des instances
// constantes a la compilation (optimisation memoire Flutter).
//
// "final" sur chaque propriete : la valeur est assignee UNE FOIS
// a la creation et ne peut plus jamais changer.
// C'est le principe d'IMMUTABILITE : on ne modifie pas un objet,
// on en cree un nouveau avec les valeurs modifiees.
// =============================================================

/// Represente une carte du jeu TRIALGO.
///
/// Une carte est une IMAGE stockee dans Supabase Storage.
/// Elle peut etre une Emettrice, un Cable ou une Receptrice.
///
/// Cette classe est IMMUABLE : une fois creee, ses proprietes
/// ne changent plus. Pour "modifier" une carte, on cree une
/// nouvelle instance avec les valeurs souhaitees.
///
/// Exemple de creation :
/// ```dart
/// final carte = CardEntity(
///   id: '550e8400-...',
///   cardType: CardType.emettrice,
///   distanceLevel: 1,
///   imagePath: 'emettrices/savane/lion_base.webp',
/// );
/// ```
class CardEntity {

  // =============================================================
  // PROPRIETE : id
  // =============================================================
  // Type    : String
  // Contenu : UUID v4 genere par PostgreSQL (gen_random_uuid())
  // Exemple : "550e8400-e29b-41d4-a716-446655440000"
  //
  // Role : identifiant UNIQUE de cette carte dans la base de donnees.
  // Chaque carte a un UUID different, genere automatiquement par
  // PostgreSQL au moment de l'INSERT.
  //
  // "final" : cette valeur ne changera JAMAIS apres la creation.
  // L'ID d'une carte est permanent.
  // =============================================================
  final String id;

  // =============================================================
  // PROPRIETE : cardType
  // =============================================================
  // Type    : CardType (enum defini ci-dessus)
  // Valeurs : CardType.emettrice | CardType.cable | CardType.receptrice
  //
  // Role : determine le TYPE de cette carte.
  // Le type influence :
  //   - L'emplacement de l'image dans le Storage
  //   - Les colonnes remplies en base (cable_category, parent_*, etc.)
  //   - Le comportement dans le jeu (visible, masquee, distracteur)
  //
  // Correspondance avec la base de donnees :
  //   Colonne SQL "card_type" (TEXT) contient 'emettrice', 'cable' ou 'receptrice'
  //   Le Model (couche Data) convertit ce String en enum CardType.
  // =============================================================
  final CardType cardType;

  // =============================================================
  // PROPRIETE : distanceLevel
  // =============================================================
  // Type    : int
  // Valeurs : 1, 2 ou 3
  //
  // Role : indique a quelle DISTANCE cette carte appartient.
  //
  // Le systeme de distances dans TRIALGO :
  //   Distance 1 (D1) : trio simple    -> E1 (+) C1 = R1 (3 images)
  //   Distance 2 (D2) : quintette      -> R1 (+) C2 = R2 (5 images au total)
  //   Distance 3 (D3) : septette       -> R2 (+) C3 = R3 (7 images au total)
  //
  // Exemples :
  //   - lion_base.webp         -> distanceLevel = 1 (Emettrice racine)
  //   - miroir_h.webp          -> distanceLevel = 1 (Cable D1)
  //   - lion_miroir_h.webp     -> distanceLevel = 1 (Receptrice D1)
  //   - teinte_rouge.webp      -> distanceLevel = 2 (Cable D2)
  //   - lion_miroir_h_teinte_rouge.webp -> distanceLevel = 2 (Receptrice D2)
  //
  // Contrainte SQL : CHECK (distance_level BETWEEN 1 AND 3)
  // =============================================================
  final int distanceLevel;

  // =============================================================
  // PROPRIETE : imagePath
  // =============================================================
  // Type    : String
  // Contenu : chemin RELATIF dans le bucket Supabase Storage
  //
  // Exemples :
  //   "emettrices/savane/lion_base.webp"
  //   "cables/geometrique/miroir_h.webp"
  //   "receptrices/savane/d1/lion_miroir_h.webp"
  //
  // IMPORTANT : on stocke le chemin RELATIF, pas l'URL complete.
  // Pourquoi ? Si le projet Supabase change, on ne modifie que
  // l'URL de base dans StorageConstants, pas chaque carte en base.
  //
  // L'URL complete est reconstruite par le getter "imageUrl" (voir plus bas).
  //
  // Contrainte SQL : NOT NULL (chaque carte DOIT avoir une image)
  // =============================================================
  final String imagePath;

  // =============================================================
  // PROPRIETE : imageWidth
  // =============================================================
  // Type    : int? (nullable — le "?" autorise la valeur null)
  // Contenu : largeur de l'image en pixels
  // Exemple : 512
  //
  // Role : utile pour Flutter afin de pre-dimensionner le widget
  // AVANT que l'image ne soit telechargee. Sans cette info, le
  // widget "saute" en taille quand l'image arrive (mauvaise UX).
  //
  // Nullable car : cette info n'est pas toujours disponible
  // (certaines cartes anciennes n'ont pas cette metadonnee).
  // =============================================================
  final int? imageWidth;

  // =============================================================
  // PROPRIETE : imageHeight
  // =============================================================
  // Type    : int? (nullable)
  // Contenu : hauteur de l'image en pixels
  // Exemple : 512
  //
  // Meme role que imageWidth : pre-dimensionnement du widget.
  // =============================================================
  final int? imageHeight;

  // =============================================================
  // PROPRIETE : imageFormat
  // =============================================================
  // Type    : String
  // Valeurs : 'webp', 'png', 'jpg'
  // Defaut  : 'webp'
  //
  // Role : indique le format du fichier image.
  // WebP est le format recommande pour le mobile car :
  //   - Compression superieure a PNG et JPG
  //   - Supporte la transparence (comme PNG)
  //   - Fichiers plus petits = chargement plus rapide
  //
  // Cette info est stockee en base pour permettre un eventuel
  // traitement different selon le format (ex: fallback PNG si
  // le decodeur WebP n'est pas disponible — cas tres rare).
  // =============================================================
  final String imageFormat;

  // =============================================================
  // PROPRIETE : cableCategory
  // =============================================================
  // Type    : String? (nullable)
  // Valeurs : 'geometrique', 'couleur', 'dimension', 'complexe', ou null
  //
  // Role : categorie visuelle du cable.
  // UNIQUEMENT rempli pour les cartes de type Cable.
  // Pour les Emettrices et Receptrices, cette valeur est null.
  //
  // Les categories de cables dans TRIALGO :
  //   - 'geometrique' : miroir, rotation (transformations de forme)
  //   - 'couleur'     : teinte, niveaux de gris, inversion (transformations de couleur)
  //   - 'dimension'   : agrandissement, reduction (transformations de taille)
  //   - 'complexe'    : fragmentation, ombre portee (transformations composites)
  //
  // Utilite dans le jeu : quand la carte masquee est un Cable,
  // les 9 distracteurs sont d'abord choisis dans la MEME categorie,
  // puis completes avec des cables d'autres categories.
  // Cela rend le defi visuel plus interessant.
  // =============================================================
  final String? cableCategory;

  // =============================================================
  // PROPRIETE : themeTags
  // =============================================================
  // Type    : List<String> (liste de chaines de caracteres)
  // Defaut  : liste vide []
  //
  // Role : tags thematiques associes a cette carte.
  // Permet de classer et filtrer les cartes par theme.
  //
  // Exemples :
  //   Emettrice lion  : ['animal', 'lion', 'savane', 'felin']
  //   Cable miroir    : ['miroir', 'symetrie', 'geometrie']
  //   Receptrice D2   : ['animal', 'lion', 'savane', 'miroir', 'rouge']
  //
  // Utilite dans le jeu : les distracteurs pour une Receptrice
  // sont choisis parmi les Receptrices de meme distance ET memes tags.
  // Cela cree des distracteurs visuellement proches (plus difficile).
  //
  // En base de donnees : stocke comme TEXT[] (tableau PostgreSQL).
  // Le Model convertit ce tableau en List<String> Dart.
  // =============================================================
  final List<String> themeTags;

  // =============================================================
  // PROPRIETE : parentEmettriceId
  // =============================================================
  // Type    : String? (nullable)
  // Contenu : UUID de la carte Emettrice (ou Receptrice jouant le role d'Emettrice)
  //
  // Role : pointe vers la carte qui a SERVI d'Emettrice pour creer cette carte.
  //
  // Valeurs selon le type de carte :
  //   - Emettrice racine (D1)  : null (pas de parent, c'est le point de depart)
  //   - Cable                  : null (un cable n'a pas d'emettrice parente)
  //   - Receptrice D1          : pointe vers l'Emettrice de base
  //     Exemple : lion_miroir_h -> parent = lion_base
  //   - Receptrice D2          : pointe vers la Receptrice D1
  //     Exemple : lion_miroir_h_teinte_rouge -> parent = lion_miroir_h
  //   - Receptrice D3          : pointe vers la Receptrice D2
  //     Exemple : lion_miroir_h_teinte_rouge_fragmente -> parent = lion_miroir_h_teinte_rouge
  //
  // Cette relation permet de remonter la chaine de transformations.
  // =============================================================
  final String? parentEmettriceId;

  // =============================================================
  // PROPRIETE : parentCableId
  // =============================================================
  // Type    : String? (nullable)
  // Contenu : UUID de la carte Cable utilisee pour creer cette Receptrice
  //
  // Role : indique QUELLE transformation a produit cette Receptrice.
  //
  // Valeurs selon le type :
  //   - Emettrice : null (pas de cable implique)
  //   - Cable     : null (un cable n'est pas produit par un autre cable)
  //   - Receptrice D1 : pointe vers le Cable utilise
  //     Exemple : lion_miroir_h -> parentCable = miroir_h
  //   - Receptrice D2 : pointe vers le Cable D2
  //     Exemple : lion_miroir_h_teinte_rouge -> parentCable = teinte_rouge
  //
  // Avec parentEmettriceId + parentCableId, on peut reconstituer
  // la formule E (+) C = R pour n'importe quelle Receptrice.
  // =============================================================
  final String? parentCableId;

  // =============================================================
  // PROPRIETE : rootEmettriceId
  // =============================================================
  // Type    : String? (nullable)
  // Contenu : UUID de l'Emettrice RACINE de toute la chaine
  //
  // Role : raccourci pour remonter directement a l'Emettrice de base,
  //        sans traverser toute la chaine de parents.
  //
  // Valeurs :
  //   - Receptrice D1 : null (son parent direct est deja la racine)
  //   - Receptrice D2 : pointe vers l'Emettrice de base (D1)
  //     Exemple : lion_miroir_h_teinte_rouge -> rootEmettrice = lion_base
  //   - Receptrice D3 : pointe vers l'Emettrice de base (D1)
  //     Exemple : lion_miroir_h_teinte_rouge_fragmente -> rootEmettrice = lion_base
  //   - Emettrice/Cable : null
  //
  // Pourquoi ce raccourci ? Pour les questions de jeu, on a souvent
  // besoin de l'Emettrice racine. Sans ce champ, il faudrait faire
  // plusieurs requetes en boucle (D3 -> D2 -> D1 -> racine).
  // Avec ce champ, UNE seule requete suffit.
  // =============================================================
  final String? rootEmettriceId;

  // =============================================================
  // PROPRIETE : difficultyScore
  // =============================================================
  // Type    : double
  // Valeurs : entre 0.0 (trivial) et 1.0 (expert)
  // Defaut  : 0.5
  //
  // Role : indicateur de la difficulte visuelle de cette carte.
  // Une carte avec un dessin tres detaille ou une transformation
  // subtile aura un score plus eleve.
  //
  // Utilite : permet d'ajuster la difficulte des questions.
  // Les niveaux faciles utilisent des cartes a faible score,
  // les niveaux experts utilisent des cartes a score eleve.
  //
  // Ce score est defini manuellement par le chef artistique
  // lors de l'insertion de la carte en base.
  // =============================================================
  final double difficultyScore;

  // =============================================================
  // PROPRIETE : isActive
  // =============================================================
  // Type    : bool
  // Defaut  : true
  //
  // Role : indique si cette carte est UTILISABLE dans le jeu.
  //
  // Une carte peut etre inactive pour plusieurs raisons :
  //   - Image pas encore uploadee dans le Storage
  //   - Image en cours de revision par le chef artistique
  //   - Trio associe pas encore enregistre dans card_trios
  //   - Bug detecte sur cette carte (image corrompue)
  //
  // Seules les cartes actives (is_active = true) sont :
  //   - Visibles dans les questions de jeu
  //   - Utilisables comme distracteurs
  //   - Affichees dans la galerie des cartes debloquees
  //
  // Politique RLS : la politique "cards_select_authenticated"
  // filtre automatiquement avec USING (is_active = TRUE).
  // =============================================================
  final bool isActive;

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // "const" : permet de creer des instances constantes.
  //   Avantage : Flutter reutilise la meme instance en memoire
  //   si les parametres sont identiques (optimisation).
  //
  // "{}" : les accolades definissent des PARAMETRES NOMMES.
  //   Avantage : on sait quel parametre on assigne sans compter
  //   la position. Plus lisible quand il y a beaucoup de parametres.
  //
  // "required" : ce parametre DOIT etre fourni.
  //   Si on l'oublie, le compilateur affiche une erreur.
  //
  // "this.xxx" : raccourci pour assigner directement a la propriete.
  //   "required this.id" equivaut a : "required String id" + "this.id = id"
  //
  // Parametres avec valeur par defaut : pas besoin de les fournir.
  //   "this.imageFormat = 'webp'" : si non fourni, vaut 'webp'.
  //   "this.themeTags = const []" : si non fourni, liste vide constante.
  // =============================================================

  /// Cree une nouvelle instance de [CardEntity].
  ///
  /// Les parametres [id], [cardType], [distanceLevel] et [imagePath]
  /// sont obligatoires car une carte n'a pas de sens sans eux.
  ///
  /// Les autres parametres ont des valeurs par defaut raisonnables.
  const CardEntity({
    required this.id,              // Obligatoire : identifiant unique
    required this.cardType,        // Obligatoire : emettrice, cable ou receptrice
    required this.distanceLevel,   // Obligatoire : 1, 2 ou 3
    required this.imagePath,       // Obligatoire : chemin de l'image
    this.imageWidth,               // Optionnel  : largeur en pixels (ou null)
    this.imageHeight,              // Optionnel  : hauteur en pixels (ou null)
    this.imageFormat = 'webp',     // Optionnel  : format par defaut = webp
    this.cableCategory,            // Optionnel  : null sauf pour les cables
    this.themeTags = const [],     // Optionnel  : liste vide par defaut
    this.parentEmettriceId,        // Optionnel  : null pour les racines
    this.parentCableId,            // Optionnel  : null pour les non-receptrices
    this.rootEmettriceId,          // Optionnel  : null pour D1
    this.difficultyScore = 0.5,    // Optionnel  : difficulte moyenne par defaut
    this.isActive = true,          // Optionnel  : active par defaut
  });

  // =============================================================
  // GETTER : imageUrl
  // =============================================================
  // Un "getter" est une propriete CALCULEE. Elle n'est pas stockee
  // en memoire, mais calculee a chaque acces.
  //
  // Syntaxe : Type get nomDuGetter => expression;
  //   - "get" indique que c'est un getter (pas une methode)
  //   - "=>" est le raccourci pour "{ return expression; }"
  //
  // Role : reconstruit l'URL publique complete de l'image
  //        a partir du chemin relatif (imagePath) et de l'URL
  //        de base du bucket (StorageConstants.baseUrl).
  //
  // Exemple :
  //   imagePath = "emettrices/savane/lion_base.webp"
  //   imageUrl  = "https://olovolsbopjporwpuphm.supabase.co/storage/v1/object/public/trialgo-cards/emettrices/savane/lion_base.webp"
  //
  // Utilise par : CachedNetworkImage dans CardImageWidget
  //   CachedNetworkImage(imageUrl: card.imageUrl, ...)
  // =============================================================

  /// URL publique complete de l'image de cette carte.
  ///
  /// Reconstruit l'URL a partir de [imagePath] (chemin relatif en base)
  /// et de [StorageConstants.baseUrl] (URL de base du bucket).
  ///
  /// Cette URL est directement utilisable par les widgets d'image Flutter :
  /// ```dart
  /// Image.network(card.imageUrl)
  /// CachedNetworkImage(imageUrl: card.imageUrl)
  /// ```
  String get imageUrl => StorageConstants.fullUrl(imagePath);

  // =============================================================
  // GETTER : isRootEmettrice
  // =============================================================
  // Syntaxe : "=>" avec une expression booleenne.
  //   "==" compare deux valeurs (egalite).
  //   "&&" est le ET logique (les deux conditions doivent etre vraies).
  //
  // Role : determine si cette carte est une Emettrice RACINE.
  //
  // Une Emettrice racine est le POINT DE DEPART d'une chaine
  // de transformations. Elle n'a pas de parent.
  //
  // Conditions :
  //   1. Le type DOIT etre "emettrice" (pas cable, pas receptrice)
  //   2. parentEmettriceId DOIT etre null (pas de parent = racine)
  //
  // Contre-exemple : une Receptrice D1 qui joue le role d'Emettrice
  // en D2 n'est PAS une racine (son type est "receptrice").
  // =============================================================

  /// Retourne `true` si cette carte est une Emettrice racine (sans parent).
  ///
  /// Une Emettrice racine est le point de depart d'une chaine :
  /// `lion_base` est racine, `lion_miroir_h` ne l'est pas
  /// (c'est une Receptrice, meme si elle sert d'Emettrice en D2).
  bool get isRootEmettrice =>
      cardType == CardType.emettrice && parentEmettriceId == null;
  //  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  //  Condition 1 : type emettrice       Condition 2 : pas de parent
  //  Les deux doivent etre vraies (&&)

  // =============================================================
  // GETTER : isCable
  // =============================================================
  // Simple verification du type.
  // Utilise dans le code pour des branchements conditionnels :
  //   if (card.isCable) { ... traitement specifique cables ... }
  //
  // Plus lisible que : if (card.cardType == CardType.cable)
  // =============================================================

  /// Retourne `true` si cette carte est un Cable (image de transformation).
  bool get isCable => cardType == CardType.cable;

  // =============================================================
  // GETTER : isReceptrice
  // =============================================================
  // Meme principe que isCable, pour les Receptrices.
  // =============================================================

  /// Retourne `true` si cette carte est une Receptrice (image resultat).
  bool get isReceptrice => cardType == CardType.receptrice;
}
