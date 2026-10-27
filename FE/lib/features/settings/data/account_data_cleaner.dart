import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Only exact keys belonging to the departing account; never clear all preferences.
class AccountDataCleaner {
  AccountDataCleaner(this.owner, {SharedPreferencesAsync? preferences})
    : _provided = preferences;
  final String owner;
  final SharedPreferencesAsync? _provided;
  SharedPreferencesAsync get _prefs => _provided ?? SharedPreferencesAsync();
  Set<String> keysFor(Iterable<String> keys) {
    if (owner.trim().isEmpty) return {};
    final account = owner.trim().toLowerCase(),
        encoded = base64Url.encode(utf8.encode(account));
    final preview = 'vitality.home.preview.v1.$owner';
    final exact = {
      preview,
      '$preview.schedule',
      'vitality.home.weekly.v1.${base64Url.encode(utf8.encode(preview))}',
      'movid.analysis.pending.v1.$encoded',
      'movid.home.recommendation-choice.v1.$encoded',
    };
    return keys
        .where(
          (k) =>
              exact.contains(k) || k.startsWith('movid.workout.v1.$encoded.'),
        )
        .toSet();
  }

  Future<void> clear() async {
    if (owner.trim().isEmpty) return;
    final raw = await _prefs.getString('vitality.onboarding.preview.v1');
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map;
        final account = data['account'] as Map?;
        final email =
            (account?['email'] as String?)?.trim().toLowerCase() ?? '';
        final storedOwner = email.isNotEmpty
            ? email
            : account?['user_id'] == null
            ? ''
            : 'user:${account!['user_id']}';
        if (storedOwner == owner.trim().toLowerCase()) {
          await _prefs.remove('vitality.onboarding.preview.v1');
        }
      } on FormatException {
        /* Unknown legacy data is not deleted. */
      } on TypeError {
        /* Preserve data whose owner cannot be proved. */
      }
    }
    for (final key in keysFor(await _prefs.getKeys())) {
      await _prefs.remove(key);
    }
  }
}
