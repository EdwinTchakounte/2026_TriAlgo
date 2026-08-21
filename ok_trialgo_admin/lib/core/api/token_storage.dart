// =============================================================
// FICHIER : token_storage.dart
// ROLE    : Persistance des JWT (access + refresh)
// =============================================================
//
// DEUX IMPLEMENTATIONS, CHOISIES SELON LA PLATEFORME
// --------------------------------------------------
//   Mobile / bureau : flutter_secure_storage
//       - Android : EncryptedSharedPreferences adossees au Keystore
//       - iOS     : Keychain
//     La protection y est reelle : la cle de chiffrement vit dans un
//     composant materiel, hors de portee de l'application elle-meme.
//
//   Web : SharedPreferences (soit localStorage)
//     Voir ci-dessous pourquoi on ne garde PAS le stockage securise.
//
// POURQUOI PAS flutter_secure_storage SUR LE WEB
// ----------------------------------------------
// Deux raisons, une de fiabilite et une de fond.
//
// 1. LA RAISON QUI NOUS A FORCE LA MAIN : sur le web, le plugin
//    chiffre en AES-GCM via SubtleCrypto, et ses operations ne se
//    terminaient pas toujours -- ni resultat, ni erreur, la Future
//    restait simplement en attente. Le studio se figeait alors sur
//    "Chargement de votre session", indefiniment, sans message et
//    sans moyen de reessayer autrement qu'en vidant le stockage du
//    navigateur. Observe en conditions reelles, sur le build web
//    exact qui est destine a dashboard.mixalgo.com.
//
// 2. LA RAISON DE FOND : sur le web, ce chiffrement ne protege de
//    rien. La cle est rangee dans le MEME localStorage, a cote des
//    valeurs qu'elle protege. N'importe quel script s'executant sur
//    la page -- c'est-a-dire toute faille XSS -- lit les deux et
//    dechiffre. On payait donc en fiabilite pour une securite qui
//    n'existait pas.
//
// Ce que l'on protege vraiment le jeton sur le web : une duree de
// vie courte cote serveur, un HTTPS strict, et l'absence de faille
// XSS. Pas un chiffrement dont la cle est publique.
//
// LE GARDE-FOU SUPPLEMENTAIRE : LE DELAI
// --------------------------------------
// Toutes les operations sont bornees dans le temps. Lire un jeton
// est une commodite, jamais une raison de figer une application :
// en cas de depassement, on se comporte comme s'il n'y avait pas de
// session et l'utilisateur retrouve l'ecran de connexion. C'est ce
// qui manquait, et c'est ce qui transformait un incident de plugin
// en interface morte.
// =============================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Delai au-dela duquel une operation de stockage est abandonnee.
///
/// Genereux : lire deux cles est instantane sur une plateforme
/// saine. Ce delai ne vise pas la lenteur, il vise l'absence
/// definitive de reponse.
const Duration _delaiMax = Duration(seconds: 5);

class TokenStorage {
  // Options Android : encrypted shared prefs explicitement.
  static const _securise = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccess = 'jwt_access';
  static const _kRefresh = 'jwt_refresh';

  // -----------------------------------------------------------
  // LECTURE
  // -----------------------------------------------------------

  /// Retourne (access, refresh), ou (null, null) si indisponible.
  ///
  /// Ne leve jamais : un stockage illisible signifie "pas de
  /// session", ce que l'appelant sait deja traiter.
  Future<(String?, String?)> read() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance()
            .timeout(_delaiMax);
        return (prefs.getString(_kAccess), prefs.getString(_kRefresh));
      }

      final access =
          await _securise.read(key: _kAccess).timeout(_delaiMax);
      final refresh =
          await _securise.read(key: _kRefresh).timeout(_delaiMax);
      return (access, refresh);
    } catch (_) {
      // Depassement de delai, plugin absent, valeur corrompue : on
      // repart sans session plutot que de bloquer l'interface.
      return (null, null);
    }
  }

  // -----------------------------------------------------------
  // ECRITURE
  // -----------------------------------------------------------

  /// Persiste les deux jetons. N'echoue jamais bruyamment.
  ///
  /// Un echec ici n'empeche PAS de continuer : les jetons restent
  /// valides en memoire pour la session en cours, seule la reprise
  /// automatique au prochain lancement sera perdue. C'est une
  /// degradation acceptable ; bloquer la connexion ne le serait pas.
  Future<void> save({required String access, required String refresh}) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance()
            .timeout(_delaiMax);
        await prefs.setString(_kAccess, access).timeout(_delaiMax);
        await prefs.setString(_kRefresh, refresh).timeout(_delaiMax);
        return;
      }

      await Future.wait([
        _securise.write(key: _kAccess, value: access),
        _securise.write(key: _kRefresh, value: refresh),
      ]).timeout(_delaiMax);
    } catch (_) {
      // Voir le commentaire ci-dessus : on continue.
    }
  }

  // -----------------------------------------------------------
  // EFFACEMENT
  // -----------------------------------------------------------

  /// Vide les jetons a la deconnexion.
  Future<void> clear() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance()
            .timeout(_delaiMax);
        await prefs.remove(_kAccess).timeout(_delaiMax);
        await prefs.remove(_kRefresh).timeout(_delaiMax);
        return;
      }

      await Future.wait([
        _securise.delete(key: _kAccess),
        _securise.delete(key: _kRefresh),
      ]).timeout(_delaiMax);
    } catch (_) {
      // Un effacement qui echoue ne doit pas empecher la
      // deconnexion : l'etat applicatif repasse a "non connecte"
      // quoi qu'il arrive, et le jeton expirera cote serveur.
    }
  }
}
