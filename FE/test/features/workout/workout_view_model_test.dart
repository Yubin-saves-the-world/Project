import '../../fakes/fake_routine_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/workout/presentation/workout_view_model.dart';
import 'package:fe/features/workout/presentation/workout_dependencies.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  late FakeWorkoutRepository repo;
  late MemoryWorkoutDraftStore store;
  late DateTime now;
  WorkoutViewModel create({int? logId, int rest = 90}) => WorkoutViewModel(
    WorkoutDependencies(repository: repo, drafts: store),
    exerciseId: 7,
    routineId: 44,
    logId: logId,
    restTarget: rest,
    now: () => now,
  );
  setUp(() {
    repo = FakeWorkoutRepository()..data = workoutJson(sets: []);
    store = MemoryWorkoutDraftStore();
    now = DateTime.utc(2026, 10, 27, 10, 10);
  });
  test('시작·서버 경과 시간·세트 추가·실제 휴식·수정 버전·번호 유지', () async {
    final m = create();
    await m.load();
    expect(repo.lastRoutine, 44);
    expect(m.elapsed, 600);
    expect(await m.add(60, 10), true);
    expect(m.log!.sets.length, 1);
    expect(repo.additions.single.containsKey('exercise_id'), false);
    expect(
      repo.additions.single['client_set_id'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    now = now.add(const Duration(seconds: 30));
    expect(m.remaining, 60);
    await m.stopRest();
    now = now.add(const Duration(seconds: 10));
    expect(await m.add(65, 8), true);
    expect(repo.additions.last['rest_sec'], 30);
    await m.update(m.log!.sets.first, 62.5, 9);
    expect(repo.edits.single['version'], 1);
    expect(m.log!.sets.first.version, 2);
    await m.deleteSet(m.log!.sets.last);
    expect(m.nextNumber, 3);
    await m.add(60, 8);
    expect(m.log!.sets.map((s) => s.number), [1, 3]);
    m.dispose();
  });
  test('응답 손실 후 재실행하면 서버에 저장된 세트를 인식하고 중복 생성하지 않는다', () async {
    var m = create();
    await m.load();
    repo.loseResponse = true;
    expect(await m.add(60, 10), false);
    expect(m.pending, isNotNull);
    m.dispose();
    now = now.add(const Duration(seconds: 40));
    m = create(logId: 87);
    await m.load();
    expect(repo.starts, 1);
    expect(m.pending, isNull);
    expect(m.log!.sets.length, 1);
    expect(m.remaining, 50);
    m.dispose();
  });
  test('미전송 요청은 재실행·재시도에도 UUID와 본문을 유지한다', () async {
    var m = create();
    await m.load();
    repo.failBeforeSave = true;
    await m.add(60, 10);
    final body = Map.of(m.pending!);
    m.dispose();
    m = create(logId: 87);
    await m.load();
    expect(await m.add(70, 8), false);
    repo.failBeforeSave = false;
    expect(await m.retry(), true);
    expect(repo.additions.last, body);
    expect(m.pending, isNull);
    m.dispose();
  });
  test('로컬 영구 저장 실패 시 서버에 세트를 보내지 않는다', () async {
    final m = create();
    await m.load();
    store.fail = true;
    expect(await m.add(60, 10), false);
    expect(repo.additions, isEmpty);
    expect(m.needsReload, true);
    m.dispose();
  });
  test('VERSION_CONFLICT 후 재조회하고 사용자가 새 버전을 다시 수정한다', () async {
    final m = create();
    await m.load();
    await m.add(60, 10);
    repo.updateError = ApiRequestError(
      const ApiFailure(
        code: 'VERSION_CONFLICT',
        message: '다른 기기에서 수정했어요.',
        status: 409,
        fields: null,
      ),
    );
    expect(await m.update(m.log!.sets.first, 65, 8), false);
    expect(m.canWrite, false);
    expect(m.accessCode, 'VERSION_CONFLICT');
    (repo.data['sets'] as List).first['version'] = 5;
    repo.updateError = null;
    await m.load();
    await m.update(m.log!.sets.first, 65, 8);
    expect(repo.edits.last['version'], 5);
    m.dispose();
  });
  test('6시간 만료와 aborted 상태는 수정·이어하기를 막는다', () async {
    final m = create();
    await m.load();
    now = DateTime.utc(2026, 10, 27, 16);
    expect(m.canWrite, false);
    expect(await m.add(60, 10), false);
    repo.data['status'] = 'aborted';
    await m.load();
    expect(m.canWrite, false);
    m.dispose();
  });
  test('빈 운동 종료는 삭제, 완료 세트가 있으면 서버 종료', () async {
    final empty = create();
    await empty.load();
    expect(await empty.finish(), true);
    expect(repo.cancels, 1);
    expect(repo.completions, 0);
    empty.dispose();
    final m = create();
    await m.load();
    await m.add(60, 10);
    expect(await m.finish(), true);
    expect(repo.completions, 1);
    expect(m.closed, true);
    m.dispose();
  });
  test('세트 입력 범위 검사와 진행 상태 보존', () async {
    final m = create();
    await m.load();
    for (final value in [-1, 501, double.nan]) {
      expect(await m.add(value, 10), false);
    }
    expect(await m.add(60, 0), false);
    expect(await m.add(60, 101), false);
    expect(repo.additions, isEmpty);
    expect(m.canWrite, true);
    m.dispose();
  });
  test('저장 중 중복 탭은 요청 하나만 보낸다', () async {
    final m = create();
    await m.load();
    final results = await Future.wait([m.add(60, 10), m.add(60, 10)]);
    expect(results, [true, false]);
    expect(repo.additions.length, 1);
    m.dispose();
  });
  test('다른 세트와 번호 충돌한 미전송 입력만 확인 후 해제한다', () async {
    final m = create();
    await m.load();
    repo.failBeforeSave = true;
    await m.add(60, 10);
    repo.data['sets'] = [
      {
        'set_id': 2,
        'client_set_id': 'other',
        'set_no': 1,
        'version': 1,
        'weight_kg': 50,
        'reps': 10,
        'rest_sec': null,
        'is_done': true,
      },
    ];
    await m.load();
    expect(m.conflictingPending, true);
    expect(await m.retry(), false);
    await m.discardConflictingPending();
    expect(m.pending, isNull);
    expect(m.log!.sets.length, 1);
    expect(m.nextNumber, 2);
    m.dispose();
  });
  test('휴식 목표는 홈에서 재개해도 원래 루틴 값 유지', () async {
    var m = create(rest: 120);
    await m.load();
    await m.add(60, 10);
    m.dispose();
    now = now.add(const Duration(seconds: 30));
    m = create(logId: 87);
    await m.load();
    expect(m.remaining, 90);
    await m.add(60, 10);
    expect(m.remaining, 120);
    m.dispose();
  });
  test('첫 세트 전에도 앱을 재실행하면 원래 휴식 목표를 복원한다', () async {
    var m = create(rest: 120);
    await m.load();
    m.dispose();
    m = create(logId: 87);
    await m.load();
    expect(m.draft['rest_target'], 120);
    await m.add(60, 10);
    expect(m.remaining, 120);
    m.dispose();
  });
  test('로컬 복원 정보 없는 기기에서는 실제 연결된 루틴의 목표를 조회한다', () async {
    final routines = FakeRoutineRepository();
    final m = WorkoutViewModel(
      WorkoutDependencies(repository: repo, drafts: store, routines: routines),
      exerciseId: null,
      logId: 87,
      restTarget: 120,
      now: () => now,
    );
    await m.load();
    expect(routines.details, [44]);
    expect(m.draft['rest_target'], 90);
    expect(m.draft['target_sets'], 3);
    expect(m.draft['target_reps'], 12);
    m.dispose();
  });
}
