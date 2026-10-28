import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/routines/data/models/routine.dart';
import 'package:fe/features/routines/presentation/routine_week_view_model.dart';
import 'package:fe/features/routines/presentation/routine_detail_view_model.dart';
import '../../fakes/fake_routine_repository.dart';

void main() {
  test('이전 주 늦은 응답을 무시하고 현재 선택한 주만 표시한다', () async {
    final old = Completer<RecommendedRoutineWeek>();
    final current = Completer<RecommendedRoutineWeek>();
    final repository = FakeRoutineRepository()
      ..onWeek = (date) => date.day == 26 ? old.future : current.future;
    final model = RoutineWeekViewModel(
      repository,
      date: DateTime(2026, 10, 27),
    );
    final initial = model.load();
    model.move(1);
    current.complete(weekFixture(DateTime(2026, 11, 2)));
    await Future<void>.delayed(Duration.zero);
    old.complete(weekFixture(DateTime(2026, 10, 26)));
    await initial;
    expect(routineDateKey(model.week!.start), '2026-11-02');
    expect(repository.weeks.every((d) => d.weekday == 1), true);
    model.dispose();
  });
  test('건너뛰기와 오늘/미래 되돌리기, 완료 및 과거 되돌리기 차단', () async {
    final repository = FakeRoutineRepository()
      ..routine = routineFixture(date: DateTime(2026, 10, 26));
    final model = RoutineDetailViewModel(
      repository,
      44,
      today: () => DateTime(2026, 10, 26),
    );
    await model.load();
    await model.toggle();
    expect(repository.patches.single.$2, RoutineStatus.skipped);
    expect(model.canRestore, true);
    await model.toggle();
    expect(repository.patches.last.$2, RoutineStatus.planned);
    repository.routine = routineFixture(status: RoutineStatus.done);
    await model.load();
    await model.toggle();
    expect(repository.patches.length, 2);
    repository.routine = routineFixture(
      status: RoutineStatus.skipped,
      date: DateTime(2026, 10, 25),
    );
    await model.load();
    await model.toggle();
    expect(model.canRestore, false);
    expect(repository.patches.length, 2);
    model.dispose();
  });
  test('상태 변경 실패 시 재조회 전 추가 변경 차단 및 복구', () async {
    final repository = FakeRoutineRepository()
      ..patchError = StateError('연결 오류');
    final model = RoutineDetailViewModel(repository, 44);
    await model.load();
    await model.toggle();
    expect(model.stale, true);
    expect(model.error, contains('연결 오류'));
    await model.toggle();
    expect(repository.patches.length, 1);
    repository.patchError = null;
    await model.load();
    await model.toggle();
    expect(repository.patches.length, 2);
    model.dispose();
  });
  test('dispose 이후 늦은 상세 응답은 반영하지 않는다', () async {
    final pending = Completer<RecommendedRoutine>();
    final repository = FakeRoutineRepository()..onDetail = () => pending.future;
    final model = RoutineDetailViewModel(repository, 44);
    final request = model.load();
    model.dispose();
    pending.complete(routineFixture());
    await request;
    expect(model.routine, isNull);
  });
}
