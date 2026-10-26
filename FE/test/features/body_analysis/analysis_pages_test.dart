import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';
import 'package:fe/features/body_analysis/presentation/analysis_dependencies.dart';
import 'package:fe/features/body_analysis/presentation/pages/analysis_entry_page.dart';
import 'package:fe/features/body_analysis/presentation/pages/analysis_run_page.dart';
import 'package:fe/features/body_analysis/presentation/pages/analysis_history_page.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import '../../fakes/fake_analysis_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';
import '../../fakes/fake_home_repository.dart';
import '../profile/my_page_test.dart' show capture;

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
    testWidgets('분석 입력: 반응형 스크롤·글 분석 안내·기록 진입 $scale', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeAnalysisRepository();
      final dependencies = AnalysisDependencies(
        repository: repository,
        photos: FakePhotoRepository(),
        picker: FakePhotoPicker(),
        pending: MemoryAnalysisPendingStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const Key('capture'),
            child: AnalysisEntryPage(dependencies: dependencies),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('분석 시작'));
      await tester.pumpAndSettle();
      expect(find.text('체형 분석'), findsNothing);
      final buttonY = tester.getTopLeft(find.text('분석 시작')).dy;
      await tester.tap(find.text('분석 시작'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('분석 시작')).dy, buttonY);
      expect(repository.starts, 0);
      expect(find.text('정면 사진을 추가해 주세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(const Key('reference-content-scroll')),
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'analysis-input-$scale');
      await tester.ensureVisible(find.text('글로 설명하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('글로 설명하기'));
      await tester.pumpAndSettle();
      expect(find.text('글 분석 준비 중'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('분석 기록'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('분석 기록'));
      await tester.pumpAndSettle();
      expect(find.byType(AnalysisHistoryPage), findsOneWidget);
      expect(find.text('아직 분석 기록이 없어요.'), findsOneWidget);
    });
    testWidgets('분석 결과: null 표시와 명시적 루틴 생성·작은 화면 $scale', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeAnalysisRepository()
        ..response = result(AnalysisStatus.done);
      final dependencies = AnalysisDependencies(
        repository: repository,
        photos: FakePhotoRepository(),
        picker: FakePhotoPicker(),
        pending: MemoryAnalysisPendingStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const Key('capture'),
            child: AnalysisRunPage(id: 31, dependencies: dependencies),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('점수 산출 불가'), findsOneWidget);
      expect(find.text('측면 사진이 없어 측정하지 못했어요.'), findsOneWidget);
      expect(repository.generated, 0);
      await capture(tester, 'analysis-result-$scale');
      await tester.scrollUntilVisible(find.text('맞춤 루틴 만들기'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('맞춤 루틴 만들기'));
      await tester.pumpAndSettle();
      expect(repository.generated, 0);
      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();
      expect(repository.generated, 1);
      expect(repository.generatedId, 31);
      expect(find.text('상체 균형'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('홈 프로필 버튼은 알림 버튼과 같은 크기와 외곽선을 사용한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: const Key('capture'),
          child: HomePage(
            repository: FakeHomeRepository(),
            onOpenMyPage: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final profile = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == '마이페이지',
    );
    final bell = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == '알림',
    );
    expect(tester.getSize(profile), tester.getSize(bell));
    final a = tester.widget<IconButton>(profile),
        b = tester.widget<IconButton>(bell);
    expect(a.style!.side!.resolve({}), b.style!.side!.resolve({}));
    final person = tester.widget<SvgPicture>(
      find.descendant(of: profile, matching: find.byType(SvgPicture)),
    );
    final notification = tester.widget<SvgPicture>(
      find.descendant(of: bell, matching: find.byType(SvgPicture)),
    );
    expect(person.colorFilter, notification.colorFilter);
    expect(person.width, 20);
    expect(person.height, 20);
    await capture(tester, 'home-header-matched-icons');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
