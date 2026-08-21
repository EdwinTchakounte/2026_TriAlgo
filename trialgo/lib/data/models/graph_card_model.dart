// =============================================================
// FICHIER : lib/data/models/graph_card_model.dart
// ROLE   : Convertir le JSON d'une carte (Supabase OU FastAPI) en
//          GraphCardEntity
// COUCHE : Data > Models
// =============================================================
//
// Herite de GraphCardEntity et ajoute :
//   - fromJson() : JSON (backend) -> objet Dart
//   - toJson()   : objet Dart -> JSON (backend)
//
// DEUX BACKENDS, DEUX FORMATS DE JSON
// -----------------------------------
// Ce model doit accepter les deux, car ApiConfig.mode decide a
// l'execution d'ou viennent les cartes.
//
// 1) Supabase (table "cards") -> chemin RELATIF dans le bucket :
// {
//   "id": "uuid-001",
//   "label": "Lion",
//   "image_path": "savane/lion_base.webp"
// }
//
// 2) FastAPI (GET /api/games/{id}/cards) -> URL ABSOLUE deja
//    construite par le backend a partir de S3_PUBLIC_ENDPOINT_URL :
// {
//   "id": "uuid-001",
//   "label": "Lion",
//   "object_key": "<game_id>/<uuid>.jpg",
//   "image_url": "https://files.trialgo.io/trialgo-cards/<game_id>/<uuid>.jpg"
// }
//
// Noter qu'il n'y a AUCUNE cle "image_path" dans la reponse
// FastAPI. C'est pour cela que fromJson lit les deux cles avec un
// repli de l'une sur l'autre (voir le detail dans la factory).
//
// Le champ Dart s'appelle "imagePath" dans les deux cas ; c'est
// GraphCardEntity.imageUrl qui fait la difference a la lecture :
// si la valeur commence par "http", elle est utilisee telle quelle,
// sinon elle est prefixee par l'URL du bucket Supabase.
//
// CONVENTION :
//   Backend : snake_case (image_path / image_url)
//   Dart    : camelCase (imagePath)
//   La conversion se fait ici dans fromJson/toJson.
// =============================================================

import 'package:trialgo/domain/entities/graph_card_entity.dart';

/// Model de carte : [GraphCardEntity] + conversion JSON.
///
/// Utilise par la couche Data pour convertir les reponses Supabase
/// en objets Dart et inversement.
class GraphCardModel extends GraphCardEntity {

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // Transmet tous les parametres au constructeur parent via "super".
  // =============================================================

  /// Constructeur principal. Transmet tout a [GraphCardEntity].
  const GraphCardModel({
    required super.id,
    required super.label,
    required super.imagePath,
  });

  // =============================================================
  // FACTORY : fromJson
  // =============================================================
  // Cree un GraphCardModel depuis un Map JSON, quel que soit le
  // backend qui l'a produit (Supabase ou FastAPI).
  //
  // Seuls 3 champs sont utiles ici : id, label, et la localisation
  // de l'image. Pas d'enum a convertir, pas de liste a transformer.
  // =============================================================

  /// Cree un [GraphCardModel] a partir d'un Map JSON.
  ///
  /// [json] : une ligne de la table `cards` (Supabase) OU un element
  /// de la reponse de `GET /api/games/{id}/cards` (FastAPI).
  ///
  /// Exemple :
  /// ```dart
  /// final data = await supabase.from('cards').select().single();
  /// final card = GraphCardModel.fromJson(data);
  /// ```
  factory GraphCardModel.fromJson(Map<String, dynamic> json) {
    // -----------------------------------------------------------
    // LOCALISATION DE L'IMAGE : image_path OU image_url
    // -----------------------------------------------------------
    // Supabase renvoie 'image_path' (chemin relatif dans le bucket).
    // FastAPI renvoie 'image_url' (URL absolue deja construite) et
    // ne renvoie PAS 'image_path'.
    //
    // L'operateur "??" (null-coalescing) prend la premiere valeur
    // non-nulle :
    //   json['image_path'] ?? json['image_url']
    //     Supabase -> 'savane/lion.webp'   (image_url absent = null)
    //     FastAPI  -> null puis l'URL absolue
    //
    // Sans ce repli, le cast "as String" sur une valeur nulle levait
    // un TypeError et faisait echouer TOUT le chargement du graphe
    // des que ApiConfig.mode valait fastapi.
    //
    // Le "as String?" (nullable) suivi du "?? ''" evite de planter
    // si aucune des deux cles n'est presente : on prefere une carte
    // sans image (l'UI affiche son errorWidget) a un crash de la
    // synchronisation complete du graphe.
    // -----------------------------------------------------------
    final localisationImage =
        (json['image_path'] ?? json['image_url']) as String?;

    return GraphCardModel(
      // 'id' : UUID de la carte, retourne comme String par les deux
      // backends.
      id: json['id'] as String,

      // 'label' : nom descriptif de la carte.
      label: json['label'] as String,

      // Chemin relatif (Supabase) ou URL absolue (FastAPI).
      // C'est GraphCardEntity.imageUrl qui tranche a la lecture.
      imagePath: localisationImage ?? '',
    );
  }

  // =============================================================
  // METHODE : toJson
  // =============================================================
  // Convertit en Map JSON pour INSERT dans la table "cards".
  // L'id n'est PAS inclus : genere par PostgreSQL automatiquement.
  // =============================================================

  /// Convertit ce [GraphCardModel] en Map JSON pour Supabase.
  ///
  /// Exemple :
  /// ```dart
  /// await supabase.from('cards').insert(card.toJson());
  /// ```
  Map<String, dynamic> toJson() {
    return {
      // Pas d'id : genere par PostgreSQL via gen_random_uuid().
      'label': label,
      'image_path': imagePath,
    };
  }
}
