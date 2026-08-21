// =============================================================
// FICHIER : test/demarrage_sans_supabase_test.dart
// ROLE   : Verifier que l'app joueur demarre sans Supabase
// =============================================================
//
// CE QUE CE TEST PROTEGE
// ----------------------
// En mode fastapi, main() n'appelle plus Supabase.initialize().
// Le client Supabase est donc absent pendant toute la vie du
// processus. Tout code qui l'atteindrait malgre tout planterait au
// premier lancement chez l'utilisateur -- exactement le genre de
// regression qu'on ne voit pas en developpement si la machine a,
// elle, une session Supabase valide en cache.
//
// Ces tests s'executent SANS jamais initialiser Supabase, ce qui
// reproduit fidelement les conditions d'un APK de production.
//
// Lancer :  flutter test test/demarrage_sans_supabase_test.dart
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/core/constants/admin_constants.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/core/session/session_utilisateur.dart';

void main() {
  group('Demarrage sans Supabase', () {
    setUp(SessionUtilisateur.effacer);

    test('le mode actif est bien fastapi', () {
      // Si ce test echoue, c'est qu'on a rebascule ApiConfig.mode sur
      // supabase. Les tests suivants n'auraient alors plus de sens :
      // ils decrivent le comportement attendu en mode fastapi.
      expect(ApiConfig.isFastApi, isTrue);
      expect(ApiConfig.isSupabase, isFalse);
    });

    test('initSupabaseSiNecessaire ne fait rien et laisse le client absent',
        () async {
      // C'est l'appel exact que fait main(). En mode fastapi il doit
      // se terminer sans rien initialiser, et surtout sans lever.
      await initSupabaseSiNecessaire();

      expect(supabaseEstDisponible, isFalse,
          reason: 'Supabase ne doit pas etre initialise en mode fastapi');
    });

    test('acceder au client Supabase leve une erreur explicite', () {
      // Le message doit nommer la cause et la correction : c'est ce qui
      // distingue un diagnostic d'une AssertionError opaque du SDK.
      expect(
        () => supabase,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Client Supabase indisponible'),
              contains('fastapi'),
            ),
          ),
        ),
      );
    });

    test("l'identite utilisateur fonctionne sans Supabase", () {
      // Etat initial : personne de connecte. Aucun de ces getters ne
      // doit tenter d'atteindre le client Supabase.
      expect(SessionUtilisateur.id, isNull);
      expect(SessionUtilisateur.email, isNull);
      expect(SessionUtilisateur.estConnecte, isFalse);
      expect(SessionUtilisateur.estAdmin, isFalse);

      // Apres memorisation, comme le fait TAuthGate au demarrage.
      SessionUtilisateur.memoriserDepuisJson({
        'id': '11111111-2222-3333-4444-555555555555',
        'email': 'joueur@mixalgo.com',
        'is_admin': false,
      });
      expect(SessionUtilisateur.id, '11111111-2222-3333-4444-555555555555');
      expect(SessionUtilisateur.email, 'joueur@mixalgo.com');
      expect(SessionUtilisateur.estConnecte, isTrue);
      expect(SessionUtilisateur.estAdmin, isFalse);

      // Deconnexion : le cache doit repartir a vide, sinon l'entree
      // admin resterait visible pour le compte suivant.
      SessionUtilisateur.effacer();
      expect(SessionUtilisateur.estConnecte, isFalse);
    });

    test('AdminConstants.isAdmin repond sans toucher Supabase', () {
      // Appele depuis un build() : doit etre synchrone et sans reseau.
      expect(AdminConstants.isAdmin(), isFalse);

      SessionUtilisateur.memoriserDepuisJson({
        'id': 'aaaa',
        'email': 'admin@mixalgo.com',
        'is_admin': true,
      });
      expect(AdminConstants.isAdmin(), isTrue,
          reason: 'is_admin du backend fait autorite en mode fastapi');
    });

    test('une charge utile partielle ne fait pas planter la memorisation', () {
      // Le backend pourrait n'exposer qu'une partie des champs : la
      // memorisation doit degrader, pas lever.
      SessionUtilisateur.memoriserDepuisJson({'id': 'bbbb'});
      expect(SessionUtilisateur.id, 'bbbb');
      expect(SessionUtilisateur.email, isNull);
      expect(SessionUtilisateur.estAdmin, isFalse);

      SessionUtilisateur.memoriserDepuisJson(null);
      expect(SessionUtilisateur.estConnecte, isFalse);
    });
  });
}
