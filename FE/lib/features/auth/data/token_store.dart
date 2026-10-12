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
