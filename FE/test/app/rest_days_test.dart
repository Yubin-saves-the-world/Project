import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../fakes/fake_home_repository.dart';

void main() {
  test('휴식일 지정과 해제는 재시작 후 유지되고 운동 기록은 보존된다', () async {
    final day = DateTime(2026, 10, 14);
    final repository = FakeHomeRepository();
    final model = HomeViewModel(repository: repository, today: day);
    await model.initialize();
    expect(model.planned(day), isTrue);
    expect(await model.start(0), isTrue);
    expect(await model.setRestDay(day, rest: true), isFalse);
    expect(model.planned(day), isTrue);
    expect(await model.complete(20, 10, 3), isTrue);
    expect(await model.setRestDay(day, rest: true), isTrue);
    expect(model.planned(day), isFalse);
    expect(model.completed.length, 1);
    expect(await model.start(1), isFalse);
    final restored = HomeViewModel(repository: repository, today: day);
    await restored.initialize();
    expect(restored.planned(day), isFalse);
    expect(restored.volume, 600);
    expect(await restored.setRestDay(day, rest: false), isTrue);
    expect(restored.planned(day), isTrue);
    expect(await restored.start(1), isTrue);
    model.dispose();
    restored.dispose();
  });
  test('원래 휴식일도 운동일로 전환하며 저장 실패는 반영하지 않는다', () async {
    final day = DateTime(2026, 10, 12);
    final repository = FakeHomeRepository();
    final model = HomeViewModel(
      repository: repository,
      today: day,
      frequency: 1,
    );
    await model.initialize();
    final tomorrow = day.add(const Duration(days: 1));
    expect(model.planned(tomorrow), isFalse);
    expect(
      await model.saveRoutine(
        tomorrow,
        DayRoutine(
          title: '직접 루틴',
          items: const [RoutineItem(exercise: 0, sets: 3, reps: 10)],
        ),
        repeat: false,
      ),
      isTrue,
    );
    expect(model.planned(tomorrow), isTrue);
    repository.failSchedule = true;
    expect(await model.setRestDay(tomorrow, rest: true), isFalse);
    expect(model.planned(tomorrow), isTrue);
    expect(repository.weeklySchedule!.forDate(tomorrow)!.rest, isFalse);
    expect(
      await model.setRestDay(day.subtract(const Duration(days: 1)), rest: true),
      isFalse,
    );
    expect(repository.weeklySchedule!.dates.length, 1);
    model.dispose();
  });
  test('손상된 일정은 기존 기록을 덮어쓰지 않고 재시도를 요구한다', () async {
    final repository = FakeHomeRepository()
      ..dayOverrides = {'2026-02-31': true};
    final model = HomeViewModel(
      repository: repository,
      today: DateTime(2026, 10, 12),
    );
    await model.initialize();
    expect(model.loaded, isFalse);
    expect(await model.start(0), isFalse);
    expect(repository.writes, 0);
    model.dispose();
  });
  testWidgets('월·화를 포함한 모든 요일은 편집 화면에서 휴식일로 저장할 수 있다', (tester) async {
    final repository = FakeHomeRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(repository: repository, today: DateTime(2026, 10, 14)),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      final weekday = find.byKey(ValueKey('home-weekday-$i'));
      await tester.ensureVisible(weekday);
      await tester.tap(weekday);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('home-rest-toggle')));
      await tester.tap(find.byKey(const Key('home-rest-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('휴식일').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('routine-save')));
      await tester.tap(find.byKey(const Key('routine-save')));
      await tester.pumpAndSettle();
      final next = DateTime(2026, 10, 19 + i);
      expect(repository.weeklySchedule!.forDate(next)!.rest, isTrue);
    }
    expect(repository.workouts, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
