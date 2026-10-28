import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/home_server_view_model.dart';
import 'package:fe/features/home/presentation/home_server_dependencies.dart';
import 'package:fe/features/home/data/recommendation_choice_store.dart';
import 'package:fe/features/home/data/models/server_home_data.dart';
import 'package:fe/features/routines/data/models/routine.dart';
import '../../fakes/fake_home_repository.dart';
import '../../fakes/fake_home_server.dart';
import '../../fakes/fake_routine_repository.dart';

void main() {
  test('수동 일정 저장 후 선택 해제 실패를 재시도해도 과거 추천 선택을 다시 적용하지 않는다', () async {
    final localRepo = FakeHomeRepository(emptySchedule: true)
      ..weeklySchedule = WeeklySchedule(
        dates: {
          '2026-10-26': DayRoutine(
            title: '내 운동',
            items: [const RoutineItem(exercise: 0, sets: 3, reps: 10)],
          ),
        },
      );
    final manual = HomeViewModel(
      repository: localRepo,
      today: DateTime(2026, 10, 26),
    );
    await manual.initialize();
    final routines = FakeHomeRoutines(),
        store = FakeChoiceStore()..choices = {'2026-10-26': 44};
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: FakeHomeServer(routines),
        routines: routines,
        choices: store,
      ),
      manual,
    );
    await model.refresh();
    store.writeError = StateError('저장 실패');
    await model.manualSaved();
    expect(model.usesRecommended, false);
    store.writeError = null;
    await model.refresh();
    expect(store.choices, isEmpty);
    expect(model.usesRecommended, false);
    model.dispose();
    manual.dispose();
  });

  test('수동 일정 저장 후 선택한 날짜의 추천 선택만 해제한다', () async {
    final manualRepo = FakeHomeRepository(emptySchedule: true)
      ..weeklySchedule = WeeklySchedule(
        dates: {
          '2026-10-26': DayRoutine(
            title: '내 운동',
            items: [const RoutineItem(exercise: 0, sets: 3, reps: 10)],
          ),
        },
      );
    final manual = HomeViewModel(
      repository: manualRepo,
      today: DateTime(2026, 10, 26),
    );
    await manual.initialize();
    final routines = FakeHomeRoutines(),
        store = FakeChoiceStore()
          ..choices = {'2026-10-26': 44, '2026-10-25': 99};
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: FakeHomeServer(routines),
        routines: routines,
        choices: store,
      ),
      manual,
    );
    await model.refresh();
    expect(model.usesRecommended, true);
    await model.manualSaved();
    expect(store.choices, {'2026-10-25': 99});
    expect(model.usesRecommended, false);
    expect(routines.patches.last.$2, RoutineStatus.skipped);
    model.dispose();
    manual.dispose();
  });

  Future<HomeViewModel> local({bool rest = false, bool empty = false}) async {
    final repository = FakeHomeRepository(emptySchedule: true);
    if (!empty) {
      repository.weeklySchedule = WeeklySchedule(
        dates: {
          '2026-10-26': rest
              ? DayRoutine.rest()
              : DayRoutine(
                  title: '내 운동',
                  items: [const RoutineItem(exercise: 0, sets: 4, reps: 10)],
                ),
        },
      );
    }
    final model = HomeViewModel(
      repository: repository,
      today: DateTime(2026, 10, 26),
    );
    await model.initialize();
    return model;
  }

  test('내 운동 유지가 기본이며 추천만 건너뛰고 일정/기록은 보존한다', () async {
    final manual = await local();
    final before = jsonEncode(manual.schedule.toJson());
    final routines = FakeHomeRoutines();
    final store = FakeChoiceStore();
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: FakeHomeServer(routines),
        routines: routines,
        choices: store,
      ),
      manual,
    );
    await model.refresh();
    expect(routines.patches.single.$2, RoutineStatus.skipped);
    expect(model.usesRecommended, false);
    expect(jsonEncode(manual.schedule.toJson()), before);
    expect(store.choices, isEmpty);
    model.dispose();
    manual.dispose();
  });
  test('추천 선택은 해당 날짜만 적용하고 다른 선택과 반복 원본을 유지한다', () async {
    final manual = await local();
    final before = jsonEncode(manual.schedule.toJson());
    final routines = FakeHomeRoutines();
    final store = FakeChoiceStore()..choices = {'2026-10-25': 99};
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: FakeHomeServer(routines),
        routines: routines,
        choices: store,
      ),
      manual,
    );
    await model.refresh();
    expect(await model.chooseRecommended(), true);
    expect(model.usesRecommended, true);
    expect(store.choices, {'2026-10-25': 99, '2026-10-26': 44});
    expect(routines.patches.last.$2, RoutineStatus.planned);
    expect(jsonEncode(manual.schedule.toJson()), before);
    model.dispose();
    manual.dispose();
  });
  test('휴식일 해제는 추천 복원, 실패/과거/없음은 직접 정하기로 반환한다', () async {
    final manual = await local(rest: true);
    final routines = FakeHomeRoutines();
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: FakeHomeServer(routines),
        routines: routines,
        choices: FakeChoiceStore(),
      ),
      manual,
    );
    await model.refresh();
    routines.failRestore = true;
    expect(await model.restoreRestDay(), false);
    expect(manual.selectedRoutine!.rest, true);
    routines.failRestore = false;
    expect(await model.restoreRestDay(), true);
    expect(model.usesRecommended, true);
    manual.select(DateTime(2026, 10, 25));
    expect(await model.restoreRestDay(), false);
    model.dispose();
    manual.dispose();
  });
  test('진행 중/완료 루틴은 변경하지 않고 선택 저장 실패는 수동 일정을 유지한다', () async {
    final manual = await local();
    final routines = FakeHomeRoutines();
    final api = FakeHomeServer(routines)
      ..running = [serverWorkout(1, status: 'in_progress')];
    final store = FakeChoiceStore();
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: api,
        routines: routines,
        choices: store,
      ),
      manual,
    );
    await model.refresh();
    expect(routines.patches, isEmpty);
    expect(await model.chooseRecommended(), false);
    api.running = [];
    await model.refresh();
    store.writeError = StateError('저장 실패');
    expect(await model.chooseRecommended(), false);
    expect(model.usesRecommended, false);
    expect(manual.selectedRoutine!.title, '내 운동');
    store.writeError = null;
    routines.data[44] = routineFixture(
      status: RoutineStatus.done,
      date: DateTime(2026, 10, 26),
    );
    await model.refresh();
    expect(model.canChoose, false);
    model.dispose();
    manual.dispose();
  });
  test('서버 완료 요약에 진행 중 완료 세트만 더하고 로컬 예시 값은 섞지 않는다', () async {
    final manual = await local(empty: true);
    final routines = FakeHomeRoutines();
    final api = FakeHomeServer(routines)
      ..completed = [serverWorkout(1)]
      ..running = [
        serverWorkout(2, status: 'in_progress', sets: 1, volume: 200),
      ];
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: api,
        routines: routines,
        choices: FakeChoiceStore(),
      ),
      manual,
    );
    await model.refresh();
    expect(model.stats!.count, 1);
    expect(model.volume, 1400);
    expect(model.sets, 4);
    expect(model.completedDates, {'2026-10-26'});
    expect(model.workoutDays, 1);
    expect(model.streakLabel, '1일');
    model.dispose();
    manual.dispose();
  });
  test('선택 정보를 읽지 못하면 기존 추천 선택을 추정하거나 자동으로 변경하지 않는다', () async {
    final manual = await local();
    final routines = FakeHomeRoutines();
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: FakeHomeServer(routines),
        routines: routines,
        choices: FakeChoiceStore()..readError = StateError('읽기 실패'),
      ),
      manual,
    );
    await model.refresh();
    expect(model.error, isNotNull);
    expect(routines.patches, isEmpty);
    expect(model.canChoose, false);
    model.dispose();
    manual.dispose();
  });
  test('빠른 날짜 이동의 늦은 기록 응답을 무시한다', () async {
    final manual = await local(empty: true);
    final routines = FakeHomeRoutines();
    final api = FakeHomeServer(routines);
    final model = HomeServerViewModel(
      HomeServerDependencies(
        repository: api,
        routines: routines,
        choices: FakeChoiceStore(),
      ),
      manual,
    );
    await model.refresh();
    final delayed = Completer<ServerWorkoutPage>();
    api.onRecords = (a, b, page) =>
        a.day == 26 ? delayed.future : Future.value(serverWorkoutPage([]));
    final first = model.loadDay();
    manual.select(DateTime(2026, 10, 27));
    await model.loadDay();
    delayed.complete(serverWorkoutPage([serverWorkout(1)]));
    await first;
    expect(model.stats!.count, 0);
    expect(model.selected.day, 27);
    model.dispose();
    manual.dispose();
  });
  test('추천 선택 키는 계정마다 다르다', () {
    expect(
      PreferencesRecommendationChoiceStore('one@a.com').key,
      isNot(PreferencesRecommendationChoiceStore('two@a.com').key),
    );
  });
}
