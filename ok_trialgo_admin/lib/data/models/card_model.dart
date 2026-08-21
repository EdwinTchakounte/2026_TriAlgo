// =============================================================
// FICHIER : card_model.dart (DTO data)
// ROLE    : Serialisation GameCard <-> JSON Supabase
// =============================================================

import '../../domain/entities/card_type.dart';
import '../../domain/entities/game_card.dart';

class CardModel {
  CardModel._();

  static GameCard fromJson(Map<String, dynamic> j) {
    return GameCard(
      id: j['id'] as String,
      gameId: j['game_id'] as String,
      label: j['label'] as String,
      imagePath: j['image_path'] as String,
      // CardType.fromDb tolere null (cartes seed pre-migration)
      // et nous renvoie null. Le UI filtrera ces cartes-la.
      type: CardType.fromDb(j['card_type'] as String?),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  static Map<String, dynamic> toInsert({
    required String gameId,
    required String label,
    required String imagePath,
    required CardType type,
  }) {
    return {
      'game_id': gameId,
      'label': label,
      'image_path': imagePath,
      'card_type': type.dbKey,
    };
  }

  static Map<String, dynamic> toUpdate({
    String? label,
    CardType? type,
  }) {
    final m = <String, dynamic>{};
    if (label != null) m['label'] = label;
    if (type != null) m['card_type'] = type.dbKey;
    return m;
  }
}
