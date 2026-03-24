// =============================================================
// FICHIER : lib/core/network/supabase_client.dart
// ROLE   : Initialiser et exposer le client Supabase (singleton)
// COUCHE : Core > Network
// =============================================================
//
// POURQUOI CE FICHIER ?
// ---------------------
// Supabase est notre backend unique. Toute l'application a besoin
// d'y acceder : authentification, lecture de cartes, sessions de jeu, etc.
//
// Ce fichier centralise la configuration de connexion a Supabase
// en UN seul endroit. Aucun autre fichier ne doit contenir l'URL
// ou la cle du projet Supabase.
//
// PATTERN : Singleton
// -------------------
// Le "singleton" est un patron de conception qui garantit qu'il
// n'existe qu'UNE SEULE instance d'un objet dans toute l'application.
//
// Ici, le SDK supabase_flutter gere le singleton en interne :
// - Supabase.initialize() cree l'instance unique au demarrage
// - Supabase.instance.client la recupere partout dans le code
//
// On expose un getter "supabase" pour simplifier l'acces.
//
// SECURITE :
// ----------
// La cle "anon" est une cle PUBLIQUE. Elle est volontairement
// visible dans le code client. Ce n'est PAS un secret.
// La securite repose sur les politiques RLS de PostgreSQL
// (Row Level Security), pas sur cette cle.
// =============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
// Ce package fournit :
//   - Supabase.initialize() : initialisation au demarrage
//   - Supabase.instance.client : acces au client configure
//   - SupabaseClient : type du client (auth, from, storage, functions)

// ---------------------------------------------------------------
// CONSTANTES DE CONNEXION SUPABASE
// ---------------------------------------------------------------
// Ces valeurs sont specifiques au projet TRIALGO.
// Elles se trouvent dans le dashboard Supabase :
//   Settings > API > Project URL et Project API keys (anon/public)
// ---------------------------------------------------------------

/// URL du projet Supabase TRIALGO.
///
/// Format : `https://<PROJECT_REF>.supabase.co`
/// Le PROJECT_REF ("olovolsbopjporwpuphm") est l'identifiant unique
/// du projet, genere automatiquement par Supabase a la creation.
const String supabaseUrl = 'https://olovolsbopjporwpuphm.supabase.co';

/// Cle anonyme (anon key) du projet Supabase.
///
/// Cette cle est PUBLIQUE et SAFE a inclure dans le code client.
/// Elle permet au SDK d'identifier le projet lors des requetes API.
///
/// ATTENTION : cette cle n'accorde AUCUN privilege special.
/// Les droits d'acces sont controles par les politiques RLS
/// definies cote PostgreSQL (voir section 14 du recueil).
const String supabaseAnonKey = 'sb_publishable_HSet9rvoO4ARe7BdVGZlLg__T-UZVHH';

// ---------------------------------------------------------------
// GETTER GLOBAL : acces rapide au client Supabase
// ---------------------------------------------------------------
// Au lieu d'ecrire "Supabase.instance.client" partout dans le code,
// on definit un getter court "supabase" accessible globalement.
//
// Utilisation dans n'importe quel fichier :
//   import 'package:trialgo/core/network/supabase_client.dart';
//   final data = await supabase.from('cards').select();
// ---------------------------------------------------------------

/// Getter global pour acceder au client Supabase.
///
/// Prerequis : [initSupabase] doit avoir ete appele dans main().
/// Si appele avant l'initialisation, une exception sera levee.
///
/// Exemples d'utilisation :
/// ```dart
/// // Lire des donnees
/// final cards = await supabase.from('cards').select();
///
/// // Verifier l'authentification
/// final user = supabase.auth.currentUser;
///
/// // Appeler une Edge Function
/// final response = await supabase.functions.invoke('activate-code');
/// ```
SupabaseClient get supabase => Supabase.instance.client;

// ---------------------------------------------------------------
// FONCTION D'INITIALISATION
// ---------------------------------------------------------------
// Appelee UNE SEULE FOIS au demarrage de l'application (dans main).
// Configure le SDK Supabase avec l'URL et la cle du projet.
// ---------------------------------------------------------------

/// Initialise la connexion a Supabase.
///
/// Cette fonction DOIT etre appelee dans [main()] AVANT [runApp()].
/// Elle est asynchrone car elle :
///   1. Configure le SDK avec l'URL et la cle
///   2. Restaure la session precedente (si le joueur etait connecte)
///   3. Prepare le cache de tokens pour les requetes authentifiees
///
/// Exemple dans main.dart :
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initSupabase();
///   runApp(const ProviderScope(child: TrialgoApp()));
/// }
/// ```
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,       // URL du projet
    anonKey: supabaseAnonKey, // Cle publique
    // --- Options supplementaires (valeurs par defaut) ---
    // authOptions: configure le comportement de l'authentification
    //   - authFlowType: le type de flux OAuth (pkce = plus securise)
    //   - autoRefreshToken: renouvelle le JWT automatiquement avant expiration
  );
}
