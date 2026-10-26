import 'package:fe/app/vitality_app.dart';
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

/// 테스트용 메일 서버가 마지막으로 받은 인증번호를 읽는다.
Future<String> _codeFor(String email) async {
  final res = await http.get(Uri.parse('$_mailPeekUrl/last?to=$email'));
  return res.body.trim();
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

Future<TokenStore> _openSignup(WidgetTester tester) async {
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
  await tester.tap(find.text('회원가입'));
  await tester.pumpAndSettle();
  return tokens;
}

Future<void> _requestCode(WidgetTester tester, String nickname, String email) async {
  await _enter(tester, 'signup-nickname', nickname);
  await _enter(tester, 'signup-email', email);
  await _tap(tester, find.text('인증번호 받기'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('실제 앱 화면에서 메일 인증번호 → 가입 → 설문 저장', (tester) async {
    final run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final email = 'it$run@example.com';
    final tokens = await _openSignup(tester);

    await _requestCode(tester, 'it$run'.substring(0, 8), email);
    expect(find.text('인증번호를 보냈어요'), findsOneWidget, reason: '서버가 메일을 보내면 안내 창이 떠야 한다');
    await _tap(tester, find.text('확인'));

    await _enter(tester, 'signup-code', '000000');
    await _enter(tester, 'signup-password', 'abcd1234');
    await _tap(tester, find.text('다음'));
    expect(find.text('인증번호가 일치하지 않아요.'), findsOneWidget, reason: '틀린 번호는 서버 문구가 보여야 한다');
    expect(find.text('필수 약관 동의'), findsNothing);

    await _enter(tester, 'signup-code', await _codeFor(email));
    await _tap(tester, find.text('다음'));
    expect(find.text('필수 약관 동의'), findsOneWidget);
    await _tap(tester, find.text('전체 동의'));
    await _tap(tester, find.text('동의하고 계속'));
    await _settleNetwork(tester);

    expect(find.text('신체 정보'), findsOneWidget, reason: '가입·로그인 직후 설문(신체정보) 화면으로 이동해야 한다');
    expect(await tokens.read(), isNotNull, reason: '로그인 토큰이 저장되어야 한다');

    await _enter(tester, 'profile-height', '175');
    await _enter(tester, 'profile-weight', '73.5');
    await _enter(tester, 'profile-age', '18');
    for (final label in ['남', '근육 키우기', '1년 이상']) {
      await _tap(tester, find.text(label));
    }
    await _tap(tester, find.text('4 ~ 5회'));
    await _tap(tester, find.text('다음'));
    await _settleNetwork(tester);

    expect(find.text('체형 분석'), findsOneWidget, reason: '신체정보 저장 후 체형분석 단계로 이동해야 한다');
  });

  testWidgets('이미 가입된 이메일은 인증번호 단계에서 서버 문구로 막힌다', (tester) async {
    final run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final email = 'dup$run@example.com';

    await _openSignup(tester);
    await _requestCode(tester, 'd1$run'.substring(0, 8), email);
    await _tap(tester, find.text('확인'));
    await _enter(tester, 'signup-code', await _codeFor(email));
    await _enter(tester, 'signup-password', 'abcd1234');
    await _tap(tester, find.text('다음'));
    await _tap(tester, find.text('전체 동의'));
    await _tap(tester, find.text('동의하고 계속'));
    await _settleNetwork(tester);
    expect(find.text('신체 정보'), findsOneWidget);

    await _openSignup(tester);
    await _requestCode(tester, 'd2$run'.substring(0, 8), email);
    expect(find.text('이미 가입된 이메일이에요.'), findsOneWidget);
    expect(find.text('인증번호를 보냈어요'), findsNothing);
  });
}
