import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/settings/presentation/pages/account_settings_pages.dart';
import 'package:fe/features/settings/presentation/account_settings_dependencies.dart';
import 'package:fe/features/profile/presentation/pages/my_page.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/photos/presentation/pages/photo_management_page.dart';
import '../../fakes/fake_account_settings.dart';
import '../../fakes/fake_profile_photo_repositories.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../profile/my_page_test.dart' show capture;

Widget app(Widget page, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  builder: (c, child) => MediaQuery(
    data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
    child: RepaintBoundary(key: const Key('capture'), child: child!),
  ),
  home: page,
);
void main() {
  setUpAll(() async {
    for (final f in {
      'CapstoneUI': 'CapstoneUI-Regular.ttf',
      'CapstoneUIMedium': 'CapstoneUI-Medium.ttf',
    }.entries) {
      await (FontLoader(
        f.key,
      )..addFont(rootBundle.load('assets/fonts/${f.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final scale in [1.0, 1.3]) {
    testWidgets('계정 정보 닉네임 저장·중복 오류와 안전 영역 $scale', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeAccountRepository();
      final deps = AccountSettingsDependencies(
        repository: repo,
        cleanup: () async {},
        onDeleted: () async {},
      );
      await tester.pumpWidget(
        app(AccountInfoPage(dependencies: deps), scale: scale),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'account-info-$scale');
      await tester.enterText(
        find.byKey(const Key('account-nickname')),
        '새 닉네임',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('닉네임 저장'));
      await tester.pumpAndSettle();
      expect(repo.user.nickname, '새 닉네임');
      repo.patchError = ApiRequestError(
        const ApiFailure(
          code: 'NICKNAME_DUPLICATED',
          message: '이미 사용 중인 닉네임이에요.',
          status: 409,
          fields: null,
        ),
      );
      await tester.tap(find.text('닉네임 저장'));
      await tester.pumpAndSettle();
      expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
      expect(find.text('닉네임 저장').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('동의 철회 확인·취소·재동의와 별도 사진 관리 $scale', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeAccountRepository();
      final deps = AccountSettingsDependencies(
        repository: repo,
        cleanup: () async {},
        onDeleted: () async {},
      );
      await tester.pumpWidget(
        app(
          PrivacySettingsPage(
            dependencies: deps,
            photos: FakePhotoRepository(),
            picker: FakePhotoPicker(),
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'account-privacy-$scale');
      await tester.tap(find.byType(SwitchListTile).last);
      await tester.pumpAndSettle();
      expect(find.textContaining('진행 중인 분석이 취소돼요.'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(repo.patches, isEmpty);
      await tester.tap(find.byType(SwitchListTile).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('철회'));
      await tester.pumpAndSettle();
      expect(repo.patches.last, {'ai_processing_agreed': false});
      await tester.tap(find.byType(SwitchListTile).last);
      await tester.pumpAndSettle();
      expect(repo.user.aiProcessingAgreed, true);
      await tester.scrollUntilVisible(find.text('사진 데이터 관리'), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 데이터 관리'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoManagementPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('탈퇴는 확인 체크와 최종 확인 후 수행하며 정리 실패만 재시도한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeAccountRepository();
    var fail = true, returned = false;
    final deps = AccountSettingsDependencies(
      repository: repo,
      cleanup: () async {
        if (fail) throw StateError('기기 정리 실패');
      },
      onDeleted: () async {
        returned = true;
      },
    );
    await tester.pumpWidget(
      app(DeleteAccountPage(dependencies: deps), scale: 1.3),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'account-delete-1.3');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-delete-submit')));
    await tester.pumpAndSettle();
    expect(repo.deletions, 0);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repo.deletions, 0);
    await tester.tap(find.byKey(const Key('account-delete-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();
    expect(repo.deletions, 1);
    expect(returned, false);
    expect(find.text('기기 정보 정리 다시 시도').hitTestable(), findsOneWidget);
    fail = false;
    await tester.tap(find.text('기기 정보 정리 다시 시도'));
    await tester.pumpAndSettle();
    expect(repo.deletions, 1);
    expect(returned, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('마이페이지 하위 화면 변경이 계정 헤더에 반영되고 기존 항목을 유지한다', (tester) async {
    final repo = FakeAccountRepository();
    final deps = AccountSettingsDependencies(
      repository: repo,
      cleanup: () async {},
      onDeleted: () async {},
    );
    await tester.pumpWidget(
      app(
        MyPage(
          onboarding: const OnboardingProgress(
            account: previewAccount,
            profile: previewProfile,
          ),
          profileRepository: FakeProfileRepository(),
          photoRepository: FakePhotoRepository(),
          photoPicker: FakePhotoPicker(),
          accountSettings: deps,
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('내 계정 정보'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 계정 정보'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('account-nickname')), '바뀐 이름');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('닉네임 저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('바뀐 이름'), findsOneWidget);
    expect(find.text('신체정보'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
