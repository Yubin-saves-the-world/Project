import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/app/shell/main_shell.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/community/data/local_community_repository.dart';
import 'package:fe/features/community/presentation/community_controller.dart';
import 'package:fe/features/community/presentation/community_detail_page.dart';
import 'package:fe/features/community/presentation/community_widgets.dart';
import 'package:fe/features/community/presentation/community_safety_pages.dart';
import 'package:fe/features/profile/presentation/pages/my_page.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';
import 'community_repository_test.dart' show NoPicker, draft;

void main() {
  testWidgets('커뮤니티 프로필과 내 게시글 프로필은 마이페이지로 연결되고 차단 관리를 연다', (tester) async {
    final repo = LocalCommunityRepository(() => '유빈');
    final post = await repo.save(draft());
    final deps = CommunityDependencies(
      repository: repo,
      picker: NoPicker(),
      preview: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainShell(
          initialIndex: 4,
          onboarding: const OnboardingProgress(
            account: previewAccount,
            profile: editableProfile,
          ),
          profileRepository: FakeProfileRepository(),
          photoRepository: FakePhotoRepository(),
          photoPicker: FakePhotoPicker(),
          community: deps,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-menu')), findsNothing);
    await tester.tap(find.byKey(const Key('community-profile')));
    await tester.pumpAndSettle();
    expect(find.byType(MyPage), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('차단한 사용자 관리'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('차단한 사용자 관리'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityBlocksPage), findsOneWidget);
    expect(find.text('차단한 사용자가 없어요.'), findsOneWidget);
    Navigator.pop(tester.element(find.byType(CommunityBlocksPage)));
    await tester.pumpAndSettle();
    Navigator.pop(tester.element(find.byType(MyPage)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(ValueKey('community-card-${post.id}')),
    );
    await tester.tap(find.text(post.title));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityDetailPage), findsOneWidget);
    await tester.tap(find.byType(CommunityAvatar).first);
    await tester.pumpAndSettle();
    expect(find.byType(MyPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
