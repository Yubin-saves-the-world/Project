import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../routines/data/models/routine.dart';

abstract interface class RecommendationChoiceStore {
  Future<Map<String, int>> read();
  Future<void> write(Map<String, int> choices);
}

class PreferencesRecommendationChoiceStore
    implements RecommendationChoiceStore {
  PreferencesRecommendationChoiceStore(String account)
    : key =
          'movid.home.recommendation-choice.v1.${base64Url.encode(utf8.encode(account.trim().toLowerCase()))}';
  final String key;
  SharedPreferencesAsync get _prefs => SharedPreferencesAsync();
  @override
  Future<Map<String, int>> read() async {
    final raw = await _prefs.getString(key);
    if (raw == null) return {};
    final choices = Map<String, int>.from(jsonDecode(raw) as Map);
    for (final entry in choices.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null ||
          routineDateKey(date) != entry.key ||
          entry.value <= 0) {
        throw const FormatException('잘못된 추천 선택 정보');
      }
    }
    return choices;
  }

  @override
  Future<void> write(Map<String, int> choices) =>
      _prefs.setString(key, jsonEncode(choices));
}
