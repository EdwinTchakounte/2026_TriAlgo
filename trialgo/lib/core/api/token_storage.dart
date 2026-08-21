// =============================================================
// FICHIER : token_storage.dart  (trialgo - app joueur)
// ROLE    : Persistance des JWT (access + refresh)
// =============================================================
//
// DEUX IMPLEMENTATIONS, CHOISIES SELON LA PLATEFORME
// --------------------------------------------------
//   Mobile / bureau : flutter_secure_storage
//       - Android : EncryptedSharedPreferences adossees au Keystore
//       - iOS     : Keychain
//     La protection y est reelle : la cle de chiffrement vit dans un
//     composant materiel, hors de portee de l'application.
//
//   Web : SharedPreferences (soit localStorage)
//
// POURQUOI PAS flutter_secure_storage SUR LE WEB
// ----------------------------------------------
// Meme raisonnement -- et meme incident -- que dans le studio admin
// (cf. ok_trialgo_admin/lib/core/api/token_storage.dart) :
//
// 1. FIABILITE : sur le web, les operations du plugin ne se
//    terminaient pas toujours. Ni resultat, ni erreur : la Future
//    restait en attente. L'application se figeait alors sur son
//    ecran de demarrage, sans message et sans autre recours que
//    vider le stockage du navigateur. Constate en conditions
//    reelles sur le studio ; rien n'indique que cette application
//    y echapperait.
//
// 2. FOND : sur le web ce chiffrement ne protege de rien. La cle
//    est rangee dans le MEME localStorage, a cote des valeurs
//    qu'elle protege. Toute faille XSS lit les deux et dechiffre.
//    On payait en fiabilite une securite inexistante.
//
// LE DELAI MAXIMAL, VALABLE SUR TOUTES LES PLATEFORMES
// ----------------------------------------------------
// Toutes les operations sont bornees dans le temps, y compris sur
// mobile. Lire un jeton est une commodite, jamais une raison de
// figer un jeu : en cas de depassement, on se comporte comme s'il
// n'y avait pas de session et le joueur retrouve l'ecran de
// connexion. C'est exactement ce garde-fou qui manquait, et qui
// transformait un incident de plugin en application morte.
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
  // iOS utilise le Keychain par defaut, pas besoin d'options.
  static const _securise = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Clefs distinctes pour ne pas collisionner avec d'autres apps
  // qui utiliseraient flutter_secure_storage sur le meme device.
  static const _kAccess = 'trialgo_jwt_access';
  static const _kRefresh = 'trialgo_jwt_refresh';

  /// Lecture des deux jetons. Renvoie (null, null) si indisponible.
  ///
  /// Ne leve jamais : un stockage illisible signifie "pas de
  /// session", ce que l'appelant sait deja traiter.
  Future<(String?, String?)> read() async {
    try {
      if (kIsWeb) {
        final prefs =
            await SharedPreferences.getInstance().timeout(_delaiMax);
        return (prefs.getString(_kAccess), prefs.getString(_kRefresh));
      }

      final access =
          await _securise.read(key: _kAccess).timeout(_delaiMax);
      final refresh =
          await _securise.read(key: _kRefresh).timeout(_delaiMax);
      return (access, refresh);
    } catch (_) {
      // Depassement de delai, plugin absent, valeur corrompue : on
      // repart sans session plutot que de bloquer le jeu.
      return (null, null);
    }
  }

  /// Sauvegarde apres login ou refresh reussi.
  ///
  /// Un echec n'empeche PAS de continuer : les jetons restent
  /// valides en memoire pour la session en cours, seule la reprise
  /// automatique au prochain lancement sera perdue. Degradation
  /// acceptable ; bloquer la connexion ne le serait pas.
  Future<void> save({required String access, required String refresh}) async {
    try {
      if (kIsWeb) {
        final prefs =
            await SharedPreferences.getInstance().timeout(_delaiMax);
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

  /// Vide les jetons (deconnexion, ou refresh echoue).
  Future<void> clear() async {
    try {
      if (kIsWeb) {
        final prefs =
            await SharedPreferences.getInstance().timeout(_delaiMax);
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

  /// True si l'utilisateur a une session active (access token present).
  ///
  /// Note : ne valide PAS la signature ; sert juste au routage initial.
  /// S'appuie sur [read], donc herite du meme delai et du meme repli.
  Future<bool> hasSession() async {
    final (access, _) = await read();
    return access != null;
  }
}
