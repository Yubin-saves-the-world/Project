import 'dart:convert';
import 'package:fe/app/onboarding/onboarding_view_model.dart';
import 'package:fe/app/router/route_paths.dart';
import 'package:fe/app/vitality_app.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/models/signup_request.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/auth/data/server_onboarding_repository.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/auth/presentation/pages/consent_page.dart';
import 'package:fe/features/profile/presentation/pages/profile_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../../fakes/fake_onboarding_repository.dart';

class RealCodeRepository extends FakeOnboardingRepository {
  @override
  bool get usesRealEmailVerification => true;
  int confirmations = 0;
  SignupRequest? received;
  @override
  Future<String> confirmEmailCode({
    required String email,
    required String code,
  }) async {
    confirmations++;
    if (code != '482916') throw StateError('인증번호가 일치하지 않아요.');
    return 'server-proof';
  }

  @override
  Future<OnboardingProgress> register(SignupRequest request) async {
    received = request;
    return super.register(request);
  }
}

const me = {
  'user_id': 1,
  'nickname': '유빈',
  'email': 'user@example.com',
  'role': 'user',
  'consent_completed': true,
  'body_photo_agreed': true,
  'ai_processing_agreed': true,
  'onboarding_completed': false,
  'created_at': '2026-10-25T12:00:00+09:00',
};
const profile = {
  'height_cm': 174.0,
  'weight_kg': 65.0,
  'age': 18,
  'gender': 'male',
  'goal_type': 'muscle',
  'weekly_frequency': 3,
  'experience_level': 'under3m',
};
http.Response json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

void main() {
  test('서버 모드는 고정 개발 코드가 아닌 확인 토큰으로 가입하고 재로그인 실패 시 중복 가입하지 않는다', () async {
    final repo = RealCodeRepository()..failLoginOnce = true;
    final model = OnboardingViewModel(
      repository: repo,
      photoPicker: FakePhotoPicker(),
    );
    await model.initialize();
    model.nickname = '유빈';
    model.email = 'USER@example.com';
    model.password = 'abcd1234';
    model.updateConsent(terms: true, privacy: true, photo: true, ai: true);
    expect(await model.sendVerification(), true);
    expect(
      await model.verifyEmailCode(model.email, '123456'),
      contains('일치하지'),
    );
    expect(await model.verifyEmailCode(model.email, '482916'), isNull);
    expect(await model.submitAccount(), false);
    expect(repo.received!.toJson()['email_verification_token'], 'server-proof');
    expect(await model.submitAccount(), true);
    expect(repo.accountWrites, 1);
    expect(repo.loginCalls, 2);
    model.dispose();
  });
  test('인증 토큰은 같은 이메일에서 재사용하고 30분 만료·이메일 변경 때 폐기한다', () async {
    var now = DateTime(2026, 10, 25);
    final repo = RealCodeRepository();
    final model = OnboardingViewModel(
      repository: repo,
      photoPicker: FakePhotoPicker(),
      now: () => now,
    );
    await model.initialize();
    model.email = 'user@example.com';
    model.nickname = '유빈';
    model.password = 'abcd1234';
    model.updateConsent(terms: true, privacy: true, photo: true, ai: true);
    expect(await model.verifyEmailCode(model.email, '482916'), isNull);
    expect(await model.verifyEmailCode(' USER@example.com ', '482916'), isNull);
    expect(repo.confirmations, 1);
    now = now.add(const Duration(minutes: 30));
    expect(await model.submitAccount(), false);
    expect(repo.accountWrites, 0);
    model.resetEmailVerification();
    expect(model.emailVerificationToken, isNull);
    model.email = 'other@example.com';
    expect(await model.submitAccount(), false);
    expect(repo.accountWrites, 0);
    model.dispose();
  });
  test('서버 첫 화면은 동의·설문·홈 완료 상태에 따라 복원된다', () async {
    for (final state in [(false, false), (true, false), (true, true)]) {
      final tokens = MemoryTokenStore();
      await tokens.write('tok');
      final repo = ServerOnboardingRepository(
        baseUrl: 'http://server.test',
        tokenStore: tokens,
        client: MockClient(
          (request) async => json(
            request.url.path.endsWith('/profile')
                ? profile
                : {
                    ...me,
                    'consent_completed': state.$1,
                    'onboarding_completed': state.$2,
                  },
          ),
        ),
      );
      final model = OnboardingViewModel(
        repository: repo,
        photoPicker: FakePhotoPicker(),
      );
      await model.initialize(startWithLogin: true);
      expect(model.showLogin, false);
      expect(model.progress.consentCompleted, state.$1);
      expect(model.progress.completed, state.$1 && state.$2);
      if (state.$1 && !state.$2) expect(model.step, 1);
      model.dispose();
    }
  });
  testWidgets('서버 동의 플래그가 false인 계정은 동의 화면에 진입한다', (tester) async {
    final tokens = MemoryTokenStore();
    await tokens.write('tok');
    final repo = ServerOnboardingRepository(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      client: MockClient(
        (_) async => json({...me, 'consent_completed': false}),
      ),
    );
    await tester.pumpWidget(
      VitalityApp(onboardingRepository: repo, photoPicker: FakePhotoPicker()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConsentPage), findsOneWidget);
    await tester.tap(find.text('동의 후 계속'));
    await tester.pumpAndSettle();
    // Mock intentionally keeps consent false: UI must not bypass the server flag.
    expect(find.byType(ConsentPage), findsOneWidget);
  });
  testWidgets('중첩 화면에서 세션이 만료되면 이전 페이지를 제거하고 로그인으로 이동한다', (tester) async {
    final tokens = MemoryTokenStore();
    await tokens.write('tok');
    final key = GlobalKey<NavigatorState>();
    var expire = false;
    late final ServerOnboardingRepository repo;
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      onSessionExpired: () async {
        repo.clearSessionData();
        key.currentState!.pushNamedAndRemoveUntil(
          RoutePaths.login,
          (_) => false,
        );
      },
      client: MockClient(
        (_) async => expire
            ? json({
                'code': 'UNAUTHORIZED',
                'message': '로그인이 필요해요.',
                'status': 401,
              }, 401)
            : json(me),
      ),
    );
    repo = ServerOnboardingRepository(
      baseUrl: 'http://server.test',
      apiClient: api,
    );
    await tester.pumpWidget(
      VitalityApp(
        navigatorKey: key,
        onboardingRepository: repo,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProfileFormPage), findsOneWidget);
    key.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('상세 화면')),
      ),
    );
    await tester.pumpAndSettle();
    expire = true;
    await expectLater(api.send('GET', '/api/users/me'), throwsStateError);
    await tester.pumpAndSettle();
    expect(await tokens.read(), isNull);
    expect(find.text('상세 화면'), findsNothing);
    expect(find.text('로그인'), findsWidgets);
    expect(key.currentState!.canPop(), false);
  });
  testWidgets('인증번호 발송의 중복 이메일 오류는 입력칸에 표시하고 이메일 수정 시 해제한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tokens = MemoryTokenStore();
    final repo = ServerOnboardingRepository(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      client: MockClient(
        (_) async => json({
          'code': 'EMAIL_DUPLICATED',
          'message': '이미 가입된 이메일이에요.',
          'status': 409,
        }, 409),
      ),
    );
    await tester.pumpWidget(
      VitalityApp(onboardingRepository: repo, photoPicker: FakePhotoPicker()),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byKey(const Key('signup-email')),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, 'user@example.com');
    await tester.ensureVisible(find.text('인증번호 받기'));
    await tester.tap(find.text('인증번호 받기'));
    await tester.pumpAndSettle();
    expect(find.text('이미 가입된 이메일이에요.'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(field).forceErrorText,
      '이미 가입된 이메일이에요.',
    );
    await tester.enterText(field, 'other@example.com');
    await tester.pumpAndSettle();
    expect(find.text('이미 가입된 이메일이에요.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
