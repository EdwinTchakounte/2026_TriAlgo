// =============================================================
// FICHIER : site_repository.dart (contrat domain)
// ROLE    : Lecture / publication du contenu de la vitrine
// =============================================================
//
// Correspond aux routes /api/admin/site du backend :
//   charger()            -> GET  /api/admin/site/accueil
//   publier(contenu)     -> PUT  /api/admin/site/accueil
//   televerserImage(...) -> POST /api/admin/site/images
//
// televerserImage renvoie l'URL PUBLIQUE de l'image : c'est elle,
// et rien d'autre, qui est ensuite rangee dans la galerie. La
// vitrine n'a jamais besoin de connaitre la cle de stockage.
// =============================================================

import 'dart:typed_data';

import '../../core/utils/result.dart';
import '../entities/site_content.dart';

abstract class SiteRepository {
  /// Le document "accueil" tel que publie. Un document jamais
  /// publie revient comme un ContenuAccueil vide, pas comme une erreur.
  Future<Result<ContenuAccueil>> charger();

  /// Remplace le document publie par [contenu]. Renvoie le document
  /// tel que le serveur l'a enregistre (avec sa nouvelle date).
  Future<Result<ContenuAccueil>> publier(ContenuAccueil contenu);

  /// Televerse une image et renvoie son URL publique.
  Future<Result<String>> televerserImage({
    required Uint8List octets,
    required String nomFichier,
    required String typeMime,
  });
}
