import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/features/home/data/home_preview_repository.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/app/shell/app_bottom_nav.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import '../fakes/fake_onboarding_repository.dart';
import '../fakes/fake_home_repository.dart';

void main() {
  setUpAll(() async {
    for (final font in ['Regular', 'Medium']) {
      await (FontLoader(
        font == 'Regular' ? 'CapstoneUI' : 'CapstoneUIMedium',
      )..addFont(rootBundle.load('assets/fonts/CapstoneUI-$font.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test('미리보기 기록 저장·복원·볼륨·연속일과 저장 실패', () async {
    final repo = FakeHomeRepository();
    final today = DateTime(2026, 10, 12);
    final m = HomeViewModel(repository: repo, today: today);
    await m.initialize();
    expect(await m.start(0), isTrue);
    expect(m.active, isNotNull);
    expect(await m.start(0), isTrue);
    expect(repo.workouts.length, 1);
    expect(await m.complete(20, 12, 4), isTrue);
    expect(m.volume, 960);
    expect(m.totalSets, 4);
    expect(m.doneCount, 1);
    expect(m.streak, 1);
    final restored = HomeViewModel(repository: repo, today: today);
    await restored.initialize();
    expect(restored.volume, 960);
    expect(restored.workoutDays, 1);
    repo.fail = true;
    expect(await restored.start(1), isFalse);
    expect(restored.active, isNull);
    expect(restored.volume, 960);
    m.dispose();
    restored.dispose();
  });
  test('이어하기 복원과 휴식일, 중단하지 않은 기록은 볼륨 집계 제외', () async {
    final today = DateTime(2026, 10, 12);
    final repo = FakeHomeRepository()
      ..workouts = [
        PreviewWorkout(
          date: today,
          exercise: 1,
          startedAt: today.add(const Duration(hours: 11)),
        ),
      ];
    final m = HomeViewModel(repository: repo, today: today, frequency: 1);
    await m.initialize();
    expect(m.active!.exercise, 1);
    expect(m.volume, 0);
    expect(m.streak, 0);
    expect(m.planned(today), isTrue);
    expect(m.planned(today.add(const Duration(days: 1))), isFalse);
    m.dispose();
  });
  testWidgets('홈 디자인과 날짜 선택·루틴 시작·완료·기록 요약', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
          body: HomePage(
            onboarding: const OnboardingProgress(
              account: previewAccount,
              profile: previewProfile,
            ),
            repository: FakeHomeRepository(),
            today: DateTime(2026, 10, 12),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('화요일 · 10월 13일'), findsNothing);
    expect(find.byTooltip('알림'), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-홈')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-weekday-1')));
    await tester.pumpAndSettle();
    expect(find.text('선택한 날은 휴식일'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-weekday-0')));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 루틴'), findsOneWidget);
    expect(find.text('예시'), findsNothing);
    expect(find.text('일정 수정'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/frontend-architecture/previews/home.png'),
    );
    await tester.tap(find.text('운동 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('바벨 스쿼트').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('preview-무게(kg)')), '20');
    await tester.ensureVisible(find.text('종목 완료'));
    await tester.tap(find.text('종목 완료'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4종목 완료'), findsOneWidget);
    await tester.ensureVisible(find.text('보기'));
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    expect(find.text('총 볼륨 960kg'), findsOneWidget);
  });
  testWidgets('홈의 작은 화면·큰 글꼴에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
          body: HomePage(
            repository: FakeHomeRepository(),
            today: DateTime(2026, 10, 12),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
