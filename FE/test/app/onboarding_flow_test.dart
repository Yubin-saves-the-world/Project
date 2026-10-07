import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/app/vitality_app.dart';
import 'package:fe/app/router/route_paths.dart';
import 'package:fe/app/onboarding/onboarding_view_model.dart';
import 'package:fe/features/body_analysis/presentation/pages/onboarding_analysis_page.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/profile/presentation/pages/profile_form_page.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/ui/core/widgets/design_reference_page.dart';

import '../fakes/fake_onboarding_repository.dart';

Future<void> enter(WidgetTester tester, String key, String text) async {
  final keyed = find.byKey(Key(key));
  final field = tester.widget(keyed) is TextFormField
      ? keyed
      : find.descendant(of: keyed, matching: find.byType(TextFormField));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'CapstoneUIMedium',
    )..addFont(rootBundle.load('assets/fonts/CapstoneUI-Medium.ttf'))).load();
    await (FontLoader(
      'CapstoneUI',
    )..addFont(rootBundle.load('assets/fonts/CapstoneUI-Regular.ttf'))).load();
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('개발용 인증·동의·범위 상한 저장·텍스트 입력 후 가입 완료', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeOnboardingRepository();
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    await enter(tester, 'signup-nickname', '유빈');
    await enter(tester, 'signup-email', 'yubin@example.com');
    await tester.tap(find.text('인증번호 받기'));
    await tester.pumpAndSettle();
    expect(find.text('개발용 이메일 인증'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await enter(tester, 'signup-code', '000000');
    await enter(tester, 'signup-password', 'password123');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(repository.progress.account, isNull);
    await enter(tester, 'signup-code', '123456');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('필수 약관 동의'), findsOneWidget);
    expect(repository.progress.account, isNull);
    await tester.tap(find.text('전체 동의'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의하고 계속'));
    await tester.pumpAndSettle();
    expect(find.text('신체 정보'), findsOneWidget);
    await enter(tester, 'profile-height', '174');
    await enter(tester, 'profile-weight', '68');
    await enter(tester, 'profile-age', '20');
    for (final label in ['남', '근육 키우기', '3개월 미만']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('4 ~ 5회'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('다음'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(repository.progress.profile!.weeklyFrequency, 5);
    expect(find.text('체형 분석'), findsOneWidget);
    await tester.tap(find.text('글로 설명하기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('analysis-text')),
      '어깨가 앞으로 굽는 느낌이 있어요.',
    );
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('분석 시작'));
    await tester.tap(find.text('분석 시작'));
    await tester.pumpAndSettle();
    expect(find.text('유빈님, 반가워요.'), findsOneWidget);
    expect(repository.progress.completed, isTrue);
  });

  testWidgets('인증번호 없이 가입되지 않고 뒤로 이동하면 초안을 유지한다', (tester) async {
    final repository = FakeOnboardingRepository();
    await tester.pumpWidget(
      VitalityApp(
        initialRoute: RoutePaths.signup,
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    await enter(tester, 'signup-nickname', '유빈');
    await enter(tester, 'signup-email', 'yubin@example.com');
    await enter(tester, 'signup-password', 'password123');
    await tester.ensureVisible(find.text('다음'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('인증번호 6자리를 입력해 주세요.'), findsOneWidget);
    expect(repository.progress.account, isNull);
    expect(find.byType(ReferenceField), findsNWidgets(4));
  });

  testWidgets('로그아웃 실패 재시도와 앱 재실행 시 로그인 화면 유지', (tester) async {
    final repository = FakeOnboardingRepository(
      const OnboardingProgress(
        account: previewAccount,
        profile: previewProfile,
        completed: true,
      ),
    );
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    repository.failNext = true;
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그아웃하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(repository.progress.completed, isTrue);
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('로그인'), findsOneWidget);
    expect(repository.progress.account, isNotNull);
    expect(repository.progress.signedIn, isFalse);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    await enter(tester, 'login-email', 'yubin@example.com');
    await enter(tester, 'login-password', 'password123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('유빈님, 반가워요.'), findsOneWidget);
    expect(repository.progress.signedIn, isTrue);
  });

  testWidgets('기존 미동의 데이터는 홈보다 동의 화면을 먼저 표시한다', (tester) async {
    final repository = FakeOnboardingRepository(
      OnboardingProgress(
        account: OnboardingAccount(
          nickname: '유빈',
          email: 'yubin@example.com',
          bodyPhotoAgreed: false,
          aiProcessingAgreed: false,
        ),
        profile: previewProfile,
        completed: true,
      ),
    );
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('필수 동의 확인'), findsOneWidget);
    expect(find.text('유빈님, 반가워요.'), findsNothing);
    expect(repository.progress.consentCompleted, isFalse);
    await tester.tap(find.text('[필수] 신체 사진 이용'));
    await tester.tap(find.text('[필수] AI 처리'));
    await tester.tap(find.text('동의 후 계속'));
    await tester.pumpAndSettle();
    expect(repository.progress.consentCompleted, isTrue);
    expect(find.text('유빈님, 반가워요.'), findsOneWidget);
  });

  testWidgets('첫 화면은 로그인, 가입 화면의 뒤로 이동과 초안 유지', (tester) async {
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: FakeOnboardingRepository(),
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    await enter(tester, 'signup-nickname', '유빈');
    await tester.ensureVisible(find.byKey(const Key('reference-back')));
    await tester.tap(find.byKey(const Key('reference-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byKey(const Key('signup-nickname')),
      matching: find.byType(TextFormField),
    );
    expect(tester.widget<TextFormField>(field).controller!.text, '유빈');
  });

  testWidgets('로그인 실패 시 입력을 유지하고 키보드 완료로 재시도한다', (tester) async {
    final repository = FakeOnboardingRepository(
      const OnboardingProgress(
        account: previewAccount,
        profile: previewProfile,
        completed: true,
        signedIn: false,
      ),
    );
    repository.failLoginOnce = true;
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    await enter(tester, 'login-email', 'yubin@example.com');
    await enter(tester, 'login-password', '1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('로그인을 다시 시도해 주세요.'), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const Key('login-password')),
      matching: find.byType(TextFormField),
    );
    expect(tester.widget<TextFormField>(field).controller!.text, '1');
    await tester.tap(field);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('유빈님, 반가워요.'), findsOneWidget);
  });

  testWidgets('성별 미선택은 없고 소셜 로그인은 준비 안내만 제공한다', (tester) async {
    final repository = FakeOnboardingRepository();
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('구글로 계속하기'));
    await tester.tap(find.text('구글로 계속하기'));
    await tester.pumpAndSettle();
    expect(find.text('구글 로그인 준비 중'), findsOneWidget);
    expect(repository.loginCalls, 0);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: FakeOnboardingRepository(
          const OnboardingProgress(account: previewAccount),
        ),
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('남'), findsOneWidget);
    expect(find.text('여'), findsOneWidget);
    expect(find.text('선택 안 함'), findsNothing);
    expect(find.text('미선택'), findsNothing);
  });

  for (final modal in [
    'google',
    'forgot',
    'otp',
    'consent',
    'photos',
    'goal',
    'source',
    'text',
  ]) {
    testWidgets('$modal: 추가 창도 현재 디자인으로 렌더한다', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = OnboardingViewModel(
        repository: FakeOnboardingRepository(
          const OnboardingProgress(
            account: previewAccount,
            profile: previewProfile,
          ),
        ),
        photoPicker: FakePhotoPicker(),
      );
      await model.initialize();
      addTearDown(model.dispose);
      if (['photos', 'goal', 'source', 'text'].contains(modal)) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: OnboardingAnalysisPage(model: model, onCompleted: () {}),
          ),
        );
      } else {
        await tester.pumpWidget(
          VitalityApp(
            onboardingRepository: FakeOnboardingRepository(),
            photoPicker: FakePhotoPicker(),
          ),
        );
      }
      await tester.pumpAndSettle();
      switch (modal) {
        case 'google':
          await tester.tap(find.text('구글로 계속하기'));
        case 'forgot':
          await tester.tap(find.text('비밀번호 찾기'));
        case 'otp':
          await tester.tap(find.text('회원가입'));
          await tester.pumpAndSettle();
          await enter(tester, 'signup-email', 'yubin@example.com');
          await tester.tap(find.text('인증번호 받기'));
        case 'consent':
          await tester.tap(find.text('회원가입'));
          await tester.pumpAndSettle();
          await enter(tester, 'signup-nickname', '유빈');
          await enter(tester, 'signup-email', 'yubin@example.com');
          await tester.tap(find.text('인증번호 받기'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('확인'));
          await tester.pumpAndSettle();
          await enter(tester, 'signup-code', '123456');
          await enter(tester, 'signup-password', 'password123');
          await tester.tap(find.text('다음'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('전체 동의'));
        case 'photos':
          await tester.tap(find.text('사진으로 분석'));
        case 'goal':
          await tester.tap(find.text('목표 체형 사진'));
        case 'source':
          await tester.tap(find.text('사진으로 분석'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byKey(const Key('front-photo')),
              matching: find.text('사진 추가'),
            ),
          );
        case 'text':
          await tester.tap(find.text('글로 설명하기'));
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      final target = modal == 'otp'
          ? find.byType(AlertDialog)
          : modal == 'consent'
          ? find.byType(BottomSheet)
          : find.byType(MaterialApp);
      await expectLater(
        target,
        matchesGoldenFile(
          '../../docs/frontend-architecture/previews/modals/$modal.png',
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('신체정보 카드 전체를 눌러 직접 입력하고 입력값을 저장한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeOnboardingRepository(
      const OnboardingProgress(account: previewAccount),
    );
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    for (final item in [('height', '170'), ('weight', '65'), ('age', '18')]) {
      final field = tester.widget<TextFormField>(
        find.byKey(Key('profile-${item.$1}')),
      );
      expect(field.controller!.text, isEmpty);
      final input = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(Key('profile-${item.$1}')),
          matching: find.byType(TextField),
        ),
      );
      expect(input.decoration!.hintText, item.$2);
      expect(input.decoration!.hintStyle!.color, ReferenceStyle.muted);
    }
    expect(tester.getTopLeft(find.byType(FilledButton)).dy, 758);
    for (final item in [
      ('height', '키', '174'),
      ('weight', '몸무게', '68.5'),
      ('age', '나이', '20'),
    ]) {
      await tester.tap(find.text(item.$2));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(Key('profile-${item.$1}')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(find.byKey(Key('profile-${item.$1}')), item.$3);
      await tester.pumpAndSettle();
    }
    final model = tester
        .widget<ProfileFormPage>(find.byType(ProfileFormPage))
        .model;
    expect(model.height, '174');
    expect(model.weight, '68.5');
    expect(model.age, '20');
    expect(model.gender, isNull);
    expect(model.goalType, isNull);
    expect(model.frequency, isNull);
    expect(model.experienceLevel, isNull);
    expect(find.text('주 운동 횟수'), findsOneWidget);
    expect(find.text('운동 기간'), findsOneWidget);
    for (final label in ['남', '근육 키우기', '2 ~ 3회', '3개월 미만']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('다음'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(repository.progress.profile!.heightCm, 174);
    expect(repository.progress.profile!.weightKg, 68.5);
    expect(repository.progress.profile!.age, 20);
    expect(tester.getTopLeft(find.byType(FilledButton)).dy, 758);
  });

  testWidgets('미선택 안내는 각 항목 아래에 표시되고 선택하면 사라진다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeOnboardingRepository(
      const OnboardingProgress(account: previewAccount),
    );
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    await enter(tester, 'profile-height', '174');
    await enter(tester, 'profile-weight', '68');
    await enter(tester, 'profile-age', '20');
    await tester.ensureVisible(find.text('다음'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(FilledButton)).dy, 758);
    expect(find.text('다음').hitTestable(), findsOneWidget);
    expect(repository.progress.profile, isNull);
    for (final item in [
      ('성별', '남'),
      ('운동 목적', '근육 키우기'),
      ('주 운동 횟수', '2 ~ 3회'),
      ('운동 기간', '3개월 미만'),
    ]) {
      final section = find.byKey(ValueKey('profile-choice-${item.$1}'));
      final error = find.descendant(
        of: section,
        matching: find.text(
          '${item.$1}${item.$1 == '주 운동 횟수' ? '를' : '을'} 선택해 주세요.',
        ),
      );
      expect(error, findsOneWidget);
      expect(
        tester.getTopLeft(error).dy,
        greaterThan(
          tester
              .getBottomLeft(
                find.descendant(of: section, matching: find.byType(Row)),
              )
              .dy,
        ),
      );
      await tester.ensureVisible(find.text(item.$2));
      await tester.tap(find.text(item.$2));
      await tester.pumpAndSettle();
      expect(error, findsNothing);
    }
    await tester.ensureVisible(find.text('다음'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(repository.progress.profile, isNotNull);
  });

  testWidgets('숫자와 선택 항목 오류가 동시에 있어도 다음 버튼 위치를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: FakeOnboardingRepository(
          const OnboardingProgress(account: previewAccount),
        ),
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byType(FilledButton));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(FilledButton)), before);
    expect(find.text('다음').hitTestable(), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(FilledButton)), before);
    expect(find.text('다음').hitTestable(), findsOneWidget);
  });

  testWidgets('재실행한 로그아웃 상태에서 가입하면 이전 계정 입력을 표시하지 않는다', (tester) async {
    final repository = FakeOnboardingRepository(
      const OnboardingProgress(
        account: previewAccount,
        profile: previewProfile,
        completed: true,
        signedIn: false,
      ),
    );
    await tester.pumpWidget(
      VitalityApp(
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    for (final key in [
      'signup-nickname',
      'signup-email',
      'signup-code',
      'signup-password',
    ]) {
      final field = tester.widget<TextFormField>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(TextFormField),
        ),
      );
      expect(field.controller!.text, isEmpty);
    }
    expect(repository.progress.account, previewAccount);
    expect(repository.progress.profile, previewProfile);
  });

  testWidgets('체형 분석 오류와 스크롤에도 분석 시작 버튼 위치를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final model = OnboardingViewModel(
      repository: FakeOnboardingRepository(
        const OnboardingProgress(
          account: previewAccount,
          profile: previewProfile,
        ),
      ),
      photoPicker: FakePhotoPicker(),
    );
    await model.initialize();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AnimatedBuilder(
          animation: model,
          builder: (context, _) =>
              OnboardingAnalysisPage(model: model, onCompleted: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byType(FilledButton));
    expect(before.dy, 758);
    await tester.tap(find.text('분석 시작'));
    await tester.pumpAndSettle();
    expect(find.text('정면 사진을 추가해 주세요. 측면과 목표 사진은 선택이에요.'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(FilledButton)), before);
    expect(find.text('분석 시작').hitTestable(), findsOneWidget);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    final smallBefore = tester.getTopLeft(find.byType(FilledButton));
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(FilledButton)), smallBefore);
    expect(find.text('분석 시작').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  final snapshots = <String, OnboardingProgress>{
    'signup': const OnboardingProgress(),
    'login': const OnboardingProgress(
      account: previewAccount,
      profile: previewProfile,
      completed: true,
      signedIn: false,
    ),
    'profile': const OnboardingProgress(account: previewAccount),
    'analysis': const OnboardingProgress(
      account: previewAccount,
      profile: previewProfile,
    ),
  };
  for (final entry in snapshots.entries) {
    testWidgets('${entry.key}: 393×852 화면 렌더', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (entry.key == 'analysis') {
        final model = OnboardingViewModel(
          repository: FakeOnboardingRepository(entry.value),
          photoPicker: FakePhotoPicker(),
        );
        await model.initialize();
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: OnboardingAnalysisPage(model: model, onCompleted: () {}),
          ),
        );
      } else {
        await tester.pumpWidget(
          VitalityApp(
            initialRoute: entry.key == 'signup'
                ? RoutePaths.signup
                : RoutePaths.login,
            onboardingRepository: FakeOnboardingRepository(entry.value),
            photoPicker: FakePhotoPicker(),
          ),
        );
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../docs/frontend-architecture/previews/${entry.key}.png',
        ),
      );
    });
    testWidgets('${entry.key}: 작은 화면·큰 글꼴·키보드에서도 넘치지 않는다', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (entry.key == 'analysis') {
        final model = OnboardingViewModel(
          repository: FakeOnboardingRepository(entry.value),
          photoPicker: FakePhotoPicker(),
        );
        await model.initialize();
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: OnboardingAnalysisPage(model: model, onCompleted: () {}),
          ),
        );
      } else {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: VitalityApp(
              initialRoute: entry.key == 'signup'
                  ? RoutePaths.signup
                  : RoutePaths.login,
              onboardingRepository: FakeOnboardingRepository(entry.value),
              photoPicker: FakePhotoPicker(),
            ),
          ),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
