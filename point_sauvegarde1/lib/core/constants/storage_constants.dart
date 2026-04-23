// =============================================================
// FICHIER : lib/core/constants/storage_constants.dart
// ROLE   : Centraliser toutes les URLs de Supabase Storage
// COUCHE : Core (accessible par toutes les autres couches)
// =============================================================
//
// POURQUOI CE FICHIER ?
// ---------------------
// Dans TRIALGO, chaque carte (Emettrice, Cable, Receptrice) est
// une image stockee dans Supabase Storage. En base de donnees,
// on ne stocke que le chemin RELATIF (ex: "emettrices/savane/lion_base.webp").
//
// Ce fichier fournit les methodes pour reconstruire l'URL COMPLETE
// a partir du chemin relatif. Centraliser cette logique ici permet :
//   - De changer l'URL de base en UN seul endroit si le projet migre
//   - D'eviter les erreurs de copier-coller d'URLs dans tout le code
//   - De garantir un format d'URL coherent partout
//
// STRUCTURE DU BUCKET SUPABASE STORAGE :
// --------------------------------------
//   trialgo-cards/           <- bucket public
//     emettrices/            <- images de base
//       savane/lion_base.webp
//       ocean/requin_base.webp
//     cables/                <- images de transformation
//       geometrique/miroir_h.webp
//       couleur/teinte_rouge.webp
//     receptrices/           <- images resultat
//       savane/d1/lion_miroir_h.webp
//       savane/d2/lion_miroir_h_teinte_rouge.webp
// =============================================================

/// Classe utilitaire contenant les constantes et helpers
/// pour construire les URLs des images Supabase Storage.
///
/// Utilisation :
/// ```dart
/// final url = StorageConstants.fullUrl('emettrices/savane/lion_base.webp');
/// // -> "https://olovolsbopjporwpuphm.supabase.co/storage/v1/object/public/trialgo-cards/emettrices/savane/lion_base.webp"
/// ```
class StorageConstants {
  // ---------------------------------------------------------------
  // URL de base du bucket public "trialgo-cards"
  // ---------------------------------------------------------------
  // Format : https://<PROJECT_REF>.supabase.co/storage/v1/object/public/<BUCKET>
  //
  // "olovolsbopjporwpuphm" = identifiant unique du projet Supabase TRIALGO
  // "storage/v1/object/public" = chemin fixe de l'API Storage pour les buckets publics
  // "trialgo-cards" = nom du bucket qui contient toutes les images de cartes
  // ---------------------------------------------------------------
  static const String baseUrl =
      'https://olovolsbopjporwpuphm.supabase.co/storage/v1/object/public/trialgo-cards';

  // ---------------------------------------------------------------
  // Methode principale : construit l'URL complete depuis un chemin relatif
  // ---------------------------------------------------------------
  // Parametre : imagePath = chemin relatif stocke en base de donnees
  //   Exemple : "emettrices/savane/lion_base.webp"
  //
  // Retour : URL complete utilisable par Image.network() ou CachedNetworkImage
  //   Exemple : "https://olovolsbopjporwpuphm.supabase.co/.../emettrices/savane/lion_base.webp"
  // ---------------------------------------------------------------
  static String fullUrl(String imagePath) => '$baseUrl/$imagePath';

  // ---------------------------------------------------------------
  // Helpers specifiques par type de carte
  // ---------------------------------------------------------------
  // Ces methodes construisent le chemin relatif selon les conventions
  // de nommage definies dans le recueil de conception (section 2.2).
  // ---------------------------------------------------------------

  /// Construit l'URL d'une image Emettrice.
  ///
  /// Convention : emettrices/{theme}/{sujet}_base.webp
  /// Exemple : emettriceUrl('savane', 'lion_base.webp')
  ///        -> "https://.../emettrices/savane/lion_base.webp"
  ///
  /// [theme]    : thematique de l'image (savane, ocean, foret...)
  /// [filename] : nom du fichier avec extension (lion_base.webp)
  static String emettriceUrl(String theme, String filename) =>
      '$baseUrl/emettrices/$theme/$filename';

  /// Construit l'URL d'une image Cable (transformation).
  ///
  /// Convention : cables/{categorie}/{transformation}.webp
  /// Exemple : cableUrl('geometrique', 'miroir_h.webp')
  ///        -> "https://.../cables/geometrique/miroir_h.webp"
  ///
  /// [category] : categorie du cable (geometrique, couleur, dimension, complexe)
  /// [filename] : nom du fichier avec extension (miroir_h.webp)
  static String cableUrl(String category, String filename) =>
      '$baseUrl/cables/$category/$filename';

  /// Construit l'URL d'une image Receptrice (resultat).
  ///
  /// Convention : receptrices/{theme}/d{distance}/{sujet}_{transformations}.webp
  /// Exemple : receptriceUrl('savane', 1, 'lion_miroir_h.webp')
  ///        -> "https://.../receptrices/savane/d1/lion_miroir_h.webp"
  ///
  /// [theme]    : meme theme que l'Emettrice racine
  /// [distance] : niveau de distance (1, 2 ou 3)
  /// [filename] : nom compose = sujet + transformations accumulees
  static String receptriceUrl(String theme, int distance, String filename) =>
      '$baseUrl/receptrices/$theme/d$distance/$filename';
}
