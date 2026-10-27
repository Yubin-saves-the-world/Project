import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Separate per-account/per-log recovery data. Existing local workout data stays intact.
abstract interface class WorkoutDraftStore {
  Future<Map<String, dynamic>> read(int logId);
  Future<void> write(int logId, Map<String, dynamic> draft);
}

class PreferencesWorkoutDraftStore implements WorkoutDraftStore {
  PreferencesWorkoutDraftStore(String account)
    : prefix =
          'movid.workout.v1.${base64Url.encode(utf8.encode(account.trim().toLowerCase()))}';
  final String prefix;
  SharedPreferencesAsync get _prefs => SharedPreferencesAsync();
  @override
  Future<Map<String, dynamic>> read(int logId) async {
    final raw = await _prefs.getString('$prefix.$logId');
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<void> write(int logId, Map<String, dynamic> draft) =>
      _prefs.setString('$prefix.$logId', jsonEncode(draft));
}
