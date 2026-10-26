import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/features/home/presentation/pages/weekly_routine_editor.dart';
import 'package:fe/features/home/presentation/widgets/server_records_day.dart';
import 'package:fe/features/home/presentation/home_server_dependencies.dart';
import 'package:fe/features/home/data/models/weekly_schedule.dart';
import '../../fakes/fake_home_repository.dart';
import '../../fakes/fake_home_server.dart';
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
    testWidgets('내 운동 기본 유지·추천 교체 확인·서버 기록 달력과 $scale배 글꼴', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final manual = FakeHomeRepository(emptySchedule: true)
        ..weeklySchedule = WeeklySchedule(
          dates: {
            '2026-10-26': DayRoutine(
              title: '내 운동',
              items: [const RoutineItem(exercise: 0, sets: 4, reps: 10)],
            ),
          },
        );
      final routines = FakeHomeRoutines();
      final api = FakeHomeServer(routines)..completed = [serverWorkout(87)];
      final choices = FakeChoiceStore();
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
            child: HomePage(
              today: DateTime(2026, 10, 26),
              repository: manual,
              server: HomeServerDependencies(
                repository: api,
                routines: routines,
                choices: choices,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('내 운동 · 1종목'), findsOneWidget);
      await tester.ensureVisible(find.text('추천 루틴으로 교체'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('추천 루틴으로 교체'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('내 운동 유지'));
      await tester.pumpAndSettle();
      expect(choices.choices, isEmpty);
      await tester.tap(find.text('추천 루틴으로 교체'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '추천 루틴으로 교체'));
      await tester.pumpAndSettle();
      expect(choices.choices, {'2026-10-26': 44});
      expect(find.text('상체 균형'), findsOneWidget);
      expect(
        manual.weeklySchedule!.forDate(DateTime(2026, 10, 26))!.title,
        '내 운동',
      );
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 2000),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'home-server-$scale');
      await tester.ensureVisible(find.text('보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('보기'));
      await tester.pumpAndSettle();
      expect(find.byType(ServerRecordsDay), findsOneWidget);
      expect(find.text('서버에 저장된 기록'), findsOneWidget);
      expect(find.text('바벨 스쿼트'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('휴식일 해제 복원 실패는 일정 편집으로 이어진다', (tester) async {
    final local = FakeHomeRepository(emptySchedule: true)
      ..weeklySchedule = WeeklySchedule(
        dates: {'2026-10-26': DayRoutine.rest()},
      );
    final routines = FakeHomeRoutines()..failRestore = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          today: DateTime(2026, 10, 26),
          repository: local,
          server: HomeServerDependencies(
            repository: FakeHomeServer(routines),
            routines: routines,
            choices: FakeChoiceStore(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('운동일로 변경'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('운동일로 변경'));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyRoutineEditor), findsOneWidget);
    expect(local.weeklySchedule!.forDate(DateTime(2026, 10, 26))!.rest, true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('신규 사용자는 분석으로 유도하고 서버 실패를 0개 기록으로 표시하지 않는다', (tester) async {
    final routines = FakeHomeRoutines()..data.clear();
    final api = FakeHomeServer(routines)..analyses = 0;
    var analyses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          today: DateTime(2026, 10, 26),
          repository: FakeHomeRepository(emptySchedule: true),
          onOpenAnalysis: () => analyses++,
          server: HomeServerDependencies(
            repository: api,
            routines: routines,
            choices: FakeChoiceStore(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('체형 분석하고 루틴 받기'));
    expect(analyses, 1);
    await tester.pumpWidget(const SizedBox());
    api.error = StateError('네트워크 오류');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          today: DateTime(2026, 10, 26),
          repository: FakeHomeRepository(emptySchedule: true),
          server: HomeServerDependencies(
            repository: api,
            routines: routines,
            choices: FakeChoiceStore(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('네트워크 오류'), findsWidgets);
    expect(find.textContaining('0개 완료 기록'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
