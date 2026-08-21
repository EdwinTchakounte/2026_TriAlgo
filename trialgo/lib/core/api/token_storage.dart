// =============================================================
// FICHIER : token_storage.dart  (trialgo - app joueur)
// ROLE    : Persistance securisee des JWT (access + refresh)
// =============================================================
//
// On stocke les tokens FastAPI dans flutter_secure_storage :
//   - sur Android : EncryptedSharedPreferences via Keystore
//   - sur iOS     : Keychain
//
// Plus sur que SharedPreferences (en clair sur disque). Sur un
// device root/jailbreak rien n'est invulnerable mais ca eleve
// significativement la barre.
//
// Les 3 operations dont on a besoin :
//   read()   : recupere (access, refresh) ou (null, null)
//   save()   : persiste apres login / refresh
//   clear()  : vide a la deconnexion
// =============================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  // Options Android : encrypted shared prefs explicitement.
  // iOS utilise le Keychain par defaut, pas besoin d'options.
  static const _opts = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Clefs distinctes pour ne pas collisionner avec d'autres apps
  // qui utiliseraient flutter_secure_storage sur le meme device.
  static const _kAccess = 'trialgo_jwt_access';
  static const _kRefresh = 'trialgo_jwt_refresh';

  /// Lecture des deux tokens. Renvoie (null, null) si aucun.
  Future<(String?, String?)> read() async {
    final access = await _opts.read(key: _kAccess);
    final refresh = await _opts.read(key: _kRefresh);
    return (access, refresh);
  }

  /// Sauvegarde apres login ou refresh reussi.
  Future<void> save({required String access, required String refresh}) async {
    await Future.wait([
      _opts.write(key: _kAccess, value: access),
      _opts.write(key: _kRefresh, value: refresh),
    ]);
  }

  /// Vide les tokens (logout, ou refresh echoue).
  Future<void> clear() async {
    await Future.wait([
      _opts.delete(key: _kAccess),
      _opts.delete(key: _kRefresh),
    ]);
  }

  /// True si l'utilisateur a une session active (access token present).
  /// Note : ne valide PAS la signature ; sert juste au routing initial.
  Future<bool> hasSession() async {
    final access = await _opts.read(key: _kAccess);
    return access != null;
  }
}
