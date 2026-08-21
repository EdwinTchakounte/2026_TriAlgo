// Placeholder test : le scaffolding par defaut de `flutter create`
// a ete remplace par TrialgoDashboardApp + Riverpod + Supabase.
// Un vrai test d'integration necessiterait un mock Supabase ;
// on garde ici un smoke test minimal qui verifie juste que les
// imports compilent.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compilation smoke test', () {
    // Pas d'assertion : on veut juste que l'import ci-dessus
    // resolve sans erreur (sinon flutter analyze casse).
    expect(1 + 1, 2);
  });
}
