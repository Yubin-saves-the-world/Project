import 'package:fe/app/vitality_app.dart';
import 'package:fe/features/auth/data/models/signup_request.dart';
import 'package:fe/features/auth/data/server_onboarding_repository.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);
const _mailPeekUrl = String.fromEnvironment(
  'MAIL_PEEK_URL',
  defaultValue: 'http://localhost:18025',
);

Future<String> _codeFor(String email) async {
  final res = await http.get(Uri.parse('$_mailPeekUrl/last?to=$email'));
  return res.body.trim();
}

Future<String> _newCodeFor(String email, String previous) async {
  for (var i = 0; i < 60; i++) {
    final code = await _codeFor(email);
    if (code.isNotEmpty && code != previous) return code;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError('새 인증번호 메일이 오지 않았어요.');
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final keyed = find.byKey(Key(key));
  final field = tester.widget(keyed) is TextFormField
      ? keyed
      : find.descendant(of: keyed, matching: find.byType(TextFormField));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _settleNetwork(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settleNetwork(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('실제 앱 화면에서 비밀번호 찾기 → 새 비밀번호로 로그인', (tester) async {
    final run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final email = 'pw$run@example.com';
    const oldPassword = 'abcd1234';
    const newPassword = 'newpass99';

    final seed = ServerOnboardingRepository(
      baseUrl: _baseUrl,
      tokenStore: MemoryTokenStore(),
    );
    await seed.sendEmailCode(email);
    final signupCode = await _codeFor(email);
    final verified = await seed.confirmEmailCode(email: email, code: signupCode);
    await seed.register(SignupRequest(
      nickname: 'pw$run'.substring(0, 8),
      email: email,
      password: oldPassword,
      termsAgreed: true,
      privacyAgreed: true,
      bodyPhotoAgreed: true,
      aiProcessingAgreed: true,
      emailVerificationToken: verified,
    ));

    final tokens = MemoryTokenStore();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: ServerOnboardingRepository(
          baseUrl: _baseUrl,
          tokenStore: tokens,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tap(tester, find.text('비밀번호 찾기'));
    expect(find.text('가입한 이메일로 인증번호를 보내드려요.\n번호를 확인한 뒤 새 비밀번호를 정해 주세요.'), findsOneWidget,
        reason: '서버 연결 화면은 링크가 아니라 인증번호 안내를 보여야 한다');

    await _enter(tester, 'reset-email', email);
    await _tap(tester, find.text('인증번호 받기'));
    expect(find.text('인증번호를 보냈어요'), findsOneWidget);
    expect(find.textContaining('개발용'), findsNothing);
    await _tap(tester, find.text('확인'));

    final code = await _newCodeFor(email, signupCode);
    await _enter(tester, 'reset-code', code == '000000' ? '111111' : '000000');
    await _enter(tester, 'reset-password', newPassword);
    await _tap(tester, find.text('비밀번호 변경'));
    expect(find.text('인증번호가 일치하지 않아요.'), findsOneWidget, reason: '틀린 번호는 서버 문구가 보여야 한다');
    expect(find.text('비밀번호가 변경됐어요'), findsNothing);

    await _enter(tester, 'reset-code', code);
    await _tap(tester, find.text('비밀번호 변경'));
    expect(find.text('비밀번호가 변경됐어요'), findsOneWidget);

    await _tap(tester, find.text('로그인하러 가기'));
    await _enter(tester, 'login-email', email);
    await _enter(tester, 'login-password', oldPassword);
    await _tap(tester, find.byKey(const Key('login-submit')));
    expect(find.text('이메일 또는 비밀번호가 올바르지 않아요.'), findsOneWidget, reason: '옛 비밀번호는 거부되어야 한다');

    await _enter(tester, 'login-email', email);
    await _enter(tester, 'login-password', newPassword);
    await _tap(tester, find.byKey(const Key('login-submit')));
    await _settleNetwork(tester);
    expect(find.text('신체 정보'), findsOneWidget, reason: '새 비밀번호로 로그인하면 설문 화면으로 가야 한다');
    expect(await tokens.read(), isNotNull);
  });
}
