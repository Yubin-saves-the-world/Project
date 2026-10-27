import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/settings/data/account_data_cleaner.dart';
import 'account_settings_test.dart' show MemoryPreferences;

void main() {
  const key = 'vitality.onboarding.preview.v1';
  Map<String, dynamic> legacy(String email) => {
    'account': {'email': email},
    'analysis': {
      'front': {'path': '/app/onboarding_photos/front.jpg'},
      'side': {'path': '/app/onboarding_photos/front.jpg'},
      'goal': {'path': '/app/onboarding_photos/goal.jpg'},
    },
  };
  test('소유가 증명된 레거시 사진은 포인터를 지우기 전에 중복 없이 정리한다', () async {
    final prefs = MemoryPreferences()
      ..data[key] = jsonEncode(legacy('mine@example.com'));
    final removed = <String>[];
    await AccountDataCleaner(
      'mine@example.com',
      preferences: prefs,
      discardPhoto: (path) async {
        expect(prefs.data.containsKey(key), true);
        removed.add(path);
      },
    ).clear();
    expect(removed, [
      '/app/onboarding_photos/front.jpg',
      '/app/onboarding_photos/goal.jpg',
    ]);
    expect(prefs.data.containsKey(key), false);
  });
  test('사진 정리 실패 시 소유 정보가 남아 원격 탈퇴를 반복하지 않고 재시도할 수 있다', () async {
    final prefs = MemoryPreferences()
      ..data[key] = jsonEncode(legacy('mine@example.com'));
    var fail = true;
    final cleaner = AccountDataCleaner(
      'mine@example.com',
      preferences: prefs,
      discardPhoto: (_) async {
        if (fail) throw StateError('파일 정리 실패');
      },
    );
    await expectLater(cleaner.clear(), throwsStateError);
    expect(prefs.data.containsKey(key), true);
    fail = false;
    await cleaner.clear();
    expect(prefs.data.containsKey(key), false);
  });
  test('다른 계정·소유 불명 레거시는 파일과 포인터를 삭제하지 않는다', () async {
    final prefs = MemoryPreferences();
    var calls = 0;
    final cleaner = AccountDataCleaner(
      'mine@example.com',
      preferences: prefs,
      discardPhoto: (_) async {
        calls++;
      },
    );
    for (final raw in [
      jsonEncode(legacy('other@example.com')),
      'invalid json',
      jsonEncode({
        'analysis': {
          'front': {'path': 'unknown.jpg'},
        },
      }),
    ]) {
      prefs.data[key] = raw;
      await cleaner.clear();
      expect(prefs.data[key], raw);
    }
    expect(calls, 0);
  });
}
