// =============================================================
// FICHIER : card_repository.dart (interface domain)
// ROLE    : CRUD des cartes + upload d'image
// =============================================================

import 'dart:typed_data';

import '../../core/utils/result.dart';
import '../entities/card_type.dart';
import '../entities/game_card.dart';

abstract class CardRepository {
  // Liste toutes les cartes d'un game donne. Filtrage UI par type
  // (utiliser .where(...) cote presentation, garde le repo simple).
  Future<Result<List<GameCard>>> listByGame(String gameId);

  // Cree une carte. imagePath doit etre une URL Storage publique
  // obtenue prealablement via uploadImage().
  Future<Result<GameCard>> create({
    required String gameId,
    required String label,
    required String imagePath,
    required CardType type,
  });

  // Met a jour label/type. L'image est immuable : pour la changer
  // on supprime + recree (sinon orphan dans Storage difficile a
  // gerer pour un MVP).
  Future<Result<GameCard>> update({
    required String id,
    String? label,
    CardType? type,
  });

  // Supprime une carte. Si imagePath pointe vers le bucket
  // trialgo-cards, on tente aussi de retirer le fichier Storage
  // pour eviter les fichiers orphelins (best-effort, n'echoue pas
  // si l'objet a deja disparu).
  Future<Result<void>> delete({
    required String id,
    required String imagePath,
  });

  // Upload une image dans le bucket Storage. Renvoie l'URL
  // publique a stocker ensuite dans cards.image_path.
  // gameId sert de prefixe de dossier pour organiser le bucket :
  //   trialgo-cards/{gameId}/{timestamp}_{nom}.jpg
  Future<Result<String>> uploadImage({
    required String gameId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  });
}
