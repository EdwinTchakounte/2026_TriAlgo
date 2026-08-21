// =============================================================
// FICHIER : test/liens_et_mode_collectif_test.dart
// ROLE   : Verrouiller deux flux qui ne partaient jamais au reseau
// =============================================================
//
// DEUX BUGS, DEUX FAMILLES DE TESTS
// ---------------------------------
// 1. DeepLinkService n'acceptait un lien https que si son hote
//    contenait la chaine 'trialgo'. En production le backend
//    fabrique ses liens depuis APP_FRONTEND_URL, qui vaut
//    'https://dashboard.mixalgo.com' : le lien de reinitialisation
//    de mot de passe etait donc ignore en silence, sans erreur,
//    sans log, sans rien. Le joueur restait bloque.
//
// 2. Le mode collectif verifiait les trios uniquement contre le
//    graphe charge en memoire, alors que l'endpoint serveur
//    existait. CollectiveVerifier traduit desormais la reponse
//    HTTP, en appliquant la seule regle que le serveur ignore :
//    le mode collectif s'arrete a la profondeur 3.
// =============================================================

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/data/datasources/http/http_collective_datasource.dart';
import 'package:trialgo/data/services/collective_verifier.dart';
import 'package:trialgo/data/services/deep_link_service.dart';

void main() {
  // ===========================================================
  // GROUPE 1 : hotes acceptes par le deep-link
  // ===========================================================
  group('Deep-link : hotes acceptes', () {
    test('le domaine de production est accepte', () {
      // ApiConfig.baseUrl pointe sur api.mixalgo.com en release, donc
      // tout le domaine mixalgo.com doit ouvrir l'app. C'est le cas
      // exact qui etait rejete avant.
      expect(DeepLinkService.hoteAccepte('dashboard.mixalgo.com'), isTrue);
      expect(DeepLinkService.hoteAccepte('mixalgo.com'), isTrue);
      expect(DeepLinkService.hoteAccepte('api.mixalgo.com'), isTrue);
    });

    test('la casse ne change rien', () {
      expect(DeepLinkService.hoteAccepte('DashBoard.MixAlgo.COM'), isTrue);
    });

    test('les liens historiques trialgo restent acceptes', () {
      expect(DeepLinkService.hoteAccepte('app.trialgo.io'), isTrue);
    });

    test('un domaine tiers est refuse', () {
      expect(DeepLinkService.hoteAccepte('exemple.com'), isFalse);
      expect(DeepLinkService.hoteAccepte('evil.net'), isFalse);
    });

    test('un domaine qui imite le notre est refuse', () {
      // Le piege classique d'un endsWith mal ecrit : un attaquant
      // enregistre 'notmixalgo.com' et recupere le token de reset.
      expect(DeepLinkService.hoteAccepte('notmixalgo.com'), isFalse);
      expect(DeepLinkService.hoteAccepte('mixalgo.com.evil.net'), isFalse);
    });
  });

  // ===========================================================
  // GROUPE 2 : traduction de la reponse verify-collective
  // ===========================================================
  group('Mode collectif : reponse serveur', () {
    // Garde-fou : ces tests n'ont de sens qu'en mode fastapi, sinon
    // CollectiveVerifier renvoie null par conception.
    test('le mode actif est bien fastapi', () {
      expect(ApiConfig.isFastApi, isTrue);
    });

    test('un trio existant devient un resultat valide', () async {
      final verifier = CollectiveVerifier(
        datasource: _FauxCollectiveDatasource({
          'exists': true,
          'node_index': 12,
          'depth': 1,
          'emettrice_label': 'Lion',
          'cable_label': 'Miroir',
          'receptrice_label': 'Reflet',
        }),
      );

      final r = await verifier.verifier(gameId: 'jeu-1', nodeIndex: 12);

      expect(r, isNotNull);
      expect(r!.valid, isTrue);
      expect(r.distance, 1);
      // L'ordre metier E, C, R doit etre preserve tel quel.
      expect(r.cardLabels, ['Lion', 'Miroir', 'Reflet']);
      expect(r.sourceNodeIndices, [12]);
      expect(r.trackingKey, 'D1#N12');
    });

    test('un trio inexistant reprend le message du serveur', () async {
      final verifier = CollectiveVerifier(
        datasource: _FauxCollectiveDatasource({
          'exists': false,
          'message': 'Trio inexistant pour ce jeu',
        }),
      );

      final r = await verifier.verifier(gameId: 'jeu-1', nodeIndex: 999);

      expect(r, isNotNull);
      expect(r!.valid, isFalse);
      expect(r.errorMessage, 'Trio inexistant pour ce jeu');
    });

    test('un trio trop profond est refuse par le client', () async {
      // Le serveur ne connait pas la limite du mode collectif : il
      // renvoie exists=true pour un D4. C'est le client qui tranche.
      final verifier = CollectiveVerifier(
        datasource: _FauxCollectiveDatasource({
          'exists': true,
          'node_index': 40,
          'depth': 4,
          'emettrice_label': 'A',
          'cable_label': 'B',
          'receptrice_label': 'C',
        }),
      );

      final r = await verifier.verifier(gameId: 'jeu-1', nodeIndex: 40);

      expect(r, isNotNull);
      expect(r!.valid, isFalse);
      expect(r.errorMessage, contains('hors mode collectif'));
    });

    test('sans jeu charge, on ne tranche pas', () async {
      // null = "je ne peux pas repondre", ce qui fait basculer le
      // usecase sur la verification locale.
      final verifier = CollectiveVerifier(
        datasource: _FauxCollectiveDatasource(const {}),
      );

      expect(await verifier.verifier(gameId: null, nodeIndex: 1), isNull);
      expect(await verifier.verifier(gameId: '', nodeIndex: 1), isNull);
    });

    test('une panne reseau est propagee, pas avalee', () async {
      // Distinguer "pas de reseau" de "pas applicable" est essentiel :
      // c'est le usecase qui doit decider de retomber en local.
      final verifier = CollectiveVerifier(
        datasource: _FauxCollectiveDatasourceEnPanne(),
      );

      expect(
        () => verifier.verifier(gameId: 'jeu-1', nodeIndex: 1),
        throwsA(isA<Exception>()),
      );
    });
  });
}

// =============================================================
// FAUX DATASOURCES
// =============================================================
// On etend la vraie classe et on remplace le seul appel reseau.
// Le Dio passe au super n'est jamais utilise, mais il evite de
// toucher au singleton DioClient global depuis un test.
// =============================================================

/// Renvoie toujours la meme charge utile.
class _FauxCollectiveDatasource extends HttpCollectiveDatasource {
  _FauxCollectiveDatasource(this.reponse) : super(dio: Dio());

  final Map<String, dynamic> reponse;

  @override
  Future<Map<String, dynamic>> verifyTrio({
    required String gameId,
    required int nodeIndex,
  }) async =>
      reponse;
}

/// Simule une coupure reseau.
class _FauxCollectiveDatasourceEnPanne extends HttpCollectiveDatasource {
  _FauxCollectiveDatasourceEnPanne() : super(dio: Dio());

  @override
  Future<Map<String, dynamic>> verifyTrio({
    required String gameId,
    required int nodeIndex,
  }) async =>
      throw Exception('reseau indisponible');
}
