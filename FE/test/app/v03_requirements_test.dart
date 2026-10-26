import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/app/onboarding/onboarding_view_model.dart';
import 'package:fe/features/auth/data/development_email_verification.dart';
import 'package:fe/features/profile/presentation/pages/profile_form_page.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../fakes/fake_onboarding_repository.dart';

class FailedLoginRepository extends FakeOnboardingRepository {
  bool wrong = true, network = false;
  @override
  Future<OnboardingProgress> login({
    required String email,
    required String password,
  }) async {
    if (network) throw StateError('서버에 연결하지 못했어요.');
    if (wrong) throw StateError('이메일 또는 비밀번호를 확인해 주세요.');
    return super.login(email: email, password: password);
  }
}

void main() {
  test('재요청은 60초 간격·시간당 5회이고 이메일 변경으로 한도가 초기화되지 않는다', () {
    var now = DateTime(2026, 10, 14);
    final verification = DevelopmentEmailVerification(now: () => now);
    verification.issue('USER@example.com');
    expect(() => verification.issue('user@example.com'), throwsStateError);
    now = now.add(const Duration(seconds: 60));
    for (var i = 1; i < 5; i++) {
      verification.issue('user@example.com');
      now = now.add(const Duration(seconds: 60));
    }
    expect(verification.requestError('user@example.com'), contains('시간당 5회'));
    verification.clear();
    expect(() => verification.issue('user@example.com'), throwsStateError);
    now = DateTime(2026, 10, 14, 1);
    verification.issue('user@example.com');
    expect(verification.remaining, const Duration(minutes: 5));
    now = now.add(const Duration(minutes: 5));
    expect(verification.validate('user@example.com', '123456'), contains('만료'));
  });
  test('인증 실패 5회에 찾기를 안내하며 네트워크 오류는 횟수에 포함하지 않는다', () async {
    final repository = FailedLoginRepository();
    final model = OnboardingViewModel(
      repository: repository,
      photoPicker: FakePhotoPicker(),
    );
    await model.initialize(startWithLogin: true);
    for (var i = 0; i < 4; i++) {
      await model.login('user@example.com', 'abcd1234');
    }
    expect(model.suggestPasswordReset, isFalse);
    repository.network = true;
    await model.login('user@example.com', 'abcd1234');
    expect(model.loginFailures, 4);
    repository.network = false;
    await model.login('user@example.com', 'abcd1234');
    expect(model.suggestPasswordReset, isTrue);
    repository.wrong = false;
    await model.login('user@example.com', 'abcd1234');
    expect(model.loginFailures, 0);
    model.dispose();
  });
  testWidgets('신체정보는 3단계이고 뒤로 이동해도 입력을 유지하며 6+는 6으로 저장한다', (tester) async {
    final repository = FakeOnboardingRepository(
      const OnboardingProgress(account: previewAccount),
    );
    final model = OnboardingViewModel(
      repository: repository,
      photoPicker: FakePhotoPicker(),
    );
    await model.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfileFormPage(model: model),
      ),
    );
    await tester.pumpAndSettle();
    for (final item in [('height', '170'), ('weight', '65.5'), ('age', '18')]) {
      await tester.enterText(find.byKey(Key('profile-${item.$1}')), item.$2);
    }
    await tester.tap(find.text('남'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.text('근육 키우기'));
    await tester.tap(find.text('6+'));
    await tester.tap(find.byKey(const Key('reference-back')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('profile-height')))
          .controller!
          .text,
      '170',
    );
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(model.frequency, 6);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(repository.progress.profile, isNull);
    await tester.tap(find.text('3개월 미만'));
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(repository.progress.profile!.weeklyFrequency, 6);
    expect(repository.progress.profile!.weightKg, 65.5);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
