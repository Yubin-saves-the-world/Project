import '../../auth/data/local_nickname_registry.dart';
import '../../profile/data/profile_avatar_store.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Only exact keys belonging to the departing account; never clear all preferences.
class AccountDataCleaner {
  AccountDataCleaner(
    this.owner, {
    SharedPreferencesAsync? preferences,
    this.discardPhoto,
  }) : _provided = preferences;
  final String owner;
  final Future<void> Function(String path)? discardPhoto;
  final SharedPreferencesAsync? _provided;
  SharedPreferencesAsync get _prefs => _provided ?? SharedPreferencesAsync();
  Set<String> keysFor(Iterable<String> keys) {
    if (owner.trim().isEmpty) return {};
    final account = owner.trim().toLowerCase(),
        encoded = base64Url.encode(utf8.encode(account));
    final preview = 'vitality.home.preview.v1.$owner';
    final exact = {
      ProfileAvatarStore.keyFor(owner),
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

  List<String>? _ownedLegacyPhotos(String raw) {
    final dynamic data;
    try {
      data = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (data is! Map || data['account'] is! Map) return null;
    final account = data['account'] as Map;
    final email = account['email'] is String
        ? (account['email'] as String).trim().toLowerCase()
        : '';
    final id = account['user_id'];
    final storedOwner = email.isNotEmpty
        ? email
        : id is int
        ? 'user:$id'
        : '';
    if (storedOwner.isEmpty || storedOwner != owner.trim().toLowerCase()) {
      return null;
    }
    final analysis = data['analysis'];
    if (analysis is! Map) return [];
    return {
      for (final slot in ['front', 'side', 'goal'])
        if (analysis[slot] is Map && (analysis[slot] as Map)['path'] is String)
          (analysis[slot] as Map)['path'] as String,
    }.toList();
  }

  Future<void> clear() async {
    if (owner.trim().isEmpty) return;
    final raw = await _prefs.getString('vitality.onboarding.preview.v1');
    final photos = raw == null ? null : _ownedLegacyPhotos(raw);
    if (photos != null) {
      // Keep ownership evidence until photo removal succeeds so cleanup is retryable.
      for (final path in photos) {
        await discardPhoto?.call(path);
      }
      await _prefs.remove('vitality.onboarding.preview.v1');
    }
    await LocalNicknameRegistry(_prefs).removeOwner(owner);
    for (final key in keysFor(await _prefs.getKeys())) {
      await _prefs.remove(key);
    }
  }
}
