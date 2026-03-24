// =============================================================
// FICHIER : lib/data/models/card_model.dart
// ROLE   : Convertir les donnees JSON de Supabase en CardEntity
// COUCHE : Data > Models
// =============================================================
//
// QU'EST-CE QU'UN MODEL ?
// -----------------------
// Un Model est une EXTENSION d'une entite du Domain.
// Il ajoute la capacite de SE CONSTRUIRE a partir de donnees brutes
// (JSON venant de Supabase) et de SE CONVERTIR en donnees brutes
// (pour envoyer des donnees a Supabase).
//
// Pourquoi separer Entity et Model ?
//   - Entity (Domain) : ne connait PAS le format JSON
//     -> Pure, testable, independante du backend
//   - Model (Data) : CONNAIT le format JSON
//     -> Liee au format de la base de donnees
//
// Si le schema de la base change (ex: renommer une colonne),
// on ne modifie QUE le Model, pas l'Entity.
//
// HERITAGE : CardModel HERITE de CardEntity
// ------------------------------------------
// "extends" signifie que CardModel EST un CardEntity.
// Il possede TOUTES les proprietes de CardEntity (id, cardType, etc.)
// PLUS les methodes supplementaires (fromJson, toJson).
//
// Partout ou on attend un CardEntity, on peut passer un CardModel.
// C'est le principe de SUBSTITUTION de Liskov (SOLID).
//
// FORMAT JSON ATTENDU (venant de Supabase) :
// ------------------------------------------
// {
//   "id": "550e8400-e29b-41d4-a716-446655440000",
//   "card_type": "emettrice",
//   "distance_level": 1,
//   "image_path": "emettrices/savane/lion_base.webp",
//   "image_width": 512,
//   "image_height": 512,
//   "image_format": "webp",
//   "cable_category": null,
//   "theme_tags": ["animal", "lion", "savane"],
//   "parent_emettrice_id": null,
//   "parent_cable_id": null,
//   "root_emettrice_id": null,
//   "difficulty_score": 0.5,
//   "is_active": true
// }
//
// REFERENCE : Recueil de conception v3.0, section 3.2
// =============================================================

// Import de l'entite parente que ce Model etend.
import 'package:trialgo/domain/entities/card_entity.dart';

/// Model de carte : [CardEntity] + conversion JSON.
///
/// Herite de [CardEntity] et ajoute :
///   - [CardModel.fromJson] : cree un CardModel depuis un Map JSON
///   - [toJson] : convertit le CardModel en Map JSON
///
/// Utilise par la couche Data pour convertir les reponses Supabase
/// en objets Dart structures utilisables par le reste de l'application.
class CardModel extends CardEntity {
  // =============================================================
  // CONSTRUCTEUR PRINCIPAL
  // =============================================================
  // "const CardModel({...})" : constructeur du Model.
  //
  // "super.xxx" : passe la valeur au constructeur de la classe parente
  // (CardEntity). C'est comme dire : "prends cette valeur et stocke-la
  // dans la propriete 'xxx' de CardEntity".
  //
  // Syntaxe "required super.id" :
  //   - "required" : le parametre est obligatoire
  //   - "super" : le parametre est transmis au constructeur parent
  //   - "id" : nom du parametre (correspond a "this.id" dans CardEntity)
  //
  // Equivalent sans sucre syntaxique :
  //   CardModel({required String id, ...})
  //       : super(id: id, ...);
  // =============================================================

  /// Constructeur principal.
  ///
  /// Transmet tous les parametres au constructeur de [CardEntity].
  /// Memes parametres, memes valeurs par defaut.
  const CardModel({
    required super.id,                // -> CardEntity.id
    required super.cardType,          // -> CardEntity.cardType
    required super.distanceLevel,     // -> CardEntity.distanceLevel
    required super.imagePath,         // -> CardEntity.imagePath
    super.imageWidth,                 // -> CardEntity.imageWidth (null)
    super.imageHeight,                // -> CardEntity.imageHeight (null)
    super.imageFormat,                // -> CardEntity.imageFormat ('webp')
    super.cableCategory,              // -> CardEntity.cableCategory (null)
    super.themeTags,                  // -> CardEntity.themeTags ([])
    super.parentEmettriceId,          // -> CardEntity.parentEmettriceId (null)
    super.parentCableId,              // -> CardEntity.parentCableId (null)
    super.rootEmettriceId,            // -> CardEntity.rootEmettriceId (null)
    super.difficultyScore,            // -> CardEntity.difficultyScore (0.5)
    super.isActive,                   // -> CardEntity.isActive (true)
  });

  // =============================================================
  // FACTORY : fromJson
  // =============================================================
  // "factory" est un type special de constructeur en Dart.
  //
  // Differences avec un constructeur normal :
  //   - Normal   : cree TOUJOURS une nouvelle instance
  //   - Factory  : peut retourner une instance existante ou faire
  //                du traitement avant de creer l'instance
  //
  // Ici, on utilise "factory" car on doit TRANSFORMER les donnees
  // JSON avant de les passer au constructeur normal :
  //   - Convertir "card_type" (String) en CardType (enum)
  //   - Convertir "theme_tags" (dynamic) en List<String>
  //   - Gerer les valeurs nulles avec l'operateur "??"
  //
  // PARAMETRES :
  //   Map<String, dynamic> json
  //     - "Map" : dictionnaire cle-valeur (comme un objet JSON)
  //     - "<String, dynamic>" : les cles sont des String (noms de colonnes)
  //       et les valeurs sont "dynamic" (peuvent etre String, int, null, etc.)
  //     - C'est le format retourne par supabase.from('cards').select()
  //
  // CONVENTION DE NOMMAGE :
  //   - Supabase/PostgreSQL utilise "snake_case" : image_path, card_type
  //   - Dart utilise "camelCase" : imagePath, cardType
  //   - La conversion se fait ICI, dans le fromJson
  // =============================================================

  /// Cree un [CardModel] a partir d'un Map JSON (reponse Supabase).
  ///
  /// [json] : dictionnaire cle-valeur retourne par une requete Supabase.
  ///
  /// Exemple :
  /// ```dart
  /// final data = await supabase.from('cards').select().single();
  /// final card = CardModel.fromJson(data);
  /// ```
  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      // -------------------------------------------------------
      // id : json['id']
      // -------------------------------------------------------
      // "json['id']" : accede a la valeur associee a la cle 'id'.
      // Le type retourne est "dynamic" (on ne sait pas a l'avance).
      // Dart le cast implicitement en String car le parametre attend un String.
      // Si la valeur est null ou d'un autre type, une erreur sera levee.
      // -------------------------------------------------------
      id: json['id'],

      // -------------------------------------------------------
      // cardType : conversion String -> enum CardType
      // -------------------------------------------------------
      // En base, card_type est un TEXT ('emettrice', 'cable', 'receptrice').
      // En Dart, on utilise l'enum CardType.
      //
      // "CardType.values" : liste de toutes les valeurs de l'enum
      //   [CardType.emettrice, CardType.cable, CardType.receptrice]
      //
      // ".byName()" : cherche la valeur dont le nom correspond au String.
      //   'emettrice' -> CardType.emettrice
      //   'cable'     -> CardType.cable
      //   'receptrice' -> CardType.receptrice
      //
      // Si le String ne correspond a aucune valeur, une exception est levee.
      // C'est voulu : si la base contient un type invalide, on veut le savoir.
      // -------------------------------------------------------
      cardType: CardType.values.byName(json['card_type']),

      // -------------------------------------------------------
      // distanceLevel : json['distance_level']
      // -------------------------------------------------------
      // En base : distance_level INT
      // En Dart : int
      // Pas de conversion necessaire, Supabase retourne deja un int.
      // -------------------------------------------------------
      distanceLevel: json['distance_level'],

      // -------------------------------------------------------
      // imagePath : json['image_path']
      // -------------------------------------------------------
      // Le chemin relatif dans Supabase Storage.
      // Exemple : "emettrices/savane/lion_base.webp"
      // -------------------------------------------------------
      imagePath: json['image_path'],

      // -------------------------------------------------------
      // imageWidth : json['image_width']
      // -------------------------------------------------------
      // Peut etre null (pas toujours renseigne en base).
      // Le parametre est de type int?, donc null est accepte.
      // -------------------------------------------------------
      imageWidth: json['image_width'],

      // -------------------------------------------------------
      // imageHeight : json['image_height']
      // -------------------------------------------------------
      imageHeight: json['image_height'],

      // -------------------------------------------------------
      // imageFormat : json['image_format'] ?? 'webp'
      // -------------------------------------------------------
      // L'operateur "??" (null-coalescing) :
      //   Si json['image_format'] est non-null -> utilise cette valeur
      //   Si json['image_format'] est null     -> utilise 'webp'
      //
      // C'est un filet de securite : meme si la base ne renseigne pas
      // le format, on utilise 'webp' par defaut (le format recommande).
      // -------------------------------------------------------
      imageFormat: json['image_format'] ?? 'webp',

      // -------------------------------------------------------
      // cableCategory : json['cable_category']
      // -------------------------------------------------------
      // null pour les Emettrices et Receptrices.
      // 'geometrique', 'couleur', 'dimension' ou 'complexe' pour les Cables.
      // -------------------------------------------------------
      cableCategory: json['cable_category'],

      // -------------------------------------------------------
      // themeTags : conversion List<dynamic> -> List<String>
      // -------------------------------------------------------
      // En PostgreSQL : theme_tags TEXT[] (tableau de texte)
      // Supabase retourne : une List<dynamic> (ou null si vide)
      //
      // Decomposition :
      //   json['theme_tags']     -> dynamic (peut etre List ou null)
      //   ?? []                  -> si null, utilise une liste vide
      //   List<String>.from(...) -> convertit chaque element en String
      //
      // "List<String>.from()" est un constructeur qui prend un Iterable
      // et cree une nouvelle List<String>. Chaque element est cast en String.
      //
      // Pourquoi cette conversion ?
      //   Supabase retourne List<dynamic>, pas List<String>.
      //   Sans conversion, on aurait une erreur de type plus tard
      //   quand on essaierait d'utiliser les tags comme des Strings.
      // -------------------------------------------------------
      themeTags: List<String>.from(json['theme_tags'] ?? []),

      // -------------------------------------------------------
      // parentEmettriceId : json['parent_emettrice_id']
      // -------------------------------------------------------
      // UUID ou null. Pas de conversion necessaire.
      // -------------------------------------------------------
      parentEmettriceId: json['parent_emettrice_id'],

      // -------------------------------------------------------
      // parentCableId : json['parent_cable_id']
      // -------------------------------------------------------
      parentCableId: json['parent_cable_id'],

      // -------------------------------------------------------
      // rootEmettriceId : json['root_emettrice_id']
      // -------------------------------------------------------
      rootEmettriceId: json['root_emettrice_id'],

      // -------------------------------------------------------
      // difficultyScore : conversion et valeur par defaut
      // -------------------------------------------------------
      // En base : difficulty_score FLOAT (peut etre null)
      // En Dart : double
      //
      // Decomposition :
      //   (json['difficulty_score'] ?? 0.5)
      //     -> Si non-null, prend la valeur. Si null, utilise 0.5.
      //
      //   .toDouble()
      //     -> Convertit en double. Necessaire car Supabase peut
      //        retourner un int (ex: 1 au lieu de 1.0) pour les
      //        valeurs entieres, et Dart est strict sur les types.
      //        int.toDouble() : 1 -> 1.0
      //        double.toDouble() : 0.5 -> 0.5 (identite)
      // -------------------------------------------------------
      difficultyScore: (json['difficulty_score'] ?? 0.5).toDouble(),

      // -------------------------------------------------------
      // isActive : json['is_active'] ?? true
      // -------------------------------------------------------
      // En base : is_active BOOLEAN DEFAULT TRUE
      // Si la colonne n'est pas dans le SELECT (cas rare), on
      // considere la carte comme active par defaut.
      // -------------------------------------------------------
      isActive: json['is_active'] ?? true,
    );
  }

  // =============================================================
  // METHODE : toJson
  // =============================================================
  // Convertit le CardModel en Map JSON pour l'envoyer a Supabase.
  //
  // Utilisation : lors d'un INSERT ou UPDATE dans la table cards.
  //   await supabase.from('cards').insert(card.toJson());
  //
  // Retour : Map<String, dynamic>
  //   Les cles sont en snake_case (convention PostgreSQL).
  //   Les valeurs sont des types JSON standards (String, int, bool, List).
  //
  // NOTE : l'enum CardType est reconverti en String avec ".name".
  //   CardType.emettrice.name -> "emettrice"
  //   CardType.cable.name     -> "cable"
  // =============================================================

  /// Convertit ce [CardModel] en Map JSON pour Supabase.
  ///
  /// Les cles utilisent la convention snake_case de PostgreSQL.
  /// L'[id] n'est PAS inclus car il est genere par PostgreSQL (gen_random_uuid).
  ///
  /// Exemple :
  /// ```dart
  /// await supabase.from('cards').insert(card.toJson());
  /// ```
  Map<String, dynamic> toJson() {
    return {
      // On N'INCLUT PAS 'id' : il est genere automatiquement par PostgreSQL.
      // Si on l'incluait, PostgreSQL ignorerait notre valeur et en genererait une.

      // cardType.name convertit l'enum en String :
      //   CardType.emettrice -> "emettrice"
      'card_type': cardType.name,

      'distance_level': distanceLevel,
      'image_path': imagePath,
      'image_width': imageWidth,       // null si non renseigne
      'image_height': imageHeight,     // null si non renseigne
      'image_format': imageFormat,     // 'webp' par defaut
      'cable_category': cableCategory, // null pour E et R
      'theme_tags': themeTags,         // List<String> -> JSON array
      'parent_emettrice_id': parentEmettriceId, // null pour les racines
      'parent_cable_id': parentCableId,         // null pour E et C
      'root_emettrice_id': rootEmettriceId,     // null pour D1
      'difficulty_score': difficultyScore,
      'is_active': isActive,
    };
  }
}
