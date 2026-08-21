// =============================================================
// FICHIER : lib/core/constants/admin_constants.dart
// ROLE   : Constantes pour l'administration du jeu
// COUCHE : Core > Constants
// =============================================================
//
// Centralise l'email admin et les fonctions de verification.
// Un seul endroit a modifier si l'email admin change.
// =============================================================

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/core/session/session_utilisateur.dart';

/// Constantes et utilitaires pour l'administration.
class AdminConstants {

  // =============================================================
  // EMAIL ADMIN
  // =============================================================
  // L'email du compte administrateur. Seul cet email a acces
  // a l'interface d'administration des cartes et noeuds.
  //
  // Cote Supabase, les politiques RLS verifient aussi cet email
  // pour autoriser les operations d'ecriture sur cards et nodes.
  // =============================================================

  /// Email du compte administrateur.
  static const String adminEmail = 'admin@trialgo.com';

  // =============================================================
  // METHODE : isAdmin
  // =============================================================
  // Verifie si l'utilisateur actuellement connecte est l'admin.
  //
  // Compare l'email de la session courante avec adminEmail.
  // Retourne false si :
  //   - Aucun utilisateur connecte (currentUser == null)
  //   - L'email ne correspond pas
  //
  // Utilise par l'interface Flutter pour :
  //   - Afficher ou masquer le bouton "Administration" sur la home
  //   - Proteger la navigation vers les pages admin
  //
  // SECURITE : cette verification est cote CLIENT.
  // Elle decide de l'AFFICHAGE d'un bouton, rien de plus. Les droits
  // reels sont verifies par le backend a chaque requete :
  //   - fastapi  : dependance get_current_admin -> 403 sinon
  //   - supabase : politiques RLS de PostgreSQL
  // Un utilisateur qui contournerait ce test n'obtiendrait donc que
  // des refus. C'est un confort UX, pas une barriere.
  //
  // LE CRITERE DEPEND DU BACKEND ACTIF
  // ----------------------------------
  // L'information disponible n'est pas la meme des deux cotes :
  //
  //   fastapi  : le backend expose un vrai champ `is_admin`, tenu en
  //              base et renvoye par /api/auth/me. C'est une donnee
  //              d'autorite, pas une heuristique. SessionUtilisateur
  //              la met en cache a l'ouverture de session.
  //
  //   supabase : aucun champ equivalent cote client, d'ou la
  //              comparaison de l'email a une adresse en dur -- ce que
  //              faisait l'app auparavant, conserve tel quel.
  // =============================================================

  /// Retourne `true` si l'utilisateur connecte doit voir l'entree admin.
  static bool isAdmin() {
    if (ApiConfig.isFastApi) {
      // Champ is_admin renvoye par le backend, mis en cache a la
      // connexion. Pas d'appel reseau ici : la methode est appelee
      // depuis un build().
      return SessionUtilisateur.estAdmin;
    }

    // Mode supabase : comparaison a l'email admin en dur.
    // SessionUtilisateur.email delegue au SDK dans ce mode.
    return SessionUtilisateur.email == adminEmail;
  }
}
