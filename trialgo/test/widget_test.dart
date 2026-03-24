// =============================================================
// FICHIER : test/widget_test.dart
// ROLE   : Test de base pour verifier que l'application demarre
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trialgo/main.dart';

void main() {
  testWidgets('TrialgoApp should build without errors', (tester) async {
    // Verifie que le widget racine se construit sans exception.
    await tester.pumpWidget(const TrialgoApp());

    // Verifie que le titre "TRIALGO" est affiche.
    expect(find.text('TRIALGO'), findsOneWidget);
  });
}
