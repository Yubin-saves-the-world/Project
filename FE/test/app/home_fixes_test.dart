import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/features/home/data/home_preview_repository.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../fakes/fake_home_repository.dart';

void main() {
  test('정수 표기와 API 입력 범위를 저장에서도 검증한다', () async {
    expect(HomeViewModel.parseCount('3.0', 20), isNull);
    expect(HomeViewModel.parseCount('1e2', 100), isNull);
    expect(HomeViewModel.parseCount(' 3 ', 20), 3);
    expect(HomeViewModel.parseCount('21', 20), isNull);
    expect(HomeViewModel.parseCount('101', 100), isNull);
    expect(HomeViewModel.parseWeight('501'), isNull);
    expect(HomeViewModel.parseWeight('Infinity'), isNull);
    final repo = FakeHomeRepository();
    final m = HomeViewModel(repository: repo, today: DateTime(2026, 10, 12));
    await m.initialize();
    await m.start(0);
    expect(await m.complete(501, 12, 4), isFalse);
    expect(await m.complete(20, 101, 4), isFalse);
    expect(await m.complete(20, 12, 21), isFalse);
    expect(m.active, isNotNull);
    m.dispose();
  });
  test('기록 조회 실패 후 저장 차단, 재조회 성공 후 복원한다', () async {
    final repo = FakeHomeRepository()
      ..workouts = [
        PreviewWorkout(
          date: DateTime(2026, 10, 12),
          exercise: 0,
          startedAt: DateTime(2026, 10, 12, 10),
          completed: true,
          weight: 20,
          reps: 12,
          sets: 4,
        ),
      ]
      ..failLoad = true;
    final m = HomeViewModel(repository: repo, today: DateTime(2026, 10, 12));
    await m.initialize();
    expect(m.loaded, isFalse);
    expect(await m.start(1), isFalse);
    expect(repo.writes, 0);
    expect(repo.workouts.length, 1);
    repo.failLoad = false;
    await m.initialize();
    expect(m.volume, 960);
    expect(await m.start(1), isTrue);
    m.dispose();
  });
  test('다른 종목은 자동 전환되지 않고 취소는 진행 중 기록만 지운다', () async {
    final repo = FakeHomeRepository();
    final m = HomeViewModel(repository: repo, today: DateTime(2026, 10, 12));
    await m.initialize();
    await m.start(0);
    await m.complete(20, 12, 4);
    await m.start(1);
    expect(await m.start(2), isFalse);
    expect(m.active!.exercise, 1);
    expect(await m.cancelActive(), isTrue);
    expect(m.volume, 960);
    expect(await m.start(2), isTrue);
    expect(m.active!.exercise, 2);
    m.dispose();
  });
  test('같은 주 계획은 날짜가 바뀌어도 고정, 오늘과 주간은 갱신한다', () async {
    var now = DateTime.utc(2026, 10, 12, 14, 59);
    final m = HomeViewModel(repository: FakeHomeRepository(), now: () => now);
    await m.initialize();
    final planned = m.week.where(m.planned).map((d) => d.weekday).toList();
    now = now.add(const Duration(minutes: 2));
    await m.refreshClock();
    expect(m.today.day, 13);
    expect(m.selectedDate.day, 13);
    expect(m.week.where(m.planned).map((d) => d.weekday), planned);
    m.select(DateTime(2026, 10, 12));
    now = DateTime.utc(2026, 10, 19, 3);
    await m.refreshClock();
    expect(m.monday.day, 19);
    expect(m.selectedDate.day, 12);
    m.goToday();
    expect(m.isToday, isTrue);
    m.dispose();
  });
  test('과거 미래 시작 차단, 모두 완료하면 재시작 차단한다', () async {
    final repo = FakeHomeRepository();
    final m = HomeViewModel(repository: repo, today: DateTime(2026, 10, 12));
    await m.initialize();
    m.select(m.today.add(const Duration(days: 1)));
    expect(await m.start(0), isFalse);
    m.select(m.today.subtract(const Duration(days: 1)));
    expect(await m.start(0), isFalse);
    expect(repo.writes, 0);
    m.goToday();
    for (var i = 0; i < 4; i++) {
      expect(await m.start(i), isTrue);
      expect(await m.complete(20, 12, 4), isTrue);
    }
    expect(m.routineDone, isTrue);
    expect(await m.start(0), isFalse);
    expect(m.doneCount, 4);
    m.dispose();
  });
  test('6시간 경과 운동 자동 중단, 집계에서 제외하고 재시작한다', () async {
    var now = DateTime.utc(2026, 10, 12, 3);
    final repo = FakeHomeRepository();
    final m = HomeViewModel(repository: repo, now: () => now);
    await m.initialize();
    await m.start(0);
    now = now.add(const Duration(hours: 6, seconds: 1));
    await m.refreshClock();
    expect(m.active, isNull);
    expect(repo.workouts.single.aborted, isTrue);
    expect(m.volume, 0);
    expect(m.streak, 0);
    expect(await m.start(1), isTrue);
    m.dispose();
  });
  test('손상된 기록은 원본을 덮어쓰지 않는다', () async {
    final repo = FakeHomeRepository()
      ..workouts = [
        PreviewWorkout(
          date: DateTime(2026, 10, 12),
          exercise: 99,
          startedAt: DateTime(2026, 10, 12),
        ),
      ];
    final m = HomeViewModel(repository: repo, today: DateTime(2026, 10, 12));
    await m.initialize();
    expect(m.loaded, isFalse);
    expect(await m.start(0), isFalse);
    expect(repo.workouts.single.exercise, 99);
    expect(repo.writes, 0);
    m.dispose();
  });
  test('자동 중단 저장 실패 시 추가 저장을 막고 원본을 유지한다', () async {
    var now = DateTime.utc(2026, 10, 12, 3);
    final repo = FakeHomeRepository();
    final m = HomeViewModel(repository: repo, now: () => now);
    await m.initialize();
    await m.start(0);
    repo.fail = true;
    now = now.add(const Duration(hours: 7));
    await m.refreshClock();
    expect(m.loaded, isFalse);
    expect(await m.complete(20, 12, 4), isFalse);
    expect(repo.workouts.single.aborted, isFalse);
    repo.fail = false;
    await m.initialize();
    expect(m.active, isNull);
    expect(repo.workouts.single.aborted, isTrue);
    m.dispose();
  });
  test('자정을 넘어 완료한 운동은 시작 날짜의 기록으로 표시한다', () async {
    var now = DateTime.utc(2026, 10, 12, 14, 59);
    final m = HomeViewModel(repository: FakeHomeRepository(), now: () => now);
    await m.initialize();
    await m.start(0);
    now = now.add(const Duration(minutes: 2));
    await m.refreshClock();
    expect(m.today.day, 13);
    expect(await m.complete(20, 12, 4), isTrue);
    expect(m.completed.single.date.day, 12);
    expect(m.selectedDate.day, 12);
    expect(m.volume, 960);
    m.dispose();
  });
  testWidgets('다른 종목 선택 시 이어하기와 취소 후 새 시작을 명시적으로 선택한다', (tester) async {
    final day = DateTime(2026, 10, 12);
    final repo = FakeHomeRepository()
      ..workouts = [
        PreviewWorkout(
          date: day,
          exercise: 0,
          startedAt: day.add(const Duration(hours: 11)),
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(repository: repo, today: day),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> openOther() async {
      await tester.ensureVisible(find.text('운동 시작'));
      await tester.tap(find.text('운동 시작'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('루마니안 데드리프트').last);
      await tester.pumpAndSettle();
    }

    await openOther();
    expect(find.text('진행 중인 운동이 있어요'), findsOneWidget);
    await tester.tap(find.text('기존 운동 이어하기'));
    await tester.pumpAndSettle();
    expect(repo.workouts.single.exercise, 0);
    expect(find.byKey(const Key('preview-무게(kg)')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('preview-무게(kg)')))).pop();
    await tester.pumpAndSettle();
    await openOther();
    await tester.tap(find.text('취소하고 새 운동'));
    await tester.pumpAndSettle();
    expect(repo.workouts.single.exercise, 1);
    expect(find.byKey(const Key('preview-무게(kg)')), findsOneWidget);
  });
  testWidgets('완료한 루틴은 시작 대신 기록 보기로 표시한다', (tester) async {
    final day = DateTime(2026, 10, 12);
    final repo = FakeHomeRepository()
      ..workouts = List.generate(
        4,
        (i) => PreviewWorkout(
          date: day,
          exercise: i,
          startedAt: day.add(const Duration(hours: 10)),
          completed: true,
          weight: 20,
          reps: 12,
          sets: 4,
        ),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(repository: repo, today: day),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('운동 시작'), findsNothing);
    expect(find.text('운동 완료 · 기록 보기'), findsOneWidget);
    await tester.ensureVisible(find.text('운동 완료 · 기록 보기'));
    await tester.tap(find.text('운동 완료 · 기록 보기'));
    await tester.pumpAndSettle();
    expect(find.text('10월 12일 운동 기록'), findsOneWidget);
    expect(repo.workouts.length, 4);
  });
  testWidgets('조회 재시도와 미래 조회 전용·오늘 요일로 복귀', (tester) async {
    final repo = FakeHomeRepository()..failLoad = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(repository: repo, today: DateTime(2026, 10, 12)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('다시 불러오기'), findsOneWidget);
    repo.failLoad = false;
    await tester.ensureVisible(find.text('다시 불러오기'));
    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('다시 불러오기'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('home-weekday-2')));
    await tester.tap(find.byKey(const ValueKey('home-weekday-2')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('루틴 보기'));
    await tester.tap(find.text('루틴 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('바벨 스쿼트').last);
    await tester.pumpAndSettle();
    expect(repo.workouts, isEmpty);
    Navigator.of(tester.element(find.text('하체 집중'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('home-weekday-0')));
    await tester.tap(find.byKey(const ValueKey('home-weekday-0')));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 루틴'), findsOneWidget);
  });
  testWidgets('운동 취소 확인과 잘못된 정수 입력은 예외 없이 안내한다', (tester) async {
    final repo = FakeHomeRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(repository: repo, today: DateTime(2026, 10, 12)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('운동 시작'));
    await tester.tap(find.text('운동 시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('바벨 스쿼트').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('preview-무게(kg)')), '20');
    await tester.enterText(find.byKey(const Key('preview-횟수')), '3.0');
    await tester.ensureVisible(find.text('종목 완료'));
    await tester.tap(find.text('종목 완료'));
    await tester.pumpAndSettle();
    expect(find.text('1~100 범위의 정수로 입력해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('운동 취소'));
    await tester.tap(find.text('운동 취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('운동 취소').last);
    await tester.pumpAndSettle();
    expect(repo.workouts, isEmpty);
  });
}
