import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AnalysisPendingStore {
  Future<int?> read();
  Future<void> write(int id);
  Future<void> clear(int id);
}

class MemoryAnalysisPendingStore implements AnalysisPendingStore {
  int? id;
  @override
  Future<int?> read() async => id;
  @override
  Future<void> write(int value) async {
    id = value;
  }

  @override
  Future<void> clear(int value) async {
    if (id == value) id = null;
  }
}

class PreferencesAnalysisPendingStore implements AnalysisPendingStore {
  PreferencesAnalysisPendingStore(
    String account, {
    SharedPreferencesAsync? preferences,
  }) : key =
           'movid.analysis.pending.v1.${base64Url.encode(utf8.encode(account.trim().toLowerCase()))}',
       _provided = preferences;
  final String key;
  final SharedPreferencesAsync? _provided;
  SharedPreferencesAsync get _prefs => _provided ?? SharedPreferencesAsync();
  @override
  Future<int?> read() async {
    final id = await _prefs.getInt(key);
    if (id != null && id <= 0) {
      throw StateError('진행 중인 분석 정보를 확인하지 못했어요. 기록에서 다시 확인해 주세요.');
    }
    return id;
  }

  @override
  Future<void> write(int id) => _prefs.setInt(key, id);
  @override
  Future<void> clear(int id) async {
    if (await read() == id) await _prefs.remove(key);
  }
}
