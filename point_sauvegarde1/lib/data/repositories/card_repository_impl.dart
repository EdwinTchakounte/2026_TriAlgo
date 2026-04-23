// =============================================================
// FICHIER : lib/data/repositories/card_repository_impl.dart
// ROLE   : Implementation CONCRETE du CardRepository avec Supabase
// COUCHE : Data > Repositories
// =============================================================
//
// QU'EST-CE QU'UNE IMPLEMENTATION ?
// ---------------------------------
// Dans le chapitre precedent, on a cree l'INTERFACE CardRepository
// (couche Domain) qui dit QUOI faire, sans dire COMMENT.
//
// Ici, on cree l'IMPLEMENTATION qui dit COMMENT le faire :
//   - En utilisant le SDK Supabase
//   - En faisant des requetes SQL via l'API REST
//   - En convertissant les resultats JSON en CardModel
//
// "implements" vs "extends" :
//   - "extends" (heritage) : on herite du code de la classe parente.
//     La sous-classe reutilise le code existant.
//   - "implements" (implementation) : on s'engage a FOURNIR toutes
//     les methodes de l'interface. Pas de code herite, tout est ecrit.
//
// On utilise "implements" car CardRepository est une interface pure
// (abstract class sans code). On ne reutilise rien, on fournit tout.
//
// REFERENCE : Recueil de conception v3.0, section 9
// =============================================================

// Import du client Supabase pour faire les requetes.
// C'est un import de Core (autorise dans Data).
import 'package:trialgo/core/network/supabase_client.dart';

// Import de l'entite et du type CardType pour les signatures de methodes.
import 'package:trialgo/domain/entities/card_entity.dart';

// Import de l'INTERFACE que l'on implemente.
import 'package:trialgo/domain/repositories/card_repository.dart';

// Import du MODEL qui sait convertir le JSON en objet Dart.
import 'package:trialgo/data/models/card_model.dart';

/// Implementation concrete de [CardRepository] utilisant Supabase.
///
/// Cette classe traduit chaque methode du contrat en requete Supabase.
/// Elle utilise le SDK `supabase_flutter` pour communiquer avec
/// la table `cards` de PostgreSQL.
///
/// "implements CardRepository" : cette classe s'engage a fournir
/// TOUTES les methodes declarees dans CardRepository.
/// Si une methode manque, le compilateur affiche une erreur.
class CardRepositoryImpl implements CardRepository {

  // =============================================================
  // METHODE : getCardById
  // =============================================================
  // Recupere UNE carte par son UUID.
  //
  // "@override" : annotation qui indique qu'on REIMPLEMENTE une
  // methode de l'interface parente. Si on fait une faute de frappe
  // dans le nom de la methode, le compilateur nous previent
  // ("cette methode ne surcharge rien dans la classe parente").
  //
  // SQL genere par Supabase :
  //   SELECT * FROM cards WHERE id = $id LIMIT 1
  // =============================================================

  /// Recupere une carte par son [id] (UUID).
  ///
  /// Fait un SELECT sur la table `cards` avec filtre sur l'ID.
  /// `.single()` garantit exactement 1 resultat (erreur si 0 ou 2+).
  @override
  Future<CardEntity> getCardById(String id) async {
    // "supabase" : le getter global defini dans supabase_client.dart
    // ".from('cards')" : cible la table PostgreSQL nommee "cards"
    //   -> Equivalent de : FROM cards
    //
    // ".select()" : demande TOUTES les colonnes
    //   -> Equivalent de : SELECT *
    //   -> On pourrait specifier des colonnes : .select('id, image_path')
    //
    // ".eq('id', id)" : filtre d'egalite
    //   -> Equivalent de : WHERE id = $id
    //   -> "eq" = "equals" (egal a)
    //   -> Premier parametre : nom de la colonne
    //   -> Deuxieme parametre : valeur recherchee
    //
    // ".single()" : attend EXACTEMENT 1 resultat
    //   -> Si 0 resultats : leve une PostgrestException
    //   -> Si 2+ resultats : leve une PostgrestException
    //   -> Si 1 resultat : retourne un Map<String, dynamic>
    //
    // "await" : attend la reponse du serveur (operation reseau)
    final json = await supabase
        .from('cards')
        .select()
        .eq('id', id)
        .single();

    // "json" est maintenant un Map<String, dynamic> contenant
    // une ligne de la table cards au format JSON.
    //
    // On le convertit en CardModel (qui est aussi un CardEntity)
    // grace a la factory CardModel.fromJson().
    return CardModel.fromJson(json);
  }

  // =============================================================
  // METHODE : getCardsByType
  // =============================================================
  // Recupere toutes les cartes actives d'un type donne.
  //
  // SQL genere :
  //   SELECT * FROM cards
  //   WHERE card_type = $type AND is_active = true
  // =============================================================

  /// Recupere toutes les cartes actives du type [type].
  @override
  Future<List<CardEntity>> getCardsByType(CardType type) async {
    // La requete Supabase se construit par CHAINAGE de methodes.
    // Chaque methode retourne un builder, ce qui permet d'enchainer.
    //
    // ".eq('card_type', type.name)" : filtre sur le type
    //   type.name convertit l'enum en String :
    //   CardType.emettrice.name -> "emettrice"
    //
    // ".eq('is_active', true)" : ne prend que les cartes actives
    //   Securite supplementaire (en plus du RLS qui filtre deja)
    final data = await supabase
        .from('cards')
        .select()
        .eq('card_type', type.name)    // WHERE card_type = 'emettrice'
        .eq('is_active', true);        // AND is_active = true

    // "data" est une List<Map<String, dynamic>> :
    //   - List : plusieurs lignes retournees
    //   - Map<String, dynamic> : chaque ligne au format JSON
    //
    // ".map((json) => ...)" : transforme CHAQUE element de la liste
    //   - "json" : un Map<String, dynamic> (une ligne)
    //   - "=> CardModel.fromJson(json)" : le convertit en CardModel
    //   - ".map()" retourne un Iterable, pas une List
    //
    // ".toList()" : convertit l'Iterable en List
    //   Necessaire car le type de retour est List<CardEntity>,
    //   pas Iterable<CardEntity>.
    //
    // Equivalent avec une boucle for :
    //   final List<CardEntity> result = [];
    //   for (final json in data) {
    //     result.add(CardModel.fromJson(json));
    //   }
    //   return result;
    return data.map((json) => CardModel.fromJson(json)).toList();
  }

  // =============================================================
  // METHODE : getCardsByDistance
  // =============================================================
  // SQL genere :
  //   SELECT * FROM cards
  //   WHERE distance_level = $distance AND is_active = true
  // =============================================================

  /// Recupere toutes les cartes actives d'une distance [distance].
  @override
  Future<List<CardEntity>> getCardsByDistance(int distance) async {
    final data = await supabase
        .from('cards')
        .select()
        .eq('distance_level', distance)  // WHERE distance_level = 1/2/3
        .eq('is_active', true);          // AND is_active = true

    return data.map((json) => CardModel.fromJson(json)).toList();
  }

  // =============================================================
  // METHODE : getCardsByTypeAndDistance
  // =============================================================
  // Combine les filtres type + distance.
  //
  // SQL genere :
  //   SELECT * FROM cards
  //   WHERE card_type = $type
  //     AND distance_level = $distance
  //     AND is_active = true
  //
  // Cas d'utilisation : charger toutes les Receptrices D1
  //   getCardsByTypeAndDistance(CardType.receptrice, 1)
  // =============================================================

  /// Recupere les cartes filtrees par [type] ET [distance].
  @override
  Future<List<CardEntity>> getCardsByTypeAndDistance(
    CardType type,
    int distance,
  ) async {
    final data = await supabase
        .from('cards')
        .select()
        .eq('card_type', type.name)
        .eq('distance_level', distance)
        .eq('is_active', true);

    return data.map((json) => CardModel.fromJson(json)).toList();
  }

  // =============================================================
  // METHODE : getDistractors
  // =============================================================
  // Genere les 9 images distractrices pour une question de jeu.
  //
  // Logique (reference : recueil section 6.3) :
  //   1. Filtrer par MEME TYPE que la bonne reponse
  //   2. Exclure la bonne reponse elle-meme
  //   3. Si c'est un Cable : priorite a la meme cable_category
  //   4. Limiter au nombre demande (9 par defaut)
  //
  // SQL genere (cas Cable) :
  //   SELECT * FROM cards
  //   WHERE card_type = 'cable'
  //     AND is_active = true
  //     AND id != $correctCardId
  //     AND cable_category = $category
  //   LIMIT 5
  //
  //   UNION
  //
  //   SELECT * FROM cards
  //   WHERE card_type = 'cable'
  //     AND is_active = true
  //     AND id != $correctCardId
  //     AND cable_category != $category
  //   LIMIT 4
  //
  // (On prend d'abord de la meme categorie, puis on complete)
  // =============================================================

  /// Genere les distracteurs pour une question de jeu.
  ///
  /// [correctCard] : la bonne reponse (sera exclue des resultats).
  /// [count]       : nombre de distracteurs (defaut: 9).
  ///
  /// Retourne une liste de cartes du meme type que [correctCard]
  /// mais qui ne sont PAS la bonne reponse.
  @override
  Future<List<CardEntity>> getDistractors({
    required CardEntity correctCard,
    int count = 9,
  }) async {
    // --- CAS SPECIAL : la bonne reponse est un Cable ---
    // Les cables ont une categorie (geometrique, couleur, etc.).
    // On priorise les distracteurs de la MEME categorie pour
    // rendre le defi plus interessant visuellement.
    if (correctCard.isCable && correctCard.cableCategory != null) {
      // ETAPE 1 : Charger des cables de la MEME categorie
      //
      // ".neq('id', correctCard.id)" : filtre de NON-egalite
      //   -> Equivalent de : WHERE id != $correctCardId
      //   -> "neq" = "not equals" (different de)
      //   -> Exclut la bonne reponse des resultats
      //
      // ".limit(count ~/ 2)" : limite le nombre de resultats
      //   -> "~/" est la DIVISION ENTIERE en Dart
      //   -> 9 ~/ 2 = 4 (on prend 4 de la meme categorie)
      //   -> "/" serait la division decimale : 9 / 2 = 4.5
      final sameCategory = await supabase
          .from('cards')
          .select()
          .eq('card_type', correctCard.cardType.name)
          .eq('is_active', true)
          .eq('cable_category', correctCard.cableCategory!)
          // "!" apres cableCategory : affirme que la valeur n'est PAS null.
          // On a deja verifie avec "correctCard.cableCategory != null" au-dessus.
          // Sans "!", Dart refuse car le type est String? (nullable).
          .neq('id', correctCard.id)
          .limit(count ~/ 2);

      // ETAPE 2 : Completer avec des cables d'AUTRES categories
      //
      // "count - sameCategory.length" : combien il en manque
      // Si on a obtenu 4 de la meme categorie, il en faut 5 d'autres.
      final otherCategory = await supabase
          .from('cards')
          .select()
          .eq('card_type', correctCard.cardType.name)
          .eq('is_active', true)
          .neq('cable_category', correctCard.cableCategory!)
          .neq('id', correctCard.id)
          .limit(count - sameCategory.length);

      // ETAPE 3 : Fusionner les deux listes et convertir
      //
      // "[...list1, ...list2]" : spread operator
      //   Cree une nouvelle liste contenant tous les elements
      //   de list1 suivis de tous les elements de list2.
      //
      // "..shuffle()" : melange la liste en place (cascade operator)
      //   Pour que les distracteurs de meme categorie ne soient pas
      //   toujours au debut de la liste.
      return [...sameCategory, ...otherCategory]
          .map((json) => CardModel.fromJson(json))
          .toList()
        ..shuffle();
    }

    // --- CAS GENERAL : Emettrices ou Receptrices ---
    // Pas de categorie a prioriser. On prend simplement des cartes
    // du meme type, en excluant la bonne reponse.
    //
    // Filtre supplementaire : meme distance_level
    // Pour que les distracteurs soient visuellement proches.
    final data = await supabase
        .from('cards')
        .select()
        .eq('card_type', correctCard.cardType.name)
        .eq('is_active', true)
        .eq('distance_level', correctCard.distanceLevel)
        .neq('id', correctCard.id)
        .limit(count);

    return data.map((json) => CardModel.fromJson(json)).toList();
  }
}
