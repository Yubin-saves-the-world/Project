import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/data/home_preview_repository.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/features/home/presentation/pages/workout_calendar_page.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../fakes/fake_home_repository.dart';

void main() {
  testWidgets('홈 요약에서 달력으로 이동하고 날짜별 모든 완료 기록을 조회한다', (tester) async {
    final today = DateTime(2026, 10, 14);
    final repo = FakeHomeRepository()
      ..workouts = [
        for (final exercise in [0, 1])
          PreviewWorkout(
            date: DateTime(2026, 10, 13),
            exercise: exercise,
            startedAt: DateTime(2026, 10, 13, 10),
            completed: true,
            weight: 20,
            reps: 10,
            sets: 3,
          ),
        PreviewWorkout(
          date: DateTime(2026, 10, 13),
          exercise: 2,
          startedAt: DateTime(2026, 10, 13, 10),
          aborted: true,
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(repository: repo, today: today),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('이번 주'), findsNothing);
    expect(find.text('오늘로'), findsNothing);
    expect(find.text('선택한 날짜 기록 보기'), findsNothing);
    await tester.ensureVisible(find.text('보기'));
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutCalendarPage), findsOneWidget);
    expect(find.text('완료한 운동 기록이 없어요.'), findsOneWidget);
    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    calendar.onDateChanged(DateTime(2026, 10, 13));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('루마니안 데드리프트'));
    expect(find.text('바벨 스쿼트'), findsOneWidget);
    expect(find.text('루마니안 데드리프트'), findsOneWidget);
    expect(find.text('레그 프레스'), findsNothing);
    expect(find.text('20.0kg · 10회 · 3세트'), findsNWidgets(2));
    expect(find.text('2종목 · 6세트 · 총 볼륨 1200kg'), findsOneWidget);
    expect(repo.writes, 0);
    Navigator.of(tester.element(find.byType(WorkoutCalendarPage))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('보기'));
    expect(find.text('10월 14일'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('달력의 작은 화면과 큰 글꼴에서 날짜별 기록을 스크롤할 수 있다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          repository: FakeHomeRepository(),
          today: DateTime(2026, 10, 14),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('보기'));
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('완료한 운동 기록이 없어요.'));
    expect(tester.takeException(), isNull);
  });
}
