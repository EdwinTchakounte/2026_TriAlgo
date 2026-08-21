// =============================================================
// FICHIER : supabase_config.dart
// ROLE    : Centraliser les credentials Supabase
// =============================================================
//
// Pourquoi un fichier dedie ?
// On evite de hardcoder URL et anon key dans plusieurs endroits.
// Un seul point de verite => si on bascule vers un autre projet
// (staging, prod), on change UNE constante.
//
// La cle "anon" (publishable) est CONCUE pour etre publique :
// elle ne donne acces qu'aux operations autorisees par RLS.
// La cle "service_role" (admin) ne doit JAMAIS apparaitre cote
// client : elle bypass RLS, donc clientside = fuite totale.
// =============================================================

class SupabaseConfig {
  // URL du projet Supabase (memoire projet : project ref olovolsbopjporwpuphm)
  static const String url = 'https://olovolsbopjporwpuphm.supabase.co';

  // Anon key (publique, OK cote client). Limitee par les RLS.
  // Pour ecrire dans cards / nodes / storage, l'utilisateur doit
  // etre authentifie ET avoir is_admin = TRUE (cf migration 005).
  static const String anonKey =
      'sb_publishable_HSet9rvoO4ARe7BdVGZlLg__T-UZVHH';

  // Nom du bucket Storage qui contient les images des cartes.
  // C'est ici qu'on uploadera les fichiers via la page Cards.
  static const String cardsBucket = 'trialgo-cards';

  // URL publique de base des fichiers du bucket. Quand on uploade
  // un fichier "lion_001.jpg", l'URL finale sera :
  //   {storagePublicBase}/lion_001.jpg
  // C'est cette URL qu'on stockera dans cards.image_path.
  static String get storagePublicBase =>
      '$url/storage/v1/object/public/$cardsBucket';
}
