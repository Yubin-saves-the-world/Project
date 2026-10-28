import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/features/home/presentation/pages/weekly_routine_editor.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../fakes/fake_home_repository.dart';

DayRoutine routine([String title = '상체 운동', int exercise = 4]) => DayRoutine(
  title: title,
  items: [RoutineItem(exercise: exercise, sets: 2, reps: 8)],
);

void main() {
  test('첫 진입에는 임의 루틴이 없고 요일 루틴이 다음 주와 재실행에 반복된다', () async {
    final repository = FakeHomeRepository(emptySchedule: true);
    final today = DateTime(2026, 10, 14);
    final model = HomeViewModel(
      repository: repository,
      today: today,
      frequency: 5,
    );
    await model.initialize();
    expect(model.hasSchedule, isFalse);
    expect(model.week.every((day) => model.routineFor(day) == null), isTrue);
    expect(await model.start(0), isFalse);
    expect(await model.saveRoutine(today, routine(), repeat: true), isTrue);
    expect(model.planned(today.add(const Duration(days: 7))), isTrue);
    expect(
      model.routineFor(today.add(const Duration(days: 7)))!.items.single.sets,
      2,
    );
    final restored = HomeViewModel(
      repository: repository,
      today: today.add(const Duration(days: 14)),
    );
    await restored.initialize();
    expect(restored.selectedRoutine!.title, '상체 운동');
    expect(await restored.start(4), isTrue);
    expect(restored.active!.sets, 2);
    expect(restored.active!.reps, 8);
    expect(await restored.start(0), isFalse);
    model.dispose();
    restored.dispose();
  });
  test('첫 월요일 설정은 선택한 주에 표시하고 이후 변경은 다음 월요일부터 적용한다', () async {
    final model = HomeViewModel(
      repository: FakeHomeRepository(emptySchedule: true),
      today: DateTime(2026, 10, 14),
    );
    await model.initialize();
    final monday = DateTime(2026, 10, 12);
    await model.saveRoutine(monday, routine('월요일 운동'), repeat: true);
    expect(model.routineFor(monday)!.title, '월요일 운동');
    await model.saveRoutine(monday, routine('바뀐 월요일 운동'), repeat: true);
    expect(model.routineFor(monday)!.title, '월요일 운동');
    expect(model.routineFor(DateTime(2026, 10, 19))!.title, '바뀐 월요일 운동');
    model.dispose();
  });
  test('이번 날짜의 휴식일은 반복 일정과 기록을 바꾸지 않고 이후 변경은 과거에 적용되지 않는다', () async {
    final repository = FakeHomeRepository(emptySchedule: true);
    final today = DateTime(2026, 10, 14);
    final model = HomeViewModel(repository: repository, today: today);
    await model.initialize();
    await model.saveRoutine(today, routine(), repeat: true);
    await model.start(4);
    expect(
      await model.saveRoutine(today, DayRoutine.rest(), repeat: false),
      isFalse,
    );
    await model.complete(20, 8, 2);
    final tomorrowWeek = today.add(const Duration(days: 7));
    expect(
      await model.saveRoutine(tomorrowWeek, DayRoutine.rest(), repeat: false),
      isTrue,
    );
    expect(model.routineFor(tomorrowWeek)!.rest, isTrue);
    expect(
      model.routineFor(today.add(const Duration(days: 14)))!.rest,
      isFalse,
    );
    expect(
      await model.saveRoutine(
        today.add(const Duration(days: 14)),
        routine('등 운동', 5),
        repeat: true,
      ),
      isTrue,
    );
    expect(model.routineFor(today)!.title, '상체 운동');
    expect(
      model.routineFor(today.add(const Duration(days: 21)))!.title,
      '등 운동',
    );
    expect(model.completed.single.volume, 320);
    expect(model.completed.single.exercise, 4);
    model.dispose();
  });
  test('저장 실패·잘못된 종목은 기존 일정을 보존하고 JSON으로 복원한다', () async {
    final repository = FakeHomeRepository(emptySchedule: true);
    final model = HomeViewModel(
      repository: repository,
      today: DateTime(2026, 10, 14),
    );
    await model.initialize();
    await model.saveRoutine(model.today, routine(), repeat: true);
    repository.failSchedule = true;
    expect(
      await model.saveRoutine(model.today, DayRoutine.rest(), repeat: true),
      isFalse,
    );
    expect(model.selectedRoutine!.title, '상체 운동');
    expect(
      await model.saveRoutine(
        model.today,
        routine('잘못된 운동', 999),
        repeat: true,
      ),
      isFalse,
    );
    final restored = WeeklySchedule.fromJson(
      jsonDecode(jsonEncode(model.schedule.toJson())) as Map<String, dynamic>,
    );
    restored.validate(HomeViewModel.exercises.length);
    expect(restored.forDate(model.today)!.items.single.exercise, 4);
    model.dispose();
  });
  test('예전 휴식일 설정과 운동 기록은 보존하지만 자동 루틴은 새로 만들지 않는다', () async {
    final repository = FakeHomeRepository(emptySchedule: true)
      ..dayOverrides = {'2026-10-12': true, '2026-10-13': false};
    final model = HomeViewModel(
      repository: repository,
      today: DateTime(2026, 10, 14),
    );
    await model.initialize();
    expect(model.routineFor(DateTime(2026, 10, 12))!.rest, isTrue);
    expect(model.routineFor(DateTime(2026, 10, 13)), isNull);
    expect(model.planned(model.today), isFalse);
    expect(repository.dayOverrides.length, 2);
    model.dispose();
  });
  testWidgets('빈 홈에서 종목과 세트·횟수를 직접 정한 후 운동을 시작한다', (tester) async {
    final repository = FakeHomeRepository(emptySchedule: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(repository: repository, today: DateTime(2026, 10, 14)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('일주일 운동 일정을 만들어 주세요'), findsOneWidget);
    expect(find.text('하체 집중 · 4종목'), findsNothing);
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byKey(ValueKey('home-weekday-$i')));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyRoutineEditor), findsNothing);
    }
    await tester.tap(find.byKey(const ValueKey('home-weekday-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일정 만들기'));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyRoutineEditor), findsOneWidget);
    await tester.enterText(find.byKey(const Key('routine-title')), '내 루틴');
    await tester.ensureVisible(
      find.byKey(const ValueKey('routine-exercise-13')),
    );
    await tester.tap(find.byKey(const ValueKey('routine-exercise-13')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('routine-sets-13')), '2');
    await tester.enterText(find.byKey(const ValueKey('routine-reps-13')), '8');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine-save')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('routine-save')));
    await tester.pumpAndSettle();
    expect(find.text('내 루틴 · 1종목'), findsOneWidget);
    expect(find.text('바벨 벤치프레스'), findsOneWidget);
    await tester.ensureVisible(find.text('운동 시작'));
    await tester.tap(find.text('운동 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('바벨 벤치프레스').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('preview-세트 수')))
          .controller!
          .text,
      '2',
    );
    expect(repository.workouts.single.exercise, 13);
    expect(tester.takeException(), isNull);
  });
  testWidgets('특정 날짜를 휴식일로 바꾼 뒤 편집하면 반복 루틴 대신 날짜 예외가 표시된다', (tester) async {
    final model = HomeViewModel(
      repository: FakeHomeRepository(),
      today: DateTime(2026, 10, 14),
    );
    await model.initialize();
    await model.saveRoutine(model.today, DayRoutine.rest(), repeat: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: WeeklyRoutineEditor(model: model, date: model.today),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const Key('routine-rest-day')))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(find.text('이번 날짜만'), findsOneWidget);
    expect(find.byKey(const Key('routine-title')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('다른 요일의 루틴을 복사하고 작은 화면에서도 저장 버튼을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = FakeHomeRepository(emptySchedule: true);
    final model = HomeViewModel(
      repository: repository,
      today: DateTime(2026, 10, 14),
    );
    await model.initialize();
    await model.saveRoutine(
      DateTime(2026, 10, 16),
      routine('금요일 루틴'),
      repeat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: WeeklyRoutineEditor(model: model, date: model.today),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('routine-copy')));
    await tester.tap(find.byKey(const Key('routine-copy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('금요일 · 금요일 루틴').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('routine-title')))
          .controller!
          .text,
      '금요일 루틴',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine-save')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
