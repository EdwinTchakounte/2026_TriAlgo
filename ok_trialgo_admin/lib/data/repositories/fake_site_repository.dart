// =============================================================
// FICHIER : fake_site_repository.dart
// ROLE    : SiteRepository hors backend FastAPI
// =============================================================
//
// Deux implementations, pour deux situations differentes :
//
//   FakeSiteRepository        mode 'fake' : un document en memoire,
//                             pour essayer l'ecran sans serveur. Les
//                             images televersees restent en memoire
//                             sous forme d'URL data:, que Image.network
//                             sait afficher sur le web.
//
//   UnsupportedSiteRepository mode 'supabase' : la vitrine editable
//                             est nee avec FastAPI. On renvoie un Err
//                             explicite plutot qu'un document vide qui
//                             ferait croire que rien n'est publie
//                             (meme raisonnement que
//                             unsupported_admin_repositories.dart).
// =============================================================

import 'dart:convert';
import 'dart:typed_data';

import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/site_content.dart';
import '../../domain/repositories/site_repository.dart';

class FakeSiteRepository implements SiteRepository {
  // Le "serveur" : le dernier document publie.
  ContenuAccueil _publie = const ContenuAccueil();

  @override
  Future<Result<ContenuAccueil>> charger() async => Ok(_publie);

  @override
  Future<Result<ContenuAccueil>> publier(ContenuAccueil contenu) async {
    // Aller-retour par toJson/fromJson : le fake applique ainsi les
    // memes regles que le vrai serveur (champs vides retires), et
    // l'ecran voit exactement ce qu'il verrait en production.
    _publie = ContenuAccueil.fromJson(contenu.toJson(), majLe: DateTime.now());
    return Ok(_publie);
  }

  @override
  Future<Result<String>> televerserImage({
    required Uint8List octets,
    required String nomFichier,
    required String typeMime,
  }) async {
    return Ok('data:$typeMime;base64,${base64Encode(octets)}');
  }
}

class UnsupportedSiteRepository implements SiteRepository {
  const UnsupportedSiteRepository();

  static const _message =
      "L'édition de la vitrine n'est disponible qu'avec le backend "
      'FastAPI. Basculez ApiConfig.mode sur fastapi.';

  @override
  Future<Result<ContenuAccueil>> charger() async =>
      const Err(DataFailure(_message));

  @override
  Future<Result<ContenuAccueil>> publier(ContenuAccueil contenu) async =>
      const Err(DataFailure(_message));

  @override
  Future<Result<String>> televerserImage({
    required Uint8List octets,
    required String nomFichier,
    required String typeMime,
  }) async =>
      const Err(DataFailure(_message));
}
