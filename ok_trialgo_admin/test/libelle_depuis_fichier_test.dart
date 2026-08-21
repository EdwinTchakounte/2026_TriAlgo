// =============================================================
// FICHIER : test/libelle_depuis_fichier_test.dart
// ROLE    : Verrouiller la deduction de libelle a l'import par lot
// =============================================================
//
// Cette fonction decide du libelle propose pour chacune des
// cinquante images d'un import. Une regression ici ne planterait
// rien : elle produirait juste des cartes mal nommees, et
// l'administrateur les corrigerait a la main sans comprendre
// pourquoi. C'est exactement le genre de degradation silencieuse
// qu'un test attrape.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trialgo_admin/core/utils/libelle_depuis_fichier.dart';

void main() {
  group('Libelle deduit du nom de fichier', () {
    test('cas courant : un nom simple', () {
      expect(libelleDepuisNomDeFichier('lion.jpg'), 'Lion');
    });

    test('les separateurs techniques deviennent des espaces', () {
      expect(libelleDepuisNomDeFichier('miroir_brise.png'), 'Miroir brise');
      expect(libelleDepuisNomDeFichier('reflet-eau.jpeg'), 'Reflet eau');
      expect(
        libelleDepuisNomDeFichier('vent__du___nord.jpg'),
        'Vent du nord',
      );
    });

    test('les noms d appareil photo perdent leurs capitales', () {
      // Une carte intitulee "DSC 0042" en pleine partie informe peu.
      expect(libelleDepuisNomDeFichier('DSC_0042.JPG'), 'Dsc 0042');
    });

    test('seule la derniere extension est retiree', () {
      expect(libelleDepuisNomDeFichier('reflet.eau.jpg'), 'Reflet.eau');
    });

    test('un nom sans extension passe tel quel', () {
      expect(libelleDepuisNomDeFichier('lion'), 'Lion');
    });

    test('un fichier cache garde son nom', () {
      // Le point initial n'est pas un separateur d'extension.
      expect(libelleDepuisNomDeFichier('.gitkeep'), '.gitkeep');
    });

    test('un nom vide ou insignifiant retombe sur un defaut', () {
      expect(libelleDepuisNomDeFichier(''), 'Carte');
      expect(libelleDepuisNomDeFichier('___.jpg'), 'Carte');
      expect(libelleDepuisNomDeFichier('   '), 'Carte');
    });

    test('les espaces de bord sont rognes', () {
      expect(libelleDepuisNomDeFichier('  lion  .jpg'), 'Lion');
    });
  });
}
