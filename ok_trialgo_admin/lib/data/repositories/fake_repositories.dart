// =============================================================
// FICHIER : fake_repositories.dart
// ROLE    : Repositories EN MEMOIRE pour valider le flow sans backend
// =============================================================
//
// /!\ FICHIER DE DEV UNIQUEMENT. Branche seulement quand
//     kDevBypassAuth == true (voir main.dart). Aucune donnee ne
//     part vers Supabase : tout vit en RAM le temps de la session.
//
// POURQUOI ?
// On veut derouler tout l'enchainement d'ecrans
//   hub -> creer jeu -> cartes -> trios -> apercu
// sans dependre d'un compte admin ni des RLS Supabase. Ces fakes
// implementent les MEMES interfaces que les vrais repos, donc les
// pages/notifiers ne voient aucune difference.
//
// Les 3 repos partagent un meme FakeStore : une carte creee dans
// FakeCardRepository est donc visible par les autres (coherence).
//
// Images : uploadImage ne pousse rien ; il renvoie une URL
// picsum.photos deterministe (seed) pour que les vignettes
// affichent quelque chose de plausible (necessite une connexion ;
// sinon CardThumbnail montre son errorWidget, ce qui reste propre).
// =============================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/card_type.dart';
import '../../domain/entities/game.dart';
import '../../domain/entities/game_card.dart';
import '../../domain/entities/game_node.dart';
import '../../domain/repositories/card_repository.dart';
import '../../domain/repositories/game_repository.dart';
import '../../domain/repositories/node_repository.dart';

// -------------------------------------------------------------
// FakeStore : la "base de donnees" en RAM, partagee par les 3 repos.
// -------------------------------------------------------------
class FakeStore {
  // Listes mutables : on ajoute/retire au fil des actions de l'admin.
  final List<Game> games = [];
  final List<GameCard> cards = [];
  final List<GameNode> nodes = [];

  // Constructeur vide explicite : des qu'on declare un autre
  // constructeur (ici le factory `seeded`), Dart cesse de fournir
  // le constructeur sans nom par defaut. On le redeclare donc.
  FakeStore();

  // Compteur pour generer des ids uniques lisibles (fake-1, fake-2...).
  int _seq = 0;
  String nextId() {
    _seq += 1;
    return 'fake-$_seq';
  }

  // -----------------------------------------------------------
  // FakeStore.seeded : pre-remplit un jeu de demo avec des cartes.
  // -----------------------------------------------------------
  // But : a l'ouverture du hub, l'admin voit deja un jeu et peut
  // entrer dedans pour tester DIRECTEMENT le flow des trios sans
  // d'abord uploader des cartes. Le flow "creer un jeu vide" reste
  // dispo via le bouton + (il partira, lui, d'un etat vierge).
  //
  // On seme 6 cartes : 2 emettrices, 2 cables, 2 receptrices, ce
  // qui suffit a composer au moins un D1 (E+C=>R) puis un D2 chaine.
  factory FakeStore.seeded() {
    final store = FakeStore();
    final now = DateTime.now();

    // Le jeu de demonstration.
    final gameId = store.nextId();
    store.games.add(
      Game(
        id: gameId,
        name: 'TRIALGO Savane (démo)',
        description: 'Jeu de demo en memoire pour valider les flows.',
        theme: 'savane',
        coverImage: null,
        isActive: true,
        createdAt: now,
      ),
    );

    // Petite fabrique locale : cree une carte avec une URL Unsplash
    // stable. Les URLs ci-dessous sont issues du CDN Unsplash et
    // restent valides tant que la photo existe (jamais ephemere).
    // Si l'utilisateur est offline -> CardThumbnail retombe sur
    // l'avatar genere (lettre + couleur).
    void seedCard(String label, CardType type, String imageUrl) {
      store.cards.add(
        GameCard(
          id: store.nextId(),
          gameId: gameId,
          label: label,
          imagePath: imageUrl,
          type: type,
          createdAt: now,
        ),
      );
    }

    // 2 ingredients A, 2 ingredients B, 2 produits.
    // URLs Unsplash CDN stables (format images.unsplash.com/photo-<id>).
    // Resolution 400x400 demandee via parametres pour limiter la
    // bande passante.
    const u = 'https://images.unsplash.com/photo-';
    const params = '?w=400&h=400&fit=crop&auto=format&q=80';
    seedCard('Lion',     CardType.emettrice,  '${u}1546182990-dffeafbe841d$params');
    seedCard('Zèbre',    CardType.emettrice,  '${u}1526139334526-f591c11d77c6$params');
    seedCard('Liane',    CardType.cable,      '${u}1502082553048-f009c37129b9$params');
    seedCard('Rivière',  CardType.cable,      '${u}1426604966848-d7adac402bff$params');
    seedCard('Gazelle',  CardType.receptrice, '${u}1564349683136-77e08dba1ef7$params');
    seedCard('Éléphant', CardType.receptrice, '${u}1564760055775-d63b17a55c44$params');

    return store;
  }
}

// =============================================================
// FakeGameRepository
// =============================================================
class FakeGameRepository implements GameRepository {
  final FakeStore _store;
  FakeGameRepository(this._store);

  @override
  Future<Result<List<Game>>> listAll() async {
    // Copie defensive : on ne veut pas que l'UI mute la liste interne.
    return Ok(List<Game>.from(_store.games));
  }

  @override
  Future<Result<Game>> create({
    required String name,
    String? description,
    String? theme,
  }) async {
    // On fabrique un Game complet, comme le ferait la DB (id + date).
    final game = Game(
      id: _store.nextId(),
      name: name,
      description: description,
      theme: theme,
      coverImage: null,
      isActive: true,
      createdAt: DateTime.now(),
    );
    _store.games.add(game);
    return Ok(game);
  }

  @override
  Future<Result<Game>> update({
    required String id,
    String? name,
    String? description,
    String? theme,
    bool? isActive,
  }) async {
    final i = _store.games.indexWhere((g) => g.id == id);
    if (i < 0) return const Err(NotFoundFailure('Jeu introuvable (fake)'));
    final updated = _store.games[i].copyWith(
      name: name,
      description: description,
      theme: theme,
      isActive: isActive,
    );
    _store.games[i] = updated;
    return Ok(updated);
  }
}

// =============================================================
// FakeCardRepository
// =============================================================
class FakeCardRepository implements CardRepository {
  final FakeStore _store;
  FakeCardRepository(this._store);

  @override
  Future<Result<List<GameCard>>> listByGame(String gameId) async {
    final list = _store.cards.where((c) => c.gameId == gameId).toList();
    return Ok(list);
  }

  @override
  Future<Result<GameCard>> create({
    required String gameId,
    required String label,
    required String imagePath,
    required CardType type,
  }) async {
    final card = GameCard(
      id: _store.nextId(),
      gameId: gameId,
      label: label,
      imagePath: imagePath,
      type: type,
      createdAt: DateTime.now(),
    );
    _store.cards.add(card);
    return Ok(card);
  }

  @override
  Future<Result<GameCard>> update({
    required String id,
    String? label,
    CardType? type,
  }) async {
    final i = _store.cards.indexWhere((c) => c.id == id);
    if (i < 0) return const Err(NotFoundFailure('Carte introuvable (fake)'));
    final updated = _store.cards[i].copyWith(label: label, type: type);
    _store.cards[i] = updated;
    return Ok(updated);
  }

  @override
  Future<Result<void>> delete({
    required String id,
    required String imagePath,
  }) async {
    _store.cards.removeWhere((c) => c.id == id);
    return const Ok<void>(null);
  }

  @override
  Future<Result<String>> uploadImage({
    required String gameId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // Persistance locale : on ecrit les bytes dans
    // <documents>/cards/<gameId>/<timestamp>_<filename>.
    // L'image survit aux relances de l'app et l'URL retournee
    // est un file:// que CardThumbnail sait rendre via Image.file.
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cardsDir = Directory(p.join(dir.path, 'cards', gameId));
      if (!cardsDir.existsSync()) cardsDir.createSync(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      // Nettoie le nom de fichier pour eviter les caracteres bizarres
      // qui plantent sur certains systemes (espaces, accents, etc.).
      final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File(p.join(cardsDir.path, '${stamp}_$safe'));
      await file.writeAsBytes(bytes, flush: true);
      // On encode au format file URI pour que CardThumbnail puisse
      // detecter le scheme et basculer sur Image.file.
      return Ok(Uri.file(file.path).toString());
    } catch (e) {
      return Err(StorageFailure(
        'Echec ecriture locale : $e',
      ));
    }
  }
}

// =============================================================
// FakeNodeRepository
// =============================================================
class FakeNodeRepository implements NodeRepository {
  final FakeStore _store;
  FakeNodeRepository(this._store);

  @override
  Future<Result<List<GameNode>>> listByGame(String gameId) async {
    final list = _store.nodes.where((n) => n.gameId == gameId).toList()
      ..sort((a, b) => a.nodeIndex.compareTo(b.nodeIndex));
    return Ok(list);
  }

  @override
  Future<Result<int>> nextNodeIndex(String gameId) async {
    final list = _store.nodes.where((n) => n.gameId == gameId).toList();
    if (list.isEmpty) return const Ok(1);
    final maxIdx =
        list.map((n) => n.nodeIndex).reduce((a, b) => a > b ? a : b);
    return Ok(maxIdx + 1);
  }

  @override
  Future<Result<GameNode>> createTrio({
    required String gameId,
    required int nodeIndex,
    required String? emettriceId,
    required String cableId,
    required String receptriceId,
    required String? parentNodeId,
    required int depth,
  }) async {
    final node = GameNode(
      id: _store.nextId(),
      gameId: gameId,
      nodeIndex: nodeIndex,
      emettriceId: emettriceId,
      cableId: cableId,
      receptriceId: receptriceId,
      parentNodeId: parentNodeId,
      depth: depth,
      createdAt: DateTime.now(),
    );
    _store.nodes.add(node);
    return Ok(node);
  }

  @override
  Future<Result<void>> delete(String nodeId) async {
    // On reproduit le ON DELETE CASCADE : on retire le node ET
    // tous ses descendants (recursivement) pour rester coherent.
    final toRemove = <String>{nodeId};
    bool changed = true;
    while (changed) {
      changed = false;
      for (final n in _store.nodes) {
        if (n.parentNodeId != null &&
            toRemove.contains(n.parentNodeId) &&
            !toRemove.contains(n.id)) {
          toRemove.add(n.id);
          changed = true;
        }
      }
    }
    _store.nodes.removeWhere((n) => toRemove.contains(n.id));
    return const Ok<void>(null);
  }
}
