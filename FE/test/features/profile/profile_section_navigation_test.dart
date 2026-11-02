import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/profile/presentation/pages/my_page.dart';
import 'package:fe/features/profile/presentation/pages/profile_edit_page.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';

void main() {
  for (final section in ProfileFormSection.values) {
    testWidgets('${section.label}은 해당 단계로 바로 이동하고 뒤로가면 마이페이지다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MyPage(
            onboarding: const OnboardingProgress(
              account: previewAccount,
              profile: editableProfile,
            ),
            profileRepository: FakeProfileRepository(),
            photoRepository: FakePhotoRepository(),
            photoPicker: FakePhotoPicker(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(section.label));
      await tester.tap(find.text(section.label));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProfileEditPage>(find.byType(ProfileEditPage))
            .initialSection,
        section,
      );
      expect(find.text('${section.stage + 1} / 3'), findsOneWidget);
      if (section != ProfileFormSection.body) {
        final target = find.byKey(ValueKey('profile-choice-${section.label}'));
        expect(target, findsOneWidget);
        expect(
          tester.getRect(target).bottom,
          lessThanOrEqualTo(tester.view.physicalSize.height),
        );
      }
      await tester.tap(find.byKey(const Key('reference-back')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditPage), findsNothing);
      expect(find.byType(MyPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
