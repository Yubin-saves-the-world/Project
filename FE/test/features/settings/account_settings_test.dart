import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/auth/data/models/auth_session.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/settings/data/account_repository.dart';
import 'package:fe/features/settings/data/account_data_cleaner.dart';
import 'package:fe/features/settings/data/consent_request_guard.dart';
import 'package:fe/features/settings/presentation/account_settings_view_model.dart';
import 'package:fe/features/settings/presentation/account_settings_dependencies.dart';
import '../../fakes/fake_account_settings.dart';

class MemoryPreferences implements SharedPreferencesAsync {
  final data = <String, Object>{};
  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async =>
      data.keys.toSet();
  @override
  Future<String?> getString(String key) async => data[key] as String?;
  @override
  Future<void> remove(String key) async {
    data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('닉네임 응답 손실은 재조회한 값이 같으면 중복 PATCH 없이 성공한다', () async {
    final repo = FakeAccountRepository();
    final m = AccountSettingsViewModel(
      AccountSettingsDependencies(
        repository: repo,
        cleanup: () async {},
        onDeleted: () async {},
      ),
    );
    await m.load();
    repo.patchError = StateError('response lost');
    expect(await m.rename('새 닉네임'), false);
    repo.patchError = null;
    repo.user = CurrentUser.fromJson(accountJson(nickname: '새 닉네임'));
    expect(await m.rename('새 닉네임'), true);
    expect(repo.reads, 2);
    expect(repo.patches.length, 1);
    m.dispose();
  });
  test('닉네임 재조회 실패는 초안을 덮거나 다시 쓰지 않고 다음 저장에서 복구한다', () async {
    final repo = FakeAccountRepository();
    final m = AccountSettingsViewModel(
      AccountSettingsDependencies(
        repository: repo,
        cleanup: () async {},
        onDeleted: () async {},
      ),
    );
    await m.load();
    repo.patchError = StateError('network');
    expect(await m.rename('새 닉네임'), false);
    repo.patchError = null;
    repo.loadError = StateError('still offline');
    expect(await m.rename('새 닉네임'), false);
    expect(repo.patches.length, 1);
    repo.loadError = null;
    expect(await m.rename('새 닉네임'), true);
    expect(repo.patches.length, 2);
    expect(m.user!.nickname, '새 닉네임');
    m.dispose();
  });
  test('내 정보 API는 GET/PATCH/DELETE와 최소 수정 필드만 전송한다', () async {
    final calls = <http.Request>[];
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      client: MockClient((q) async {
        calls.add(q);
        expect(q.headers['Authorization'], 'Bearer token');
        return q.method == 'DELETE'
            ? http.Response('', 204)
            : http.Response.bytes(utf8.encode(jsonEncode(accountJson())), 200);
      }),
    );
    final repo = ServerAccountRepository(api);
    expect((await repo.load()).nickname, '유빈');
    await repo.update({'nickname': '수정닉네임'});
    expect(calls.last.method, 'PATCH');
    expect(calls.last.url.path, '/api/users/me');
    expect(jsonDecode(calls.last.body), {'nickname': '수정닉네임'});
    await repo.delete();
    expect(calls.last.method, 'DELETE');
    expect(calls.last.url.path, '/api/users/me');
    api.dispose();
  });
  test('닉네임 범위·중복 오류와 동의 변경의 서버 확정 값을 반영한다', () async {
    final repo = FakeAccountRepository();
    var changes = 0;
    final m = AccountSettingsViewModel(
      AccountSettingsDependencies(
        repository: repo,
        cleanup: () async {},
        onDeleted: () async {},
        onChanged: (_) => changes++,
      ),
    );
    await m.load();
    expect(await m.rename('가'), false);
    expect(repo.patches, isEmpty);
    repo.patchError = ApiRequestError(
      const ApiFailure(
        code: 'NICKNAME_DUPLICATED',
        message: '이미 사용 중인 닉네임이에요.',
        status: 409,
        fields: null,
      ),
    );
    expect(await m.rename('다른 이름'), false);
    expect(m.nicknameError, isNotNull);
    expect(m.canWrite, true);
    repo.patchError = null;
    expect(await m.rename('  새 이름  '), true);
    expect(m.user!.nickname, '새 이름');
    await m.consent(photo: false);
    expect(repo.patches.last, {'body_photo_agreed': false});
    expect(m.user!.bodyPhotoAgreed, false);
    expect(m.user!.aiProcessingAgreed, true);
    expect(changes, 3);
    m.dispose();
  });
  test('응답이 불확실한 동의 변경은 재조회 전 재전송하지 않는다', () async {
    final repo = FakeAccountRepository();
    final m = AccountSettingsViewModel(
      AccountSettingsDependencies(
        repository: repo,
        cleanup: () async {},
        onDeleted: () async {},
      ),
    );
    await m.load();
    repo.patchError = StateError('통신 실패');
    await m.consent(ai: false);
    expect(m.user!.aiProcessingAgreed, true);
    expect(m.canWrite, false);
    repo.patchError = null;
    repo.user = CurrentUser.fromJson(accountJson(ai: false));
    await m.load();
    expect(m.user!.aiProcessingAgreed, false);
    expect(m.canWrite, true);
    m.dispose();
  });
  test('탈퇴는 원격 삭제→기기 정리→로그인 복귀 순서이며 정리 실패만 재시도한다', () async {
    final repo = FakeAccountRepository();
    final order = <String>[];
    var fail = true;
    final m = AccountSettingsViewModel(
      AccountSettingsDependencies(
        repository: repo,
        cleanup: () async {
          order.add('cleanup');
          expect(repo.deletions, 1);
          if (fail) throw StateError('기기 정리 실패');
        },
        onDeleted: () async {
          order.add('login');
        },
      ),
    );
    await m.load();
    expect(await m.removeAccount(), false);
    expect(m.serverDeleted, true);
    expect(m.deleted, false);
    expect(repo.deletions, 1);
    fail = false;
    expect(await m.removeAccount(), true);
    expect(repo.deletions, 1);
    expect(order, ['cleanup', 'cleanup', 'login']);
    expect(m.deleted, true);
    m.dispose();
  });
  test('서버 탈퇴 실패 시 기기 정보·토큰 정리를 실행하지 않는다', () async {
    final repo = FakeAccountRepository()..deleteError = StateError('서버 오류');
    var cleanup = 0;
    final m = AccountSettingsViewModel(
      AccountSettingsDependencies(
        repository: repo,
        cleanup: () async {
          cleanup++;
        },
        onDeleted: () async {},
      ),
    );
    await m.load();
    expect(await m.removeAccount(), false);
    expect(cleanup, 0);
    expect(m.serverDeleted, false);
    expect(m.needsReload, true);
    m.dispose();
  });
  test('계정별 키·운동 초안만 정리하고 다른 계정·앱 설정은 보존한다', () async {
    final prefs = MemoryPreferences();
    final owner = 'user@example.com', other = 'other@example.com';
    String enc(String s) => base64Url.encode(utf8.encode(s));
    final preview = 'vitality.home.preview.v1.$owner';
    final own = {
      preview,
      '$preview.schedule',
      'vitality.home.weekly.v1.${enc(preview)}',
      'movid.analysis.pending.v1.${enc(owner)}',
      'movid.home.recommendation-choice.v1.${enc(owner)}',
      'movid.workout.v1.${enc(owner)}.87',
    };
    for (final key in own) {
      prefs.data[key] = 'private';
    }
    prefs.data['movid.workout.v1.${enc(other)}.87'] = 'other';
    prefs.data['theme'] = 'dark';
    prefs.data['vitality.onboarding.preview.v1'] = jsonEncode({
      'account': {'email': owner},
    });
    await AccountDataCleaner(owner, preferences: prefs).clear();
    expect(own.any(prefs.data.containsKey), false);
    expect(prefs.data['theme'], 'dark');
    expect(prefs.data['movid.workout.v1.${enc(other)}.87'], 'other');
    expect(prefs.data.containsKey('vitality.onboarding.preview.v1'), false);
    prefs.data['vitality.onboarding.preview.v1'] = jsonEncode({
      'account': {'email': other},
    });
    await AccountDataCleaner(owner, preferences: prefs).clear();
    expect(prefs.data.containsKey('vitality.onboarding.preview.v1'), true);
  });
  test('동의 철회는 새 업로드·AI 쓰기만 차단하고 기존 조회·삭제·재동의는 허용한다', () async {
    var account = const OnboardingAccount(
      nickname: '유빈',
      email: 'user@example.com',
      bodyPhotoAgreed: false,
      aiProcessingAgreed: false,
    );
    final guard = ConsentRequestGuard(() => account);
    final calls = <String>[];
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: MemoryTokenStore(),
      client: MockClient((q) async {
        calls.add(q.method);
        return http.Response('{}', 200);
      }),
    )..beforeAuthorizedRequest = guard.check;
    for (final path in [
      '/api/photos',
      '/api/body-analyses/photo',
      '/api/routines',
      '/api/goal-bodies',
    ]) {
      await expectLater(
        api.send('POST', path),
        throwsA(
          isA<ApiRequestError>().having(
            (e) => e.code,
            'code',
            'CONSENT_REQUIRED',
          ),
        ),
      );
    }
    await expectLater(
      api.upload('/api/photos', files: []),
      throwsA(isA<ApiRequestError>()),
    );
    expect(calls, isEmpty);
    await api.send('GET', '/api/body-analyses');
    await api.send('GET', '/api/workout-logs');
    await api.send('DELETE', '/api/photos/1');
    await api.send(
      'PATCH',
      '/api/users/me',
      body: {'ai_processing_agreed': true},
    );
    await api.send('POST', '/api/auth/login', authorized: false);
    expect(calls.length, 5);
    account = const OnboardingAccount(
      nickname: '유빈',
      email: 'user@example.com',
      bodyPhotoAgreed: true,
      aiProcessingAgreed: true,
    );
    await api.send('POST', '/api/body-analyses/photo');
    expect(calls.last, 'POST');
    api.dispose();
  });
  test('이메일 없는 계정은 서버 user_id로 기기 데이터를 구분한다', () async {
    const a = OnboardingAccount(
          userId: 7,
          nickname: '카카오',
          email: '',
          bodyPhotoAgreed: true,
          aiProcessingAgreed: true,
        ),
        b = OnboardingAccount(
          userId: 8,
          nickname: '다른 계정',
          email: '',
          bodyPhotoAgreed: true,
          aiProcessingAgreed: true,
        );
    expect(a.storageOwner, 'user:7');
    expect(b.storageOwner, 'user:8');
    expect(OnboardingAccount.fromJson(a.toJson()).userId, 7);
    final prefs = MemoryPreferences();
    String key(String owner) =>
        'movid.workout.v1.${base64Url.encode(utf8.encode(owner))}.1';
    prefs.data[key(a.storageOwner)] = 'mine';
    prefs.data[key(b.storageOwner)] = 'other';
    await AccountDataCleaner(a.storageOwner, preferences: prefs).clear();
    expect(prefs.data.containsKey(key(a.storageOwner)), false);
    expect(prefs.data[key(b.storageOwner)], 'other');
  });
}
