// =============================================================
// FICHIER : test/vignettes_test.dart
// ROLE   : Verrouiller le contrat de repli des vignettes
// =============================================================
//
// CE QUE CES TESTS PROTEGENT
// --------------------------
// La grille de six choix affiche des cartes d'environ 150 px. Elle
// recevait du 1024 px : un ordre de grandeur d'octets de trop, six
// fois par question. Le backend produit desormais une vignette
// 256 px a l'upload (migration 0010, colonne cards.thumb_key).
//
// Mais toutes les cartes n'en ont pas : celles creees avant la
// migration, et celles servies par le chemin Supabase. Le contrat
// est donc « thumb_url absent = utilise l'image pleine », jamais
// « erreur ».
//
// C'est exactement le genre de contrat qui casse en silence : une
// carte ancienne cesserait de s'afficher, et rien ne le signalerait
// -- ni exception, ni journal, juste un rectangle gris de plus dans
// une grille qui en compte deja pendant le chargement.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trialgo/data/models/graph_card_model.dart';
import 'package:trialgo/domain/entities/graph_card_entity.dart';

void main() {
  // ===========================================================
  group('GraphCardEntity.thumbUrl', () {
    // ===========================================================

    test('rend la vignette quand elle existe', () {
      const carte = GraphCardEntity(
        id: 'c1',
        label: 'Lion',
        imagePath: 'https://exemple.test/plein.jpg',
        thumbPath: 'https://exemple.test/vignette.jpg',
      );
      expect(carte.thumbUrl, 'https://exemple.test/vignette.jpg');
    });

    test('retombe sur l image pleine quand la vignette manque', () {
      const carte = GraphCardEntity(
        id: 'c1',
        label: 'Lion',
        imagePath: 'https://exemple.test/plein.jpg',
      );
      expect(carte.thumbUrl, carte.imageUrl,
          reason: 'une carte anterieure aux vignettes doit rester affichable');
    });

    test('traite une vignette vide comme une vignette absente', () {
      const carte = GraphCardEntity(
        id: 'c1',
        label: 'Lion',
        imagePath: 'https://exemple.test/plein.jpg',
        thumbPath: '',
      );
      expect(carte.thumbUrl, carte.imageUrl,
          reason: 'une chaine vide donnerait une URL invalide');
    });

    test('ne renvoie jamais une chaine vide', () {
      // Cas degenere : ni image ni vignette. L'appelant passe la
      // valeur a CachedNetworkImage, qui doit pouvoir afficher son
      // errorWidget -- pas planter sur une URL nulle.
      const carte = GraphCardEntity(id: 'c1', label: 'Lion', imagePath: '');
      expect(carte.thumbUrl, isNotNull);
    });

    test('prefixe un chemin relatif comme le fait imageUrl', () {
      const carte = GraphCardEntity(
        id: 'c1',
        label: 'Lion',
        imagePath: 'savane/lion.webp',
        thumbPath: 'savane/lion_thumb.webp',
      );
      expect(carte.thumbUrl, startsWith('https://'));
      expect(carte.thumbUrl, endsWith('savane/lion_thumb.webp'));
    });
  });

  // ===========================================================
  group('GraphCardModel.fromJson', () {
    // ===========================================================

    test('lit thumb_url de la reponse FastAPI', () {
      final carte = GraphCardModel.fromJson({
        'id': 'uuid-1',
        'label': 'Lion',
        'image_url': 'https://api.test/files/plein.jpg',
        'thumb_url': 'https://api.test/files/vignette.jpg',
      });
      expect(carte.thumbUrl, 'https://api.test/files/vignette.jpg');
      expect(carte.imageUrl, 'https://api.test/files/plein.jpg');
    });

    test('accepte une carte FastAPI sans thumb_url', () {
      // C'est le cas de toute carte creee avant la migration 0010 :
      // le champ est present dans le schema mais vaut null.
      final carte = GraphCardModel.fromJson({
        'id': 'uuid-1',
        'label': 'Lion',
        'image_url': 'https://api.test/files/plein.jpg',
        'thumb_url': null,
      });
      expect(carte.thumbUrl, 'https://api.test/files/plein.jpg');
    });

    test('accepte une reponse Supabase, qui ignore les vignettes', () {
      final carte = GraphCardModel.fromJson({
        'id': 'uuid-1',
        'label': 'Lion',
        'image_path': 'savane/lion.webp',
      });
      expect(carte.thumbUrl, carte.imageUrl,
          reason: 'le chemin Supabase ne connait pas thumb_url');
    });
  });
}
