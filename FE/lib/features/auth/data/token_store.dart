import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

class PreferencesTokenStore implements TokenStore {
  PreferencesTokenStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  static const storageKey = 'vitality.auth.access_token';

  @override
  Future<String?> read() => _preferences.getString(storageKey);

  @override
  Future<void> write(String token) => _preferences.setString(storageKey, token);

  @override
  Future<void> clear() => _preferences.remove(storageKey);
}

/// Serializes migration and session changes so concurrent API requests cannot
/// read an empty token midway through migration or resurrect it after logout.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage, TokenStore? legacy})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          ),
      _legacy = legacy ?? PreferencesTokenStore();
  final FlutterSecureStorage _storage;
  final TokenStore _legacy;
  static const storageKey = 'movid.auth.access_token';
  Future<void> _pending = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _writeVerified(String token) async {
    await _storage.write(key: storageKey, value: token);
    if (await _storage.read(key: storageKey) != token) {
      throw StateError('로그인 정보를 안전하게 저장하지 못했어요. 다시 시도해 주세요.');
    }
  }

  @override
  Future<String?> read() => _serial(() async {
    final current = await _storage.read(key: storageKey);
    if (current != null) {
      await _legacy.clear();
      return current;
    }
    final old = await _legacy.read();
    if (old == null) return null;
    await _writeVerified(old);
    await _legacy.clear();
    return old;
  });

  @override
  Future<void> write(String token) => _serial(() async {
    await _writeVerified(token);
    await _legacy.clear();
  });

  @override
  Future<void> clear() => _serial(() async {
    await _legacy.clear();
    await _storage.delete(key: storageKey);
  });
}
