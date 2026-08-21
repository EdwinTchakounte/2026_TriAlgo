// =============================================================
// FICHIER : lib/data/services/collective_verifier.dart
// ROLE   : Verification serveur d'un trio annonce (mode collectif)
// COUCHE : Data > Services
// =============================================================
//
// LE PROBLEME QUE CE FICHIER RESOUT
// ---------------------------------
// L'endpoint POST /api/games/{gid}/verify-collective existait, avec
// sa datasource Dart deja ecrite et testable... et aucun appelant.
// Le mode collectif se contentait du graphe charge en memoire.
//
// Ca marche tant que le joueur vient de synchroniser. Mais en
// seance, l'animateur annonce des numeros a voix haute et le joueur
// n'a pas forcement resynchronise depuis que l'administrateur a
// ajoute des trios : l'app repondait alors "trio inexistant" sur un
// trio parfaitement valide, sans aucun moyen de s'en apercevoir.
//
// CE QUE FAIT CE SERVICE
// ----------------------
// Il traduit la reponse HTTP en VerifyTrioResult, le type que l'UI
// du mode collectif sait deja afficher. Il applique au passage la
// regle metier que le serveur ne connait pas.
//
// LA REGLE QUE LE SERVEUR NE CONNAIT PAS
// --------------------------------------
// verify-collective renvoie n'importe quel noeud du jeu, quelle que
// soit sa profondeur. Or le mode collectif s'arrete a D3 (cf. le
// bandeau de VerifyTrioCardsUseCase). C'est donc ici qu'on rejette
// un trio trop profond, en s'appuyant sur le champ 'depth' renvoye
// par l'API. Le serveur reste l'autorite sur l'EXISTENCE, le client
// reste l'autorite sur les REGLES DU JEU.
// =============================================================

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/data/datasources/http/http_collective_datasource.dart';
import 'package:trialgo/domain/entities/verify_trio_result.dart';

/// Profondeur maximale acceptee en mode collectif.
///
/// Au-dela, le trio existe bien dans le jeu mais n'est pas jouable
/// dans ce mode. Doit rester coherent avec la liste [1, 2, 3]
/// parcourue par VerifyTrioCardsUseCase.verifyByCardIds.
const int kProfondeurMaxCollectif = 3;

/// Verifie un trio aupres du backend pour le mode collectif.
class CollectiveVerifier {

  /// Datasource HTTP (injectable pour les tests).
  final HttpCollectiveDatasource _datasource;

  /// Cree le verificateur. Sans argument, utilise le Dio global.
  CollectiveVerifier({HttpCollectiveDatasource? datasource})
      : _datasource = datasource ?? HttpCollectiveDatasource();

  // =============================================================
  // METHODE : verifier
  // =============================================================
  // Interroge le serveur sur un node_index.
  //
  // VALEURS DE RETOUR, ET POURQUOI TROIS CAS
  // ----------------------------------------
  //   VerifyTrioResult  le serveur a tranche (trio valide, trio
  //                     inexistant, ou trio trop profond)
  //   null              on n'a pas pu demander : mode Supabase, ou
  //                     aucun jeu charge. L'appelant bascule alors
  //                     en verification locale.
  //   exception         panne reseau. Volontairement PROPAGEE :
  //                     c'est VerifyTrioCardsUseCase qui decide de
  //                     retomber en local, pas nous. Avaler l'erreur
  //                     ici reviendrait a renvoyer null, donc a
  //                     confondre "pas de reseau" et "pas
  //                     applicable" -- deux situations differentes.
  // =============================================================

  /// Verifie [nodeIndex] pour [gameId] aupres du serveur.
  Future<VerifyTrioResult?> verifier({
    required String? gameId,
    required int nodeIndex,
  }) async {
    // Pas applicable : on laisse la main au chemin local.
    if (!ApiConfig.isFastApi) return null;
    if (gameId == null || gameId.isEmpty) return null;

    final reponse = await _datasource.verifyTrio(
      gameId: gameId,
      nodeIndex: nodeIndex,
    );

    // ---- Le serveur dit que le trio n'existe pas ----
    // Il fournit son propre message ('Trio inexistant pour ce jeu',
    // 'Noeud incoherent', 'Parent introuvable') : on le reprend tel
    // quel plutot que d'en inventer un moins precis.
    final existe = reponse['exists'] == true;
    if (!existe) {
      final message = reponse['message'] as String?;
      return VerifyTrioResult.invalid(
        message ?? 'Trio inexistant pour ce jeu',
      );
    }

    // ---- Le trio existe : reste a verifier qu'il est jouable ici ----
    final profondeur = reponse['depth'] as int?;
    if (profondeur == null) {
      // Reponse incomplete : on prefere ne pas trancher et laisser
      // le graphe local repondre.
      return null;
    }
    if (profondeur > kProfondeurMaxCollectif) {
      return VerifyTrioResult.invalid(
        'Trio hors mode collectif (D > $kProfondeurMaxCollectif)',
      );
    }

    // ---- Trio valide : on assemble le resultat ----
    // Les libelles arrivent dans l'ordre metier E, C, R. C'est aussi
    // l'ordre cardA/cardB/cardC d'un noeud logique D1, donc l'UI
    // affiche la meme chose que par le chemin local.
    final labels = <String>[
      (reponse['emettrice_label'] as String?) ?? '?',
      (reponse['cable_label'] as String?) ?? '?',
      (reponse['receptrice_label'] as String?) ?? '?',
    ];

    final index = (reponse['node_index'] as int?) ?? nodeIndex;

    return VerifyTrioResult.success(
      distance: profondeur,
      cardLabels: labels,
      // Le serveur ne renvoie pas la chaine de noeuds traversee, il
      // ne connait que le noeud interroge. On expose donc ce seul
      // index plutot qu'une chaine inventee.
      sourceNodeIndices: [index],
      // Meme convention de nommage que le generateur local
      // (cf. generate_logical_nodes_usecase : 'D1#N12'), pour que
      // les cles restent lisibles quelle que soit leur provenance.
      trackingKey: 'D$profondeur#N$index',
    );
  }
}
