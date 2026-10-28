import 'package:fe/features/profile/data/profile_avatar_store.dart';
import '../settings/account_settings_test.dart' show MemoryPreferences;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/profile/presentation/pages/my_page.dart';
import 'package:fe/features/profile/presentation/pages/profile_edit_page.dart';
import 'package:fe/features/photos/presentation/pages/photo_management_page.dart';
import 'package:fe/features/profile/data/models/body_profile.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_MANAGEMENT')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/project-context/previews/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final font in {
      'CapstoneUI': 'CapstoneUI-Regular.ttf',
      'CapstoneUIMedium': 'CapstoneUI-Medium.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final scale in [1.0, 1.3]) {
    testWidgets('마이페이지 진입·수정·사진 관리와 $scale배 글꼴', (tester) async {
      tester.view.physicalSize = Size(
        scale == 1.0 ? 393 : 320,
        scale == 1.0 ? 852 : 640,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final profile = FakeProfileRepository()..refresh = true;
      final photos = FakePhotoRepository();
      BodyProfile? saved;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: MyPage(
              avatarStore: ProfileAvatarStore(
                previewAccount.storageOwner,
                preferences: MemoryPreferences(),
              ),
              onboarding: const OnboardingProgress(
                account: previewAccount,
                profile: editableProfile,
              ),
              profileRepository: profile,
              photoRepository: photos,
              photoPicker: FakePhotoPicker(),
              onProfileSaved: (p) => saved = p,
              onLogout: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('마이페이지'), findsOneWidget);
      expect(find.text('주 4회'), findsOneWidget);
      await capture(tester, scale == 1.0 ? 'my-page' : 'my-page-large-text');
      await tester.tap(find.text('신체정보'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditPage), findsOneWidget);
      await capture(
        tester,
        scale == 1.0 ? 'profile-edit' : 'profile-edit-large-text',
      );
      final weight = find.byKey(const Key('profile-weight'));
      await tester.ensureVisible(weight);
      await tester.enterText(weight, '70.5');
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      expect(find.text('맞춤 루틴을 새로 만들까요?'), findsOneWidget);
      expect(saved!.weightKg, 70.5);
      await tester.tap(find.text('나중에'));
      await tester.pumpAndSettle();
      expect(find.textContaining('70.5kg'), findsOneWidget);
      await tester.ensureVisible(find.text('사진 데이터 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사진 데이터 관리'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoManagementPage), findsOneWidget);
      await capture(
        tester,
        scale == 1.0 ? 'photo-management' : 'photo-management-large-text',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
