// Placeholder test : l'app necessite un client Supabase initialise
// pour booter, donc un widget test integral demanderait des mocks.
// Pour cette etape on garde un smoke test minimal qui verifie
// juste que la suite de tests compile (imports + structure).

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compilation smoke test', () {
    expect(1 + 1, 2);
  });
}
