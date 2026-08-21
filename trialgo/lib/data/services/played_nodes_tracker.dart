// =============================================================
// FICHIER : lib/data/services/played_nodes_tracker.dart
// ROLE   : Persister les questions deja jouees cote serveur
// COUCHE : Data > Services
// =============================================================
//
// LE PROBLEME QUE CE FICHIER RESOUT
// ---------------------------------
// GenerateGameQuestionUseCase evite de reposer deux fois la meme
// question grace a un Set de trackingKeys. Ce Set vivait dans la
// memoire du processus : il repartait vide a chaque lancement de
// l'application. Un joueur qui fermait puis rouvrait TRIALGO
// retombait sur les trios qu'il venait de voir.
//
// Le backend, lui, etait pret depuis le debut : la table
// user_played_nodes et les trois endpoints /api/me/played-nodes
// existent et sont testes. Personne ne les appelait. Ce service
// est le fil manquant entre les deux.
//
// LES TROIS OPERATIONS
// --------------------
//   chargerClesJouees(gameId)  GET    -> amorce le Set au demarrage
//   marquerJoue(gameId, key)   POST   -> enregistre, en tache de fond
//   reinitialiser(gameId)      DELETE -> "je veux tout rejouer"
//
// POURQUOI LES ERREURS SONT AVALEES
// ---------------------------------
// Le tracking anti-doublon est un CONFORT, pas une regle du jeu.
// Un joueur dans le metro sans reseau doit pouvoir jouer : il
// reverra peut-etre un trio deja vu, ce qui est sans gravite. Une
// exception qui remonterait jusqu'a l'UI, elle, casserait la
// partie. Toute panne reseau degrade donc silencieusement vers le
// comportement historique (tracking memoire seul).
//
// MODE SUPABASE
// -------------
// Aucun equivalent n'existe cote Supabase. En mode 'supabase' les
// methodes sont des no-op : on retombe sur le tracking memoire,
// exactement comme avant. Le repli reste donc fonctionnel.
// =============================================================

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/data/datasources/http/http_played_nodes_datasource.dart';

/// Passerelle entre le tracking en memoire et /api/me/played-nodes.
class PlayedNodesTracker {

  /// Datasource HTTP (injectable pour les tests).
  final HttpPlayedNodesDatasource _datasource;

  /// Cree le tracker. Sans argument, il utilise le client Dio global.
  PlayedNodesTracker({HttpPlayedNodesDatasource? datasource})
      : _datasource = datasource ?? HttpPlayedNodesDatasource();

  // =============================================================
  // METHODE : chargerClesJouees
  // =============================================================
  // Relit l'historique du joueur pour un jeu donne.
  //
  // Appelee une seule fois, juste apres syncAndBuild, par la page
  // de chargement du graphe. Le resultat sert a amorcer le Set du
  // usecase via seedPlayedKeys.
  //
  // Retourne un ensemble vide (jamais null, jamais d'exception) en
  // mode Supabase, hors ligne, ou si le serveur repond mal.
  // =============================================================

  /// Relit les trackingKeys deja jouees par ce joueur sur [gameId].
  Future<Set<String>> chargerClesJouees(String gameId) async {
    if (!ApiConfig.isFastApi) return <String>{};

    try {
      final lignes = await _datasource.listPlayedKeys(gameId: gameId);

      // Chaque ligne est un PlayedNodeOut. Seule tracking_key nous
      // interesse : le client compare en local, il n'a que faire de
      // l'id de la ligne ni de sa date.
      return lignes
          .map((ligne) => ligne['tracking_key'] as String?)
          .whereType<String>()
          .toSet();
    } catch (_) {
      // Hors ligne ou serveur muet : on repart sur un tracking
      // purement memoire. Le joueur peut jouer, c'est l'essentiel.
      return <String>{};
    }
  }

  // =============================================================
  // METHODE : marquerJoue
  // =============================================================
  // Enregistre une trackingKey comme jouee.
  //
  // VOLONTAIREMENT "FIRE AND FORGET"
  // --------------------------------
  // Cette methode est appelee depuis GenerateGameQuestionUseCase,
  // en plein milieu de la construction d'une question, dans un
  // chemin de code SYNCHRONE. Attendre le reseau ici ferait piquer
  // l'affichage a chaque nouvelle question.
  //
  // On lance donc la requete sans l'attendre. Le POST est idempotent
  // cote serveur (contrainte UNIQUE + ON CONFLICT), donc un double
  // envoi est sans consequence, et une requete perdue coute au pire
  // un trio revu plus tard.
  // =============================================================

  /// Enregistre [trackingKey] comme jouee sur [gameId], sans attendre.
  void marquerJoue({required String gameId, required String trackingKey}) {
    if (!ApiConfig.isFastApi) return;

    // ignore: unawaited_futures
    _datasource
        .markPlayed(gameId: gameId, trackingKey: trackingKey)
        .catchError((Object _) {
      // Echec silencieux : voir le bandeau de ce fichier.
      // On renvoie une Map vide pour satisfaire le type de retour.
      return <String, dynamic>{};
    });
  }

  // =============================================================
  // METHODE : reinitialiser
  // =============================================================
  // Efface l'historique des trios joues pour un jeu.
  //
  // Contrairement aux deux autres, celle-ci PROPAGE ses erreurs :
  // elle est declenchee par un geste explicite de l'utilisateur
  // ("rejouer depuis le debut"), qui doit savoir si ca a marche.
  //
  // Sans effet sur les scores ni sur l'historique des sessions :
  // seule la table user_played_nodes est videe.
  // =============================================================

  /// Efface l'historique des trios joues sur [gameId].
  Future<void> reinitialiser(String gameId) async {
    if (!ApiConfig.isFastApi) return;
    await _datasource.resetPlayed(gameId: gameId);
  }
}
