// =============================================================
// FICHIER : lib/core/constants/admin_constants.dart
// ROLE   : Constantes pour l'administration du jeu
// COUCHE : Core > Constants
// =============================================================
//
// Centralise l'email admin et les fonctions de verification.
// Un seul endroit a modifier si l'email admin change.
// =============================================================

import 'package:trialgo/core/network/supabase_client.dart';

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
  // Meme si un utilisateur malveillant contourne cette verification,
  // les politiques RLS de Supabase bloquent les ecritures en BDD.
  // La verification client est un confort UX, pas une securite.
  // =============================================================

  /// Retourne `true` si l'utilisateur connecte est l'admin.
  ///
  /// Verifie l'email de la session Supabase courante.
  /// Retourne `false` si aucun utilisateur connecte ou email different.
  static bool isAdmin() {
    // "supabase.auth.currentUser" : l'utilisateur connecte ou null.
    // "?.email" : l'email de l'utilisateur, ou null si pas connecte.
    // Le "?" evite un crash si currentUser est null (null-safe access).
    final email = supabase.auth.currentUser?.email;

    // Compare l'email avec l'email admin.
    // Retourne false si email est null (pas connecte).
    return email == adminEmail;
  }
}
