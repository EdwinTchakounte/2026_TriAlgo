// =============================================================
// FICHIER : lib/core/session/session_utilisateur.dart
// ROLE   : Identite de l'utilisateur connecte, independamment du backend
// COUCHE : Core > Session
// =============================================================
//
// LE PROBLEME QU'IL RESOUT
// ------------------------
// Plusieurs endroits de l'app ont besoin de savoir, de maniere
// SYNCHRONE (dans un build(), dans la construction d'une cle de
// preferences...), qui est l'utilisateur courant :
//
//   - AdminConstants.isAdmin()      -> afficher ou non l'entree admin
//   - OnboardingPrefs               -> scoper une cle SharedPreferences
//
// En mode supabase, la reponse etait immediate : supabase.auth
// .currentUser, un cache tenu par le SDK. En mode fastapi il n'y a
// plus de SDK qui tienne ce cache, et le seul moyen de connaitre
// l'utilisateur est un appel reseau asynchrone a /api/auth/me.
//
// Appeler ce getter sans Supabase initialise levait donc une erreur,
// et le rendre asynchrone imposerait de reecrire les appelants.
//
// LA SOLUTION
// -----------
// Un petit cache en memoire, alimente une fois a l'ouverture de
// session (login, inscription, ou restauration au demarrage), et lu
// ensuite de maniere synchrone par tout le monde.
//
// En mode supabase, on ne duplique RIEN : les getters delegent au SDK,
// qui reste la source de verite. Le cache ne sert qu'au mode fastapi.
// Aucun risque de desynchronisation entre les deux.
//
// PORTEE
// ------
// Volontairement en memoire seulement, jamais persiste. Ce n'est pas
// un magasin de session : les jetons, eux, vivent dans TokenStorage
// (stockage securise). Perdre ce cache au redemarrage est sans
// consequence puisque TAuthGate le repeuple au lancement suivant.
// =============================================================

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/core/network/supabase_client.dart';

/// Identite de l'utilisateur connecte, valable dans les deux modes.
class SessionUtilisateur {
  // Constructeur prive : classe purement statique, jamais instanciee.
  SessionUtilisateur._();

  // --- Cache alimente en mode fastapi uniquement ---
  static String? _id;
  static String? _email;
  static bool _estAdmin = false;

  // =============================================================
  // METHODE : memoriser
  // =============================================================
  // A appeler des qu'une identite est connue, c'est-a-dire apres :
  //   - une inscription reussie   (TAuthPage)
  //   - une connexion reussie     (TAuthPage)
  //   - la restauration d'une session au demarrage (TAuthGate)
  //
  // Les trois champs viennent de la reponse de /api/auth/me ou de
  // /api/auth/register, qui exposent id, email et is_admin.
  // =============================================================

  /// Enregistre l'identite courante (mode fastapi).
  static void memoriser({
    required String? id,
    required String? email,
    required bool estAdmin,
  }) {
    _id = id;
    _email = email;
    _estAdmin = estAdmin;
  }

  /// Enregistre l'identite a partir d'une reponse `/api/auth/me`.
  ///
  /// Tolere une charge utile partielle : chaque champ absent devient
  /// null (ou false pour is_admin) sans lever d'exception.
  static void memoriserDepuisJson(Map<String, dynamic>? json) {
    if (json == null) {
      effacer();
      return;
    }
    memoriser(
      id: json['id'] as String?,
      email: json['email'] as String?,
      estAdmin: json['is_admin'] as bool? ?? false,
    );
  }

  /// Vide le cache. A appeler a la deconnexion.
  static void effacer() {
    _id = null;
    _email = null;
    _estAdmin = false;
  }

  // =============================================================
  // GETTERS
  // =============================================================
  // Chacun choisit sa source selon le mode :
  //   fastapi  -> le cache ci-dessus
  //   supabase -> le SDK, qui reste la source de verite
  //
  // Le fait de ne toucher `supabase` que dans la branche supabase est
  // essentiel : en mode fastapi ce getter leve une StateError, et il
  // ne doit donc jamais etre evalue.
  // =============================================================

  /// UUID de l'utilisateur connecte, ou null si personne ne l'est.
  static String? get id {
    if (ApiConfig.isFastApi) return _id;
    return supabase.auth.currentUser?.id;
  }

  /// Adresse email de l'utilisateur connecte, ou null.
  static String? get email {
    if (ApiConfig.isFastApi) return _email;
    return supabase.auth.currentUser?.email;
  }

  /// Vrai si l'utilisateur connecte dispose des droits d'administration.
  ///
  /// En mode fastapi la reponse fait autorite : elle vient du champ
  /// `is_admin` renvoye par le backend, qui la tient de la base.
  /// En mode supabase, il n'existait pas de tel champ cote client :
  /// la comparaison a une adresse en dur reste le seul critere
  /// disponible, et elle est laissee a l'appelant.
  static bool get estAdmin => _estAdmin;

  /// Vrai si une identite est connue.
  static bool get estConnecte => id != null;
}
