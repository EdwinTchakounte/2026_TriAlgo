// =============================================================
// FICHIER : lib/data/repositories/card_trio_repository_impl.dart
// ROLE   : Implementation CONCRETE du CardTrioRepository avec Supabase
// COUCHE : Data > Repositories
// =============================================================
//
// Implemente les 3 methodes de CardTrioRepository :
//   1. getRandomTrio  -> un trio aleatoire pour une question
//   2. isCoherent     -> verifier si un trio est valide
//   3. getTriosByDistance -> tous les trios d'une distance
//
// REFERENCE : Recueil de conception v3.0, sections 3.3 et 4.5
// =============================================================

import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/domain/entities/card_trio_entity.dart';
import 'package:trialgo/domain/repositories/card_trio_repository.dart';
import 'package:trialgo/data/models/card_trio_model.dart';

/// Implementation de [CardTrioRepository] utilisant Supabase.
///
/// Interroge la table `card_trios` pour recuperer et valider
/// les combinaisons de cartes.
class CardTrioRepositoryImpl implements CardTrioRepository {

  // =============================================================
  // METHODE : getRandomTrio
  // =============================================================
  // Recupere un trio aleatoire pour generer une question de jeu.
  //
  // La difficulte principale est de choisir AU HASARD parmi
  // les trios disponibles, en excluant ceux deja utilises.
  //
  // Supabase ne supporte pas "ORDER BY RANDOM()" directement
  // dans son SDK Flutter. On utilise donc une RPC (Remote Procedure Call)
  // ou on charge plusieurs trios et on en choisit un au hasard cote client.
  //
  // Approche choisie : charger quelques trios et en prendre un au hasard.
  // C'est plus simple qu'une RPC et suffisant pour le volume de donnees.
  // =============================================================

  /// Recupere un trio aleatoire d'une [distance] donnee.
  ///
  /// [excludeIds] : IDs de trios a exclure (deja poses dans la session).
  @override
  Future<CardTrioEntity> getRandomTrio({
    required int distance,
    List<String> excludeIds = const [],
  }) async {
    // Construction de la requete de base :
    //   SELECT * FROM card_trios WHERE distance_level = $distance
    //
    // "var" au lieu de "final" car on va potentiellement modifier
    // la requete avec des filtres supplementaires.
    //
    // ATTENTION : "var query = supabase.from(...).select()..."
    // ne lance PAS la requete immediatement. Elle construit un
    // objet "builder" qui sera execute quand on fera "await".
    // C'est le pattern BUILDER : on configure d'abord, on execute ensuite.
    var query = supabase
        .from('card_trios')
        .select()
        .eq('distance_level', distance);

    // --- Exclure les trios deja utilises ---
    // Si la liste d'exclusion n'est pas vide, on ajoute un filtre.
    //
    // ".not('id', 'in', excludeIds)" : filtre NOT IN
    //   -> Equivalent SQL : WHERE id NOT IN ('uuid1', 'uuid2', ...)
    //   -> Exclut les trios dont l'ID est dans la liste
    //
    // "isNotEmpty" : verifie que la liste contient au moins un element.
    //   Si la liste est vide, le filtre NOT IN serait invalide.
    if (excludeIds.isNotEmpty) {
      // On convertit la liste en format attendu par Supabase :
      // "(uuid1,uuid2,uuid3)"
      query = query.not('id', 'in', excludeIds);
    }

    // --- Limiter et executer ---
    // ".limit(10)" : on ne charge que 10 trios (pas toute la table).
    //   C'est suffisant pour en choisir un au hasard.
    //   Charger toute la table serait un gaspillage de bande passante.
    //
    // "await" : execute la requete et attend la reponse.
    final data = await query.limit(10);

    // --- Verification : au moins un trio disponible ---
    // "data" est une List<Map<String, dynamic>>.
    // Si la liste est vide, il n'y a aucun trio pour cette distance
    // (ou tous ont ete exclus). On leve une exception.
    //
    // "isEmpty" : propriete des List, true si la liste n'a aucun element.
    //
    // "throw Exception(...)" : leve une exception generique.
    // Dans un vrai projet, on utiliserait CardFailure.noTrioAvailable().
    if (data.isEmpty) {
      throw Exception('Aucun trio disponible pour la distance $distance');
    }

    // --- Choisir un trio au hasard ---
    // "data.length" : nombre de trios retournes (1 a 10).
    //
    // "DateTime.now().millisecondsSinceEpoch" : nombre de millisecondes
    //   depuis le 1er janvier 1970. Change a chaque milliseconde.
    //   Utilise comme SEED (graine) pour le generateur aleatoire.
    //
    // "% data.length" : operateur MODULO
    //   Retourne le reste de la division entiere.
    //   Exemple : 1728493827123 % 7 = 4 -> on prend l'element 4
    //   Garantit un index entre 0 et data.length - 1.
    //
    // Alternative plus propre : Random().nextInt(data.length)
    // On utilise le modulo ici car c'est plus leger qu'importer dart:math.
    final randomIndex = DateTime.now().millisecondsSinceEpoch % data.length;

    // "data[randomIndex]" : accede au Map a l'index aleatoire.
    // "CardTrioModel.fromJson(...)" : convertit en objet Dart.
    return CardTrioModel.fromJson(data[randomIndex]);
  }

  // =============================================================
  // METHODE : isCoherent
  // =============================================================
  // Verifie si un trio (E, C, R) existe dans la table card_trios.
  //
  // C'est LA verification qui determine si la reponse du joueur
  // est correcte ou non.
  //
  // SQL equivalent :
  //   SELECT EXISTS (
  //     SELECT 1 FROM card_trios
  //     WHERE emettrice_id = $emettriceId
  //       AND cable_id = $cableId
  //       AND receptrice_id = $receptriceId
  //   )
  //
  // Note : dans le jeu final, cette verification se fait cote serveur
  // (Edge Function validate-answer). Cette methode est un apercu client.
  // =============================================================

  /// Verifie si le trio (E, C, R) existe dans `card_trios`.
  ///
  /// Retourne `true` si la combinaison est valide, `false` sinon.
  @override
  Future<bool> isCoherent({
    required String emettriceId,
    required String cableId,
    required String receptriceId,
  }) async {
    // On fait un SELECT avec les 3 filtres d'egalite.
    // Si le trio existe, on obtient 1 resultat.
    // Si non, on obtient 0 resultats.
    final data = await supabase
        .from('card_trios')
        .select('id')               // On ne charge que l'ID (plus leger)
        .eq('emettrice_id', emettriceId)   // WHERE emettrice_id = ...
        .eq('cable_id', cableId)           // AND cable_id = ...
        .eq('receptrice_id', receptriceId); // AND receptrice_id = ...

    // "data" est une List<Map<String, dynamic>>.
    // "isNotEmpty" retourne true s'il y a au moins 1 resultat.
    //   -> true  = le trio existe = bonne reponse
    //   -> false = le trio n'existe pas = mauvaise reponse
    return data.isNotEmpty;
  }

  // =============================================================
  // METHODE : getTriosByDistance
  // =============================================================
  // Recupere TOUS les trios d'une distance.
  //
  // SQL : SELECT * FROM card_trios WHERE distance_level = $distance
  // =============================================================

  /// Recupere tous les trios d'une [distance] donnee.
  @override
  Future<List<CardTrioEntity>> getTriosByDistance(int distance) async {
    final data = await supabase
        .from('card_trios')
        .select()
        .eq('distance_level', distance);

    // Convertit chaque Map JSON en CardTrioModel.
    return data.map((json) => CardTrioModel.fromJson(json)).toList();
  }
}
