// =============================================================
// FICHIER : game.dart (entite domain)
// ROLE    : Modeliser un jeu TRIALGO (theme + metadata)
// =============================================================
//
// Un "Game" est l'unite mere : il regroupe son propre catalogue
// de cartes et son propre graphe de noeuds. On peut avoir
// "TRIALGO Savane", "TRIALGO Ocean", "TRIALGO Forest", chacun
// totalement isole des autres.
//
// L'app admin permet de :
//   - lister les games existants
//   - en creer de nouveaux (etape 1 du wizard)
//   - selectionner un game pour ensuite ajouter cartes et trios
//
// Cette classe est PURE (pas de json, pas de Supabase) : elle
// represente le "concept metier". La couche data definira le
// GameModel qui sait se serialiser.
// =============================================================

class Game {
  // UUID Supabase. Genere cote DB par DEFAULT gen_random_uuid().
  final String id;
  // Nom affichable, ex: "TRIALGO Savane".
  final String name;
  // Description courte. Peut etre null si pas renseignee.
  final String? description;
  // Theme cosmetique (ex: "savane", "ocean"). Sert au tagging.
  final String? theme;
  // URL d'une image de pochette. Pour l'instant on n'a pas d'UI
  // d'upload pour ce champ, mais le schema l'accepte.
  final String? coverImage;
  // Si false, le jeu n'apparait plus dans le selecteur (soft hide).
  final bool isActive;
  // Date de creation (UTC). Utile pour trier par recence.
  final DateTime createdAt;

  const Game({
    required this.id,
    required this.name,
    this.description,
    this.theme,
    this.coverImage,
    required this.isActive,
    required this.createdAt,
  });

  // Helper : produire une copie avec quelques champs modifies.
  // Pratique quand on update le nom en gardant le reste intact.
  Game copyWith({
    String? id,
    String? name,
    String? description,
    String? theme,
    String? coverImage,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Game(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      theme: theme ?? this.theme,
      coverImage: coverImage ?? this.coverImage,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
