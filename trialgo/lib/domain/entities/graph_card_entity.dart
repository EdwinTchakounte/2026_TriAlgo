// =============================================================
// FICHIER : lib/domain/entities/graph_card_entity.dart
// ROLE   : Representer une carte NEUTRE du catalogue
// COUCHE : Domain > Entities
// =============================================================
//
// DIFFERENCE AVEC L'ANCIEN CardEntity :
// --------------------------------------
// L'ancien CardEntity avait un "cardType" (emettrice, cable,
// receptrice) et un "distanceLevel". Ces champs n'existent plus.
//
// Dans la nouvelle logique, une carte est NEUTRE :
//   - Pas de type fixe
//   - Pas de distance
//   - Juste une image avec un label
//
// Le role de la carte (E, C ou R) est determine par sa POSITION
// dans un noeud du graphe (GraphNodeEntity).
//
// La meme carte peut etre :
//   - Emettrice dans le noeud N01
//   - Cable dans le noeud N25
//   - Receptrice dans le noeud N12
//
// REFERENCE : Discussion architecture graphe, avril 2026
// =============================================================

/// Represente une carte du catalogue TRIALGO.
///
/// Une carte est une IMAGE neutre sans role predetermine.
/// Son role (Emettrice, Cable ou Receptrice) depend de sa
/// position dans un [GraphNodeEntity].
///
/// Exemple :
/// ```dart
/// final lion = GraphCardEntity(
///   id: 'uuid-001',
///   label: 'Lion',
///   imagePath: 'savane/lion_base.webp',
/// );
/// // Cette carte peut etre E dans un noeud, C dans un autre.
/// ```
class GraphCardEntity {

  // =============================================================
  // PROPRIETE : id
  // =============================================================
  // UUID v4 genere par PostgreSQL (gen_random_uuid()).
  // Identifiant unique de cette carte dans la table "cards".
  // =============================================================

  /// Identifiant unique de la carte.
  final String id;

  // =============================================================
  // PROPRIETE : label
  // =============================================================
  // Nom descriptif de la carte, visible dans l'interface admin.
  // Pas affiche au joueur pendant le jeu — le joueur ne voit
  // que l'image.
  // Exemples : 'Lion', 'Motif Etoile', 'Lion Etoile'
  // =============================================================

  /// Nom descriptif de la carte (usage admin).
  final String label;

  // =============================================================
  // PROPRIETE : imagePath
  // =============================================================
  // Chemin RELATIF de l'image dans le bucket Supabase Storage.
  // L'URL complete est reconstruite par le getter "imageUrl".
  //
  // Exemples :
  //   'savane/lion_base.webp'
  //   'motifs/etoile.webp'
  //   'fusions/lion_etoile.webp'
  // =============================================================

  /// Chemin relatif de l'image dans Supabase Storage.
  final String imagePath;

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // "const" : permet la creation d'instances constantes.
  // Tous les champs sont obligatoires — une carte sans image
  // ou sans label n'a pas de sens.
  // =============================================================

  // =============================================================
  // PROPRIETE : thumbPath
  // =============================================================
  // Localisation de la vignette 256 px, ou null.
  //
  // POURQUOI NULLABLE
  // -----------------
  // Les vignettes ont ete introduites apres coup (migration 0010).
  // Une carte creee avant, ou servie par le chemin Supabase, n'en a
  // pas. Le contrat est donc : null signifie « utilise l'image
  // pleine », jamais « erreur ». C'est ce que fait le getter
  // [thumbUrl] ci-dessous, et c'est pour cela qu'il ne renvoie
  // jamais null lui-meme -- l'appelant n'a aucun cas a traiter.
  // =============================================================

  /// Chemin ou URL de la vignette, ou null si la carte n'en a pas.
  final String? thumbPath;

  /// Cree une carte du catalogue.
  const GraphCardEntity({
    required this.id,
    required this.label,
    required this.imagePath,
    this.thumbPath,
  });

  // =============================================================
  // GETTER : imageUrl
  // =============================================================
  // Reconstruit l'URL publique complete a partir du chemin relatif
  // et de l'URL de base du bucket Supabase Storage.
  // =============================================================

  /// URL publique complete de l'image.
  ///
  /// DEUX CAS GERES :
  ///   1. Si imagePath commence par "http" (ex: picsum.photos pour le test
  ///      ou tout CDN externe), retourne directement la valeur.
  ///   2. Sinon, considere imagePath comme un chemin relatif dans le bucket
  ///      Supabase Storage et reconstitue l'URL publique complete.
  ///
  /// Cela permet de seeder la BDD avec des URLs picsum pour tester
  /// sans uploader d'images dans Supabase Storage.
  ///
  /// Utilise par les widgets Flutter pour afficher l'image :
  /// ```dart
  /// Image.network(card.imageUrl)
  /// ```
  String get imageUrl {
    // Cas 1 : URL complete (ex: picsum.photos, CDN externe).
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    // Cas 2 : chemin relatif dans Supabase Storage.
    return 'https://olovolsbopjporwpuphm.supabase.co/storage/v1/object/public/trialgo-cards/$imagePath';
  }

  // =============================================================
  // GETTER : thumbUrl
  // =============================================================
  // URL a utiliser quand la carte s'affiche PETITE : la grille de
  // six choix, ou chaque vignette occupe environ 150 px.
  //
  // COMBIEN CELA CHANGE
  // -------------------
  // Une photo de carte pese environ 220 Ko en 1024 px ; sa vignette
  // 256 px, quelques kilo-octets. Une grille de six choix passe donc
  // de l'ordre du megaoctet a quelques dizaines de kilo-octets, et
  // le deck complet de 76 cartes de ~16 Mo a moins d'un mega.
  //
  // REPLI SILENCIEUX, ET VOULU
  // --------------------------
  // Sans vignette, on rend l'image pleine. Le joueur voit la bonne
  // carte, simplement plus lourde. C'est le seul comportement
  // acceptable : une carte ancienne ne doit pas cesser de
  // s'afficher parce qu'un champ ajoute plus tard est vide.
  // =============================================================

  /// URL de la vignette, ou celle de l'image pleine a defaut.
  ///
  /// Ne renvoie jamais null : l'appelant peut l'utiliser directement.
  String get thumbUrl {
    final chemin = thumbPath;
    if (chemin == null || chemin.isEmpty) return imageUrl;
    if (chemin.startsWith('http://') || chemin.startsWith('https://')) {
      return chemin;
    }
    return 'https://olovolsbopjporwpuphm.supabase.co/storage/v1/object/public/trialgo-cards/$chemin';
  }
}
