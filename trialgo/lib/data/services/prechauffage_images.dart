// =============================================================
// FICHIER : lib/data/services/prechauffage_images.dart
// ROLE   : Remplir le cache d'images AVANT que le jeu en ait besoin
// COUCHE : Data > Services
// =============================================================
//
// LE PROBLEME
// -----------
// Une question de jeu affiche huit cartes : deux en grand, et six
// dans la grille de choix. Toutes etaient chargees au moment ou la
// question s'affichait, chacune derriere son placeholder. A la
// premiere partie, ce sont huit requetes froides pendant que le
// joueur regarde des rectangles gris -- et le chronometre tourne.
//
// CE QUE FAIT CE SERVICE
// ----------------------
// Il telecharge les VIGNETTES de tout le catalogue pendant l'ecran
// de chargement du graphe, ou le joueur attend deja. Ensuite, la
// grille de six choix s'affiche instantanement pour le reste de la
// partie, et pour toutes les parties suivantes -- le cache de
// cached_network_image est sur disque, il survit au redemarrage.
//
// POURQUOI SEULEMENT LES VIGNETTES
// --------------------------------
// C'est ce qui rend l'operation acceptable. Une carte pese environ
// 220 Ko en plein format contre quelques kilo-octets en vignette :
// prechauffer les 76 cartes d'un jeu coute moins d'un megaoctet en
// vignettes, contre une quinzaine en plein format. Le premier est
// invisible sur un forfait mobile, le second ne l'est pas.
//
// Les deux cartes affichees en grand restent donc chargees a la
// demande. Il n'y en a que deux par question, et elles sont visibles
// des l'apparition de la question -- rien a anticiper.
//
// TROIS PRECAUTIONS
// -----------------
// 1. NE JAMAIS BLOQUER. Un prechauffage qui echoue ne doit pas
//    empecher de jouer : chaque erreur est avalee, et l'ensemble
//    est borne par un delai maximal. Au pire, le jeu se comporte
//    comme avant.
// 2. NE PAS SATURER. Les images partent par petits lots plutot que
//    toutes en meme temps : 76 requetes simultanees saturent le
//    pool de connexions et ralentissent tout le reste, y compris
//    les appels d'API dont depend le chargement.
// 3. ETRE ANNULABLE. Si le joueur quitte l'ecran, le travail
//    s'arrete a la fin du lot en cours.
// =============================================================

import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:trialgo/domain/entities/graph_card_entity.dart';

/// Nombre d'images telechargees de front.
///
/// Assez pour saturer une connexion correcte, assez peu pour ne pas
/// affamer les appels d'API qui tournent en parallele.
const int kTailleLotPrechauffage = 6;

/// Delai au-dela duquel on renonce et laisse le joueur avancer.
const Duration kDelaiMaxPrechauffage = Duration(seconds: 12);

/// Precharge les vignettes du catalogue dans le cache disque.
class PrechauffageImages {
  PrechauffageImages({BaseCacheManager? cacheManager})
      : _cache = cacheManager ?? DefaultCacheManager();

  /// Le meme gestionnaire de cache que celui de CachedNetworkImage :
  /// c'est ce qui fait que le travail profite bien a l'affichage.
  final BaseCacheManager _cache;

  /// Mis a vrai quand l'appelant demande l'arret.
  bool _annule = false;

  /// Interrompt le prechauffage a la fin du lot en cours.
  void annuler() => _annule = true;

  // =============================================================
  // METHODE : prechauffer
  // =============================================================

  /// Telecharge les vignettes de [cartes] dans le cache.
  ///
  /// [onProgres] est appele apres chaque lot avec le nombre d'images
  /// traitees et le total, pour alimenter une barre de progression.
  ///
  /// Ne leve jamais. Retourne le nombre d'images effectivement mises
  /// en cache -- utile pour un journal, jamais pour decider quoi que
  /// ce soit : un prechauffage partiel reste un succes.
  Future<int> prechauffer(
    Iterable<GraphCardEntity> cartes, {
    void Function(int faites, int total)? onProgres,
  }) async {
    // Une meme image peut servir plusieurs cartes ; et surtout,
    // thumbUrl retombe sur imageUrl quand la vignette manque, ce qui
    // peut produire des doublons entre cartes. On dedoublonne donc
    // sur l'URL, pas sur la carte.
    final urls = <String>{
      for (final c in cartes)
        if (c.thumbUrl.isNotEmpty) c.thumbUrl,
    }.toList();

    if (urls.isEmpty) return 0;

    var reussies = 0;
    var traitees = 0;

    Future<void> travail() async {
      for (var debut = 0; debut < urls.length; debut += kTailleLotPrechauffage) {
        if (_annule) return;

        final lot = urls.skip(debut).take(kTailleLotPrechauffage);
        final resultats = await Future.wait(
          lot.map((url) async {
            try {
              await _cache.downloadFile(url);
              return true;
            } catch (_) {
              // Une image manquante ou un reseau capricieux ne doit
              // pas interrompre le reste : elle sera simplement
              // chargee a la demande, comme avant.
              return false;
            }
          }),
        );

        reussies += resultats.where((ok) => ok).length;
        traitees += resultats.length;
        onProgres?.call(traitees, urls.length);
      }
    }

    try {
      await travail().timeout(kDelaiMaxPrechauffage);
    } on TimeoutException {
      // Le joueur a assez attendu. Ce qui est en cache est acquis,
      // le reste se chargera en cours de partie.
    } catch (_) {
      // Filet general : aucun defaut de prechauffage ne doit
      // remonter jusqu'a l'ecran de chargement.
    }

    return reussies;
  }
}
