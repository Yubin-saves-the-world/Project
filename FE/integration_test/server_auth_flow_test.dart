import 'package:fe/app/vitality_app.dart';
import 'package:fe/features/auth/data/server_onboarding_repository.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final keyed = find.byKey(Key(key));
  final field = tester.widget(keyed) is TextFormField
      ? keyed
      : find.descendant(of: keyed, matching: find.byType(TextFormField));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 20),
  );
}

Future<void> _settleNetwork(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('실제 앱 화면에서 가입 → 로그인 → 설문 저장 → 재로그인 시 홈', (tester) async {
    final run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final email = 'it$run@example.com';
    final nickname = 'it$run'.substring(0, 8);
    final tokens = MemoryTokenStore();

    Widget buildApp() => VitalityApp(
      onboardingRepository: ServerOnboardingRepository(
        baseUrl: _baseUrl,
        tokenStore: tokens,
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    await _enter(tester, 'signup-nickname', nickname);
    await _enter(tester, 'signup-email', email);
    await _tap(tester, find.text('인증번호 받기'));
    await _tap(tester, find.text('확인'));
    await _enter(tester, 'signup-code', '123456');
    await _enter(tester, 'signup-password', 'abcd1234');
    await _tap(tester, find.text('다음'));
    expect(find.text('필수 약관 동의'), findsOneWidget);
    await _tap(tester, find.text('전체 동의'));
    await _tap(tester, find.text('동의하고 계속'));
    await _settleNetwork(tester);

    expect(
      find.text('신체 정보'),
      findsOneWidget,
      reason: '가입·로그인 직후 설문(신체정보) 화면으로 이동해야 한다',
    );
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

    expect(
      find.text('체형 분석'),
      findsOneWidget,
      reason: '신체정보 저장 후 체형분석 단계로 이동해야 한다',
    );
  });

  testWidgets('이미 가입된 이메일로 가입하면 서버 문구가 화면에 보인다', (tester) async {
    final run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final email = 'dup$run@example.com';

    Future<void> signUp(String nickname) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        VitalityApp(
          onboardingRepository: ServerOnboardingRepository(
            baseUrl: _baseUrl,
            tokenStore: MemoryTokenStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('회원가입'));
      await tester.pumpAndSettle();
      await _enter(tester, 'signup-nickname', nickname);
      await _enter(tester, 'signup-email', email);
      await _tap(tester, find.text('인증번호 받기'));
      await _tap(tester, find.text('확인'));
      await _enter(tester, 'signup-code', '123456');
      await _enter(tester, 'signup-password', 'abcd1234');
      await _tap(tester, find.text('다음'));
      await _tap(tester, find.text('전체 동의'));
      await _tap(tester, find.text('동의하고 계속'));
      await _settleNetwork(tester);
    }

    await signUp('d1$run'.substring(0, 8));
    expect(find.text('신체 정보'), findsOneWidget);

    await signUp('d2$run'.substring(0, 8));
    expect(find.text('이미 가입된 이메일이에요.'), findsOneWidget);
    expect(find.text('신체 정보'), findsNothing);
  });
}
