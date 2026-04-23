// =============================================================
// FICHIER : lib/domain/entities/user_entity.dart
// ROLE   : Definir la structure d'un JOUEUR dans TRIALGO
// COUCHE : Domain > Entities
// =============================================================
//
// QU'EST-CE QU'UN JOUEUR ?
// ------------------------
// Un joueur est un utilisateur inscrit qui possede :
//   - Un compte Supabase Auth (email ou Google)
//   - Un profil dans la table "user_profiles"
//   - Un code d'activation lie a son appareil
//
// Le profil contient les donnees de progression :
//   - Score total cumule (toutes sessions confondues)
//   - Niveau actuel (determines par les niveaux reussis)
//   - Vies restantes (consommees par les erreurs, rechargees avec le temps)
//
// REFERENCE : Recueil de conception v3.0, section 3.4
// =============================================================

/// Represente le profil d'un joueur TRIALGO.
///
/// Correspond a une ligne de la table `user_profiles` dans Supabase.
/// L'[id] est le meme que l'UID Supabase Auth (cle primaire partagee).
///
/// Le profil est charge en temps reel depuis Supabase via un StreamProvider.
/// Chaque modification (score, niveau, vies) est refletee immediatement
/// dans l'interface grace a Supabase Realtime.
class UserEntity {

  // =============================================================
  // PROPRIETE : id
  // =============================================================
  // Type    : String
  // Contenu : UUID de l'utilisateur Supabase Auth
  // Exemple : "550e8400-e29b-41d4-a716-446655440000"
  //
  // C'est le MEME identifiant que dans auth.users de Supabase.
  // La table user_profiles utilise cet ID comme cle primaire
  // ET cle etrangere vers auth.users(id) :
  //   id UUID PRIMARY KEY REFERENCES auth.users(id)
  //
  // Cela garantit une correspondance 1-pour-1 entre un compte Auth
  // et un profil joueur. Pas de profil sans compte, pas de compte
  // sans profil (le profil est cree automatiquement a l'inscription).
  // =============================================================
  final String id;

  // =============================================================
  // PROPRIETE : username
  // =============================================================
  // Type    : String
  // Contenu : pseudo du joueur, affiche dans le jeu et le leaderboard
  // Exemple : "LionMaster"
  //
  // Contraintes SQL :
  //   - TEXT UNIQUE NOT NULL : chaque pseudo est unique
  //   - Genere automatiquement a l'inscription ("Joueur_" + partie de l'UID)
  //   - Modifiable par le joueur dans les parametres
  //
  // Affiche dans :
  //   - Le menu principal (en haut)
  //   - Le leaderboard (classement global)
  //   - L'ecran de fin de niveau (recapitulatif)
  // =============================================================
  final String username;

  // =============================================================
  // PROPRIETE : avatarUrl
  // =============================================================
  // Type    : String? (nullable)
  // Contenu : URL de l'avatar du joueur (image de profil)
  // Exemple : "https://olovolsbopjporwpuphm.supabase.co/.../avatars/550e8400.webp"
  //
  // Nullable car : le joueur peut ne pas avoir d'avatar.
  // A l'inscription, avatarUrl est null. Le joueur peut en choisir
  // un plus tard dans les parametres.
  //
  // Si null, l'interface affiche une icone par defaut (Icons.person).
  // =============================================================
  final String? avatarUrl;

  // =============================================================
  // PROPRIETE : totalScore
  // =============================================================
  // Type    : int
  // Contenu : score cumule sur TOUTES les sessions de jeu
  // Exemple : 4250
  //
  // Ce score est la SOMME de tous les points gagnes dans toutes
  // les sessions terminees. Il ne diminue jamais (pas de score negatif).
  //
  // Mis a jour : a la fin de chaque niveau reussi
  //   UPDATE user_profiles SET total_score = total_score + score_session
  //
  // Utilise pour : le classement global (leaderboard)
  //   ORDER BY total_score DESC
  //
  // Contrainte SQL : INT DEFAULT 0
  // =============================================================
  final int totalScore;

  // =============================================================
  // PROPRIETE : currentLevel
  // =============================================================
  // Type    : int
  // Contenu : numero du niveau actuel du joueur (1 a 23+)
  // Exemple : 7
  //
  // Determine :
  //   - La distance des trios utilises (D1, D2, D3)
  //   - Les configurations de question (A, B, C)
  //   - Le nombre de questions par session
  //   - Le seuil de reussite
  //   - Le temps par tour
  //   - Les points de base
  //
  // Incremente : a la fin d'un niveau REUSSI
  //   UPDATE user_profiles SET current_level = current_level + 1
  //
  // Jamais decremente : un joueur ne perd jamais de niveau.
  //
  // Contrainte SQL : INT DEFAULT 1
  // =============================================================
  final int currentLevel;

  // =============================================================
  // PROPRIETE : lives
  // =============================================================
  // Type    : int
  // Contenu : nombre de vies restantes (0 a 5)
  // Exemple : 3
  //
  // Les vies sont la monnaie du jeu :
  //   - Stock initial : 5 vies a la creation du compte
  //   - Maximum : 5 vies (jamais depasse)
  //   - Cout d'une mauvaise reponse : -1 vie
  //   - Cout d'un timeout : -1 vie
  //   - Recharge automatique : +1 vie toutes les 30 minutes (pg_cron)
  //
  // Si vies = 0 :
  //   - Session impossible jusqu'a la recharge
  //   - Affichage : "Plus de vies ! Prochaine recharge dans X minutes."
  //   - Bouton "Jouer" bloque
  //
  // Contrainte SQL : INT DEFAULT 5
  // =============================================================
  final int lives;

  // =============================================================
  // PROPRIETE : livesLastRefill
  // =============================================================
  // Type    : DateTime? (nullable)
  // Contenu : date et heure du dernier rechargement de vies
  // Exemple : DateTime(2025, 9, 15, 14, 0, 0) = 15 sept 2025 a 14h00
  //
  // DateTime est le type Dart pour representer une date et heure.
  //
  // Utilite : permet de calculer QUAND aura lieu la prochaine
  // recharge de vie. Si la derniere recharge etait a 14h00 et que
  // le delai est de 30 minutes, la prochaine sera a 14h30.
  //
  // Le rechargement est gere par pg_cron cote Supabase :
  // un job PostgreSQL qui s'execute toutes les 30 minutes et
  // incremente les vies des joueurs ayant lives < 5.
  //
  // Nullable car : a la creation du compte, ce champ est rempli
  // avec NOW() mais pourrait etre null dans des cas limites.
  //
  // Contrainte SQL : TIMESTAMPTZ DEFAULT now()
  // =============================================================
  final DateTime? livesLastRefill;

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // Tous les champs sont "required" sauf avatarUrl et livesLastRefill
  // car un profil a toujours un id, username, score, level et lives.
  // =============================================================

  /// Cree une nouvelle instance de [UserEntity].
  ///
  /// Exemple :
  /// ```dart
  /// final joueur = UserEntity(
  ///   id: '550e8400-...',
  ///   username: 'LionMaster',
  ///   totalScore: 4250,
  ///   currentLevel: 7,
  ///   lives: 3,
  /// );
  /// ```
  const UserEntity({
    required this.id,              // UUID Supabase Auth (obligatoire)
    required this.username,        // Pseudo unique (obligatoire)
    this.avatarUrl,                // URL avatar (null si pas d'avatar)
    required this.totalScore,      // Score total (obligatoire)
    required this.currentLevel,    // Niveau actuel (obligatoire)
    required this.lives,           // Vies restantes (obligatoire)
    this.livesLastRefill,          // Derniere recharge (optionnel)
  });
}
