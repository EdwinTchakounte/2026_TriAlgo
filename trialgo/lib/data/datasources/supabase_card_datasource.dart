// =============================================================
// FICHIER : lib/data/datasources/supabase_card_datasource.dart
// ROLE   : Appels bruts a la table "cards" de Supabase
// COUCHE : Data > Datasources
// =============================================================
//
// Ce fichier est volontairement SIMPLE.
// Les operations sur la table "cards" sont deja implementees
// directement dans CardRepositoryImpl pour eviter une couche
// d'abstraction inutile (la datasource serait un simple passe-plat).
//
// Ce fichier existe pour la coherence de l'architecture et
// pourrait etre utilise si on ajoute des operations complexes
// (cache local, pre-chargement, batch operations, etc.).
//
// Pour l'instant, il sert de point d'entree pour les operations
// de signalement d'images cassees (broken_image_reports).
//
// REFERENCE : Recueil de conception v3.0, section 17.3
// =============================================================

import 'package:trialgo/core/network/supabase_client.dart';

/// Datasource pour les operations secondaires sur les cartes.
///
/// Les operations principales (CRUD cartes) sont dans [CardRepositoryImpl].
/// Cette datasource gere les operations auxiliaires comme le
/// signalement d'images cassees.
class SupabaseCardDatasource {

  // =============================================================
  // METHODE : reportBrokenImage
  // =============================================================
  // Quand une image ne charge pas (404, corruption, etc.),
  // le client Flutter envoie un rapport au backend.
  //
  // Ce rapport est NON-BLOQUANT : si l'envoi echoue, le jeu continue.
  // Un administrateur pourra consulter les rapports et corriger.
  //
  // SQL : INSERT INTO broken_image_reports (card_id, image_url, error_msg, reported_by)
  //       VALUES (...)
  //
  // REFERENCE : Recueil de conception v3.0, section 17.3
  // =============================================================

  /// Signale une image cassee ou introuvable.
  ///
  /// [cardId]  : UUID de la carte dont l'image est cassee.
  /// [url]     : URL complete de l'image qui a echoue.
  /// [error]   : message d'erreur du chargement.
  ///
  /// Cette methode est SILENCIEUSE : elle ne leve jamais d'exception.
  /// Si le signalement echoue (pas de reseau), on l'ignore.
  /// Le jeu ne doit JAMAIS etre bloque par un rapport d'erreur.
  Future<void> reportBrokenImage({
    required String cardId,
    required String url,
    required String error,
  }) async {
    // "try/catch(_)" : attrape TOUTES les exceptions.
    // "(_)" : on ne nomme pas l'exception car on ne l'utilise pas.
    // Le corps du catch est VIDE : on ignore l'erreur volontairement.
    //
    // C'est un cas RARE ou ignorer une erreur est acceptable :
    // le signalement est un "nice to have", pas une fonctionnalite critique.
    try {
      await supabase.from('broken_image_reports').insert({
        'card_id': cardId,
        'image_url': url,
        'error_msg': error,
        // 'reported_by' est rempli automatiquement par la politique RLS
        // qui utilise auth.uid() comme valeur.
        'reported_by': supabase.auth.currentUser?.id,
      });
    } catch (_) {
      // Silencieux : ne jamais bloquer le jeu pour un rapport.
    }
  }
}
