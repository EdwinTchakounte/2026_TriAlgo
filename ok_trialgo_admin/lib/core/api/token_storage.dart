// =============================================================
// FICHIER : token_storage.dart
// ROLE    : Persistance securisee des JWT (access + refresh)
// =============================================================
//
// On stocke les tokens dans flutter_secure_storage qui :
//   - sur Android : utilise EncryptedSharedPreferences via Keystore
//   - sur iOS     : utilise le Keychain
//
// Plus sur que SharedPreferences (qui sont en clair sur disque).
// Si le device est root/jailbreak, rien n'est invulnerable, mais
// ca eleve significativement la barre.
//
// Les 3 operations dont on a besoin :
//   read()   : recupere (access, refresh) ou (null, null)
//   save()   : persiste apres login / refresh
//   clear()  : vide a la deconnexion
// =============================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  // Options Android : encrypted shared prefs explicitement.
  static const _opts = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccess = 'jwt_access';
  static const _kRefresh = 'jwt_refresh';

  Future<(String?, String?)> read() async {
    final access = await _opts.read(key: _kAccess);
    final refresh = await _opts.read(key: _kRefresh);
    return (access, refresh);
  }

  Future<void> save({required String access, required String refresh}) async {
    await Future.wait([
      _opts.write(key: _kAccess, value: access),
      _opts.write(key: _kRefresh, value: refresh),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _opts.delete(key: _kAccess),
      _opts.delete(key: _kRefresh),
    ]);
  }
}
