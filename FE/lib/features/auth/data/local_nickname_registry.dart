import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 모드에서 이 기기에 등록한 계정끼리만 중복을 방지한다.
class LocalNicknameRegistry {
  LocalNicknameRegistry(this.preferences);
  final SharedPreferencesAsync preferences;
  static const key = 'movid.local.nicknames.v1';
  static final _waiters = Queue<Completer<void>>();
  Future<T> _locked<T>(Future<T> Function() action) async {
    final gate = Completer<void>.sync();
    _waiters.add(gate);
    if (_waiters.length > 1) await gate.future;
    try {
      return await action();
    } finally {
      _waiters.removeFirst();
      if (_waiters.isNotEmpty) _waiters.first.complete();
    }
  }

  Future<Map<String, String>> _read() async {
    final raw = await preferences.getString(key);
    if (raw == null) return {};
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data.values.any((v) => v is! String)) {
        throw const FormatException();
      }
      return Map<String, String>.from(data);
    } catch (_) {
      throw StateError('닉네임 정보를 읽지 못했어요. 다시 시도해 주세요.');
    }
  }

  Future<T> save<T>(
    String owner,
    String nickname,
    Future<T> Function() persist,
  ) => _locked(() async {
    final name = nickname.trim(), account = owner.trim().toLowerCase();
    if (account.isEmpty || name.runes.length < 2 || name.runes.length > 20) {
      throw StateError('닉네임은 2~20자로 입력해 주세요.');
    }
    final old = await _read();
    if (old.entries.any(
      (e) =>
          e.key != account &&
          e.value.trim().toLowerCase() == name.toLowerCase(),
    )) {
      throw StateError('이미 사용 중인 닉네임이에요.');
    }
    await preferences.setString(key, jsonEncode({...old, account: name}));
    try {
      return await persist();
    } catch (_) {
      await preferences.setString(key, jsonEncode(old));
      rethrow;
    }
  });
  Future<void> removeOwner(String owner) => _locked(() async {
    final names = await _read();
    if (names.remove(owner.trim().toLowerCase()) != null) {
      await preferences.setString(key, jsonEncode(names));
    }
  });
}
