// =============================================================
// FICHIER : test/equilibrage_niveaux_test.dart
// ROLE   : Verrouiller l'equilibrage du jeu
// =============================================================
//
// CE QUE CES TESTS PROTEGENT
// --------------------------
// GameConstants calcule un LevelConfig complet (distance, configs,
// questions, seuil, points de base, vies par erreur, temps par tour).
// L'ecran de jeu en appliquait trois champs sur huit et codait le
// reste en dur. Consequences reelles :
//
//   - le seuil de reussite valait 4 quel que soit le niveau, alors
//     que la valeur exacte etait calculee ET affichee sur l'accueil.
//     Un niveau D5 de 15 questions se validait avec 4 bonnes
//     reponses, et le niveau suivant etait accorde la-dessus ;
//   - distanceMultiplier() et timeBonus() etaient ecrites et jamais
//     appelees : une question D5 rapportait autant qu'une D1 ;
//   - le palier de serie a 7 avait sa constante et aucun code.
//
// Ces tests portent sur des fonctions PURES : le calcul de score a
// ete sorti du widget precisement pour pouvoir etre verifie sans
// monter d'interface.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trialgo/core/constants/game_constants.dart';

void main() {
  group('Progression des niveaux', () {
    // Un jeu complet : toutes les tables disponibles a chaque distance.
    const tablesCompletes = [1, 5, 14, 27, 44];

    test('la distance monte avec le niveau', () {
      // D1 occupe le niveau 1 ; D2 les niveaux 2 a 6 ; D3 les 7 a 20.
      expect(GameConstants.getLevelConfigForTables(1, tablesCompletes).distance, 1);
      expect(GameConstants.getLevelConfigForTables(2, tablesCompletes).distance, 2);
      expect(GameConstants.getLevelConfigForTables(6, tablesCompletes).distance, 2);
      expect(GameConstants.getLevelConfigForTables(7, tablesCompletes).distance, 3);
    });

    test('le plan s adapte au contenu reellement disponible', () {
      // Un jeu qui n'a que 2 noeuds racines et rien d'autre : il ne
      // doit pas proposer de niveaux D2 vides.
      const contenuPauvre = [1, 0, 0, 0, 0];
      expect(
        GameConstants.getLevelConfigForTables(2, contenuPauvre).distance,
        1,
        reason: 'sans table D2, le niveau 2 ne doit pas viser D2',
      );
    });

    test('le seuil de reussite est proportionnel au nombre de questions', () {
      for (final niveau in [1, 2, 7, 20]) {
        final config = GameConstants.getLevelConfigForTables(niveau, tablesCompletes);
        expect(
          config.threshold,
          greaterThan(config.questions ~/ 2),
          reason: 'niveau $niveau : reussir doit exiger plus de la moitie',
        );
        expect(config.threshold, lessThanOrEqualTo(config.questions));
        expect(
          config.threshold,
          greaterThan(4),
          reason: 'niveau $niveau : le seuil doit depasser l ancienne valeur figee',
        );
      }
    });

    test('les vies se consomment plus vite en profondeur', () {
      final d1 = GameConstants.getLevelConfigForTables(1, tablesCompletes);
      final d5 = GameConstants.getLevelConfigForTables(21, tablesCompletes);
      expect(
        d5.livesPerWrong,
        lessThanOrEqualTo(d1.livesPerWrong),
        reason: 'plus le niveau est profond, moins l erreur est pardonnee',
      );
    });
  });

  group('Score d une bonne reponse', () {
    test('la profondeur est recompensee', () {
      int score(int distance) => GameConstants.scoreForCorrectAnswer(
            basePoints: 20,
            distance: distance,
            elapsedSeconds: 10,
            maxSeconds: 40,
            streak: 1,
          );

      // C'est le bug d'origine : sans multiplicateur, ces cinq
      // valeurs etaient identiques.
      final scores = [1, 2, 3, 4, 5].map(score).toList();
      for (var i = 1; i < scores.length; i++) {
        expect(
          scores[i],
          greaterThan(scores[i - 1]),
          reason: 'D${i + 1} doit rapporter plus que D$i (obtenu $scores)',
        );
      }
      expect(scores.last, scores.first * 3, reason: 'D5 = x3,0 de D1');
    });

    test('la rapidite est recompensee', () {
      int score(int elapsed) => GameConstants.scoreForCorrectAnswer(
            basePoints: 20,
            distance: 1,
            elapsedSeconds: elapsed,
            maxSeconds: 40,
            streak: 1,
          );

      expect(score(5), greaterThan(score(15)));   // turbo > rapide
      expect(score(15), greaterThan(score(25)));  // rapide > normal
      expect(score(25), greaterThan(score(35)));  // normal > lent
    });

    test('les deux paliers de serie existent', () {
      expect(GameConstants.streakBonus(0), 0);
      expect(GameConstants.streakBonus(2), 0);
      expect(GameConstants.streakBonus(3), 10);
      expect(GameConstants.streakBonus(6), 10);
      expect(
        GameConstants.streakBonus(7),
        25,
        reason: 'le palier renforce avait sa constante et aucun code',
      );
    });

    test('un niveau profond et rapide bat largement un debut de partie', () {
      final debutant = GameConstants.scoreForCorrectAnswer(
        basePoints: 10, distance: 1, elapsedSeconds: 25, maxSeconds: 30, streak: 1,
      );
      final expert = GameConstants.scoreForCorrectAnswer(
        basePoints: 50, distance: 5, elapsedSeconds: 5, maxSeconds: 40, streak: 8,
      );
      expect(expert, greaterThan(debutant * 10));
    });
  });
}
