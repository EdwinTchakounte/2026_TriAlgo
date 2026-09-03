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
// DEUX AXES A NE PAS CONFONDRE : `depth` ET `distance`
// ----------------------------------------------------
// L'API renvoie le `depth` du noeud : sa POSITION dans sa chaine,
// de 1 a 5. Le jeu, lui, raisonne en `distance` : la DIFFICULTE du
// trio a trouver. D1 = un trio direct (les trois cartes d'une meme
// fusion), D2 = un trio tire d'une chaine de 2 noeuds, etc.
//
// Ce sont deux choses differentes, et ce fichier les a longtemps
// confondues en recopiant `depth` dans `distance`.
//
// Le mode collectif par numero designe TOUJOURS un trio natif : un
// animateur annonce un node_index, et les joueurs cherchent les
// trois cartes de cette fusion. Peu importe que ce noeud soit le
// troisieme d'une chaine -- ses trois cartes sont sous les yeux,
// c'est une fusion directe. Sa distance est donc 1, toujours.
//
// LE DEFAUT QUE CELA CORRIGE
// --------------------------
// Le generateur local range tous les noeuds natifs dans la table D1
// avec `distance: 1` (cf. generate_logical_nodes_usecase). Tant que
// ce fichier recopiait `depth`, le MEME trio recevait deux reponses
// differentes selon l'etat du reseau :
//
//     noeud 25 (depth 2), serveur joignable   -> « Trio D2 valide »
//     noeud 25 (depth 2), serveur injoignable -> « Trio D1 valide »
//
// Et le trackingKey divergeait avec (D2#N25 contre D1#N25), donc les
// cles persistees dans played-nodes se dedoublaient. Sur un jeu de
// 2 noeuds le cas ne se presentait pas ; sur les 46 trios du
// referentiel, 22 sont a depth 2 ou 3 -- pres de la moitie.
//
// La profondeur ne sert donc plus a refuser quoi que ce soit : un
// noeud natif est jouable en collectif quelle que soit sa place
// dans la chaine. Le serveur reste l'autorite sur l'EXISTENCE, le
// client sur les REGLES DU JEU -- il se trouve simplement qu'ici la
// regle ne depend pas de la profondeur.
// =============================================================

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/data/datasources/http/http_collective_datasource.dart';
import 'package:trialgo/domain/entities/verify_trio_result.dart';

/// Distance d'un trio natif : toujours 1.
///
/// Le mode collectif par numero designe un noeud du graphe, donc
/// une fusion directe : ses trois cartes sont sous les yeux du
/// joueur. Sa profondeur dans la chaine ne change pas la
/// difficulte du trio, et ne doit donc pas apparaitre ici.
///
/// Doit rester aligne sur le `distance: 1` que
/// GenerateLogicalNodesUseCase pose sur la table D1.
const int kDistanceTrioNatif = 1;

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
  //   VerifyTrioResult  le serveur a tranche (trio valide, ou trio
  //                     inexistant pour ce jeu)
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
      // Toujours 1 : un trio natif est une fusion DIRECTE, quelle
      // que soit la place de son noeud dans la chaine. C'est aussi
      // ce que renvoie le chemin local, et les deux doivent dire la
      // meme chose (cf. le bandeau de ce fichier).
      distance: kDistanceTrioNatif,
      cardLabels: labels,
      // Le serveur ne renvoie pas la chaine de noeuds traversee, il
      // ne connait que le noeud interroge. On expose donc ce seul
      // index plutot qu'une chaine inventee.
      sourceNodeIndices: [index],
      // Exactement la cle que le generateur local produit pour ce
      // meme noeud ('D1#N12'). Sans cette egalite, le suivi des
      // trios deja joues compterait deux fois le meme trio selon
      // que le serveur ait repondu ou non.
      trackingKey: 'D$kDistanceTrioNatif#N$index',
    );
  }
}
