// =============================================================
// FICHIER : supabase_config.dart
// ROLE    : Centraliser les credentials et constantes Supabase
// =============================================================
//
// Pourquoi un fichier dedie ?
// - Eviter de copier l'URL/anon key dans plusieurs endroits.
// - Un seul point a editer pour basculer staging/prod plus tard.
// - Faciliter les tests : on peut mocker SupabaseConfig.
//
// La cle "anon" (publishable) est PUBLIQUE par design : elle ne
// donne acces qu'aux operations autorisees par les RLS. Toutes
// les ecritures cards/nodes/games sont gardees par is_admin_user()
// (migration 005). Une fuite de cette cle n'expose donc PAS la
// possibilite d'ecrire dans la base.
//
// La cle "service_role" ne doit JAMAIS apparaitre dans cette app :
// elle bypass les RLS, ce qui serait un trou de securite massif
// si elle se retrouvait dans un binaire mobile.
// =============================================================

class SupabaseConfig {
  // Constructeur prive : la classe n'est pas instanciable. On
  // l'utilise uniquement via ses constantes statiques.
  SupabaseConfig._();

  // URL du projet Supabase. Stable et publique. C'est l'adresse
  // de l'API REST + de Supabase Storage pour ce projet.
  static const String url = 'https://olovolsbopjporwpuphm.supabase.co';

  // Anon key (publishable, RLS-gated). Le SDK Supabase l'utilise
  // pour signer les requetes en tant qu'utilisateur "anon" ou
  // "authenticated" selon la session.
  static const String anonKey =
      'sb_publishable_HSet9rvoO4ARe7BdVGZlLg__T-UZVHH';

  // Nom du bucket Storage qui contient les images de cartes.
  // Cree/configure par la migration 005 (public read, admin write).
  static const String cardsBucket = 'trialgo-cards';

  // URL publique de base des fichiers du bucket. Tout fichier
  // "abc.jpg" uploade donnera l'URL :
  //   {storagePublicBase}/abc.jpg
  // C'est cette URL qu'on stocke dans cards.image_path apres
  // l'upload, pour que le jeu et le dashboard puissent l'afficher.
  static String get storagePublicBase =>
      '$url/storage/v1/object/public/$cardsBucket';
}
