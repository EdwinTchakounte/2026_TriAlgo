// =============================================================
// FICHIER : lib/core/network/supabase_client.dart
// ROLE   : Initialiser et exposer le client Supabase (singleton)
// COUCHE : Core > Network
// =============================================================
//
// POURQUOI CE FICHIER ?
// ---------------------
// Supabase a ete le backend unique de l'app. Il ne l'est plus : le
// backend de reference est desormais ok_trialgo_backend (FastAPI), et
// Supabase ne subsiste que comme chemin de repli, active uniquement
// quand ApiConfig.mode vaut ApiMode.supabase.
//
// Ce fichier centralise la configuration de connexion a Supabase
// en UN seul endroit. Aucun autre fichier ne doit contenir l'URL
// ou la cle du projet Supabase.
//
// INITIALISATION CONDITIONNELLE
// -----------------------------
// initSupabaseSiNecessaire() ne fait RIEN en mode fastapi. L'app
// demarre donc sans ouvrir de connexion Supabase, sans restaurer de
// session persistee, et sans dependre de la disponibilite du projet
// Supabase.
//
// Consequence directe : en mode fastapi, le getter `supabase`
// ci-dessous n'a aucun client a retourner. Il leve alors une erreur
// explicite plutot que l'AssertionError obscure du SDK. Tout code qui
// l'atteint dans ce mode est un oubli de branchement, pas une
// situation normale.
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

// ApiConfig decide si Supabase doit etre initialise ou non.
import 'package:trialgo/core/api/api_config.dart';
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
SupabaseClient get supabase {
  // Garde-fou : en mode fastapi, Supabase.initialize() n'a jamais ete
  // appele. Sans ce test, le SDK leve une AssertionError generique
  // ("You must initialize the supabase instance...") qui ne dit rien
  // du vrai probleme. On prefere un message qui nomme la cause et
  // designe la correction a faire.
  if (!_supabaseInitialise) {
    throw StateError(
      'Client Supabase indisponible : ApiConfig.mode vaut '
      '${ApiConfig.mode.name}, donc Supabase n\'a pas ete initialise au '
      'demarrage. Le code appelant doit passer par les datasources HTTP '
      '(lib/data/datasources/http/) ou etre place derriere un test '
      'ApiConfig.isSupabase.',
    );
  }
  return Supabase.instance.client;
}

/// Passe a vrai une fois [initSupabase] execute.
///
/// Reste faux pendant toute la vie du processus en mode fastapi.
bool _supabaseInitialise = false;

/// Indique si le client Supabase est utilisable.
bool get supabaseEstDisponible => _supabaseInitialise;

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
  _supabaseInitialise = true;
}

// =============================================================
// FONCTION : initSupabaseSiNecessaire
// =============================================================
// Point d'entree appele par main(). C'est elle, et non
// initSupabase(), qui doit etre utilisee au demarrage.
//
// En mode fastapi elle ne fait rien du tout :
//   - aucune requete reseau vers Supabase au lancement
//   - aucune restauration de session persistee
//   - l'app demarre meme si le projet Supabase est suspendu,
//     supprime, ou simplement injoignable
//
// C'est ce qui permet de deployer l'app joueur sans dependre d'un
// service qu'elle n'utilise plus.
// =============================================================

/// Initialise Supabase uniquement si le mode courant en a besoin.
///
/// Ne fait rien en [ApiMode.fastapi].
Future<void> initSupabaseSiNecessaire() async {
  if (!ApiConfig.isSupabase) return;
  await initSupabase();
}
