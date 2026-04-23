// =============================================================
// FICHIER : lib/domain/usecases/activate_code_usecase.dart
// ROLE   : Activer un code de jeu physique
// COUCHE : Domain > Usecases
// =============================================================
//
// QU'EST-CE QUE L'ACTIVATION ?
// ----------------------------
// TRIALGO est un jeu de cartes PHYSIQUE + NUMERIQUE.
// Le joueur achete une boite de jeu qui contient un CODE UNIQUE
// imprime a l'interieur (ex: "TRLG-4X9K-2M7P").
//
// Ce code doit etre saisi dans l'application pour debloquer le jeu.
// Le code est lie a UN SEUL appareil (telephone) pour empecher
// le partage entre plusieurs personnes.
//
// SCENARIOS :
//   A) Code valide + non active     -> Activation + lien Device ID
//   B) Code active + meme appareil  -> Reconnexion autorisee
//   C) Code active + autre appareil -> REFUS "Code deja utilise"
//   D) Code inexistant              -> REFUS "Code invalide"
//
// La verification se fait cote SERVEUR (Edge Function) pour
// empecher la triche (un joueur malin pourrait contourner
// la verification client en modifiant le code de l'app).
//
// REFERENCE : Recueil de conception v3.0, section 10
// =============================================================

// Import du client Supabase pour appeler l'Edge Function.
// C'est un import de la couche Core (autorise dans Domain).
import 'package:trialgo/core/network/supabase_client.dart';

// Import des erreurs structurees pour retourner des erreurs typees.
import 'package:trialgo/core/error/failures.dart';

/// Usecase : active un code de jeu physique.
///
/// Appelle l'Edge Function `activate-code` de Supabase qui :
/// 1. Verifie que le code existe dans `activation_codes`
/// 2. Verifie qu'il n'est pas deja utilise sur un autre appareil
/// 3. Si OK : lie le code a l'appareil et retourne un succes
///
/// Ce usecase retourne un [ActivationResult] qui indique
/// le statut de l'activation (succes, reconnexion, ou erreur).
class ActivateCodeUseCase {

  // =============================================================
  // METHODE : call
  // =============================================================
  // Pas de repository ici : on appelle directement une Edge Function.
  //
  // Pourquoi pas de repository ?
  // Les Edge Functions sont des endpoints CUSTOM (pas du CRUD simple).
  // Elles contiennent la logique metier cote serveur.
  // Le usecase agit ici comme un simple CLIENT de la fonction.
  //
  // On pourrait creer un repository "ActivationRepository" mais
  // ce serait une abstraction inutile : il n'y a qu'UNE seule
  // operation (activer un code) et elle se fait via Edge Function.
  //
  // Parametres :
  //   codeValue : le code saisi par le joueur (ex: "TRLG-4X9K-2M7P")
  //   userId    : UUID de l'utilisateur connecte (Supabase Auth)
  //   deviceId  : identifiant unique de l'appareil (device_info_plus)
  //
  // Retour : Future<ActivationResult>
  //   -> Objet contenant le statut et un eventuel message
  // =============================================================

  /// Active un code de jeu physique.
  ///
  /// [codeValue] : le code imprime dans la boite (ex: "TRLG-4X9K-2M7P").
  /// [userId]    : UUID de l'utilisateur connecte.
  /// [deviceId]  : identifiant unique de l'appareil.
  ///
  /// Retourne un [ActivationResult] indiquant le statut.
  /// Leve une [ActivationFailure] en cas d'erreur.
  Future<ActivationResult> call({
    required String codeValue,
    required String userId,
    required String deviceId,
  }) async {

    // --- Validation locale du format ---
    // Avant d'envoyer une requete reseau, on verifie que le code
    // a le bon format. Cela evite un appel reseau inutile.
    //
    // "RegExp" : expression reguliere (regex).
    // "r'^[A-Z0-9-]{16}$'" : le "r" devant les guillemets signifie
    //   "raw string" (pas d'echappement des \).
    //
    // Decomposition de la regex :
    //   ^          : debut de la chaine
    //   [A-Z0-9-]  : un caractere parmi A-Z, 0-9, ou tiret
    //   {16}       : exactement 16 caracteres
    //   $          : fin de la chaine
    //
    // "hasMatch(codeValue)" : retourne true si le code correspond.
    // "!" inverse le booleen : true si le code ne correspond PAS.
    if (!RegExp(r'^[A-Z0-9-]{16}$').hasMatch(codeValue)) {
      // Le format est incorrect -> on leve une erreur SANS appel reseau.
      // "throw" lance une exception qui remonte au code appelant.
      throw ActivationFailure.invalidFormat();
    }

    // --- Appel de l'Edge Function ---
    // "supabase.functions.invoke" appelle une Edge Function Supabase.
    //
    // Les Edge Functions sont des fonctions TypeScript/Deno executees
    // COTE SERVEUR. Elles ont acces au service_role (tous les droits)
    // et peuvent faire des operations que le client ne peut pas faire
    // (comme modifier activation_codes, protege par RLS).
    //
    // "try/catch" : gere les erreurs reseau et les erreurs serveur.
    try {
      // "invoke" envoie une requete POST a l'Edge Function.
      //
      // Parametres :
      //   'activate-code' : nom de la fonction (dans supabase/functions/)
      //   body: {...}     : le corps JSON de la requete
      //
      // "await" : on attend la reponse du serveur.
      final response = await supabase.functions.invoke(
        'activate-code',
        body: {
          'code_value': codeValue, // Le code saisi par le joueur
          'user_id': userId,       // UUID de l'utilisateur connecte
          'device_id': deviceId,   // ID unique de l'appareil
        },
      );

      // --- Analyse de la reponse ---
      // "response.data" est un Map<String, dynamic> (JSON decode).
      // Le champ "status" indique le resultat de l'operation.
      //
      // "as Map<String, dynamic>" : cast explicite du type.
      // Dart ne sait pas que response.data est un Map, on doit lui dire.
      final data = response.data as Map<String, dynamic>;

      // "switch" sur le statut retourne par le serveur.
      // Chaque cas correspond a un scenario defini dans le recueil.
      return switch (data['status']) {
        // Scenario A : code valide, premiere activation
        'activated' => ActivationResult(
          success: true,
          message: data['message'] as String,  // "Code active avec succes"
        ),

        // Scenario B : code deja active sur le MEME appareil (reconnexion OK)
        'already_activated_same_device' => ActivationResult(
          success: true,
          message: data['message'] as String,  // "Reconnexion autorisee"
        ),

        // Scenario C : code deja active sur un AUTRE appareil (refus)
        'device_conflict' => throw ActivationFailure.deviceConflict(),

        // Scenario D : code inexistant
        'not_found' => throw ActivationFailure.notFound(),

        // Cas non prevu : erreur generique
        // "_" est le wildcard (capture tous les cas non listes).
        _ => throw ActivationFailure(
          message: data['message'] as String? ?? 'Erreur inconnue',
          code: 'unknown',
        ),
      };

    } catch (e) {
      // Si l'erreur est deja une ActivationFailure, on la relance telle quelle.
      // "is" verifie le TYPE de l'objet a l'execution (runtime type check).
      // "rethrow" relance la meme exception sans la modifier.
      if (e is ActivationFailure) rethrow;

      // Pour toute autre erreur (reseau, timeout, etc.),
      // on la transforme en ServerFailure.
      throw ServerFailure(
        message: 'Erreur reseau. Verifiez votre connexion et reessayez.',
        code: 'activation_network_error',
      );
    }
  }
}

// =============================================================
// CLASSE : ActivationResult
// =============================================================
// Represente le resultat d'une tentative d'activation.
//
// C'est un objet simple (pas une entite Domain car c'est un
// resultat ponctuel, pas un concept metier persistant).
//
// Contient :
//   - success : true si l'activation est reussie (ou reconnexion)
//   - message : message descriptif du resultat
// =============================================================

/// Resultat d'une tentative d'activation de code.
class ActivationResult {
  /// `true` si le code a ete active avec succes ou si la
  /// reconnexion est autorisee (meme appareil).
  final bool success;

  /// Message descriptif du resultat (ex: "Code active avec succes").
  final String message;

  /// Cree un resultat d'activation.
  const ActivationResult({
    required this.success,
    required this.message,
  });
}
