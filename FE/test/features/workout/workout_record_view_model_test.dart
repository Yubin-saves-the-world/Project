import 'package:flutter_test/flutter_test.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/workout/presentation/workout_record_view_model.dart';
import 'package:fe/features/workout/presentation/workout_dependencies.dart';
import '../../fakes/fake_workout_history.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  late FakeWorkoutRecordRepository repo;
  WorkoutRecordViewModel create() => WorkoutRecordViewModel(
    WorkoutDependencies(repository: repo, drafts: MemoryWorkoutDraftStore()),
    87,
  );
  setUp(() => repo = FakeWorkoutRecordRepository());
  test('완료 세트 수정은 version을 전달하고 서버가 재계산한 합계를 다시 읽는다', () async {
    final m = create();
    await m.load();
    expect(m.log!.volume, 760);
    expect(
      await m.update(m.log!.sets.first, {
        'weight_kg': 65,
        'reps': 8,
        'is_done': true,
        'rest_sec': 120,
      }),
      true,
    );
    expect(repo.edits.single['version'], 1);
    expect(m.log!.sets.first.version, 2);
    expect(m.log!.volume, 680);
    expect(m.log!.sets.first.rest, 120);
    m.dispose();
  });
  test('버전 충돌 후 조회 전까지 수정을 막고 새 버전으로 사용자 재수정한다', () async {
    final m = create();
    await m.load();
    repo.updateError = ApiRequestError(
      const ApiFailure(
        code: 'VERSION_CONFLICT',
        message: '충돌',
        status: 409,
        fields: null,
      ),
    );
    final body = {'weight_kg': 65, 'reps': 8, 'is_done': true};
    expect(await m.update(m.log!.sets.first, body), false);
    expect(m.needsReload, true);
    expect(await m.update(m.log!.sets.first, body), false);
    expect(repo.edits.length, 1);
    (repo.data['sets'] as List).first['version'] = 5;
    repo.updateError = null;
    await m.load();
    await m.update(m.log!.sets.first, body);
    expect(repo.edits.last['version'], 5);
    m.dispose();
  });
  test('세트 404는 로그 전체를 삭제된 것으로 오인하지 않고 재조회한다', () async {
    final m = create();
    await m.load();
    repo.updateError = ApiRequestError(
      const ApiFailure(
        code: 'NOT_FOUND',
        message: '없는 세트',
        status: 404,
        fields: null,
      ),
    );
    await m.update(m.log!.sets.first, {
      'weight_kg': 65,
      'reps': 8,
      'is_done': true,
    });
    expect(m.missing, false);
    repo.updateError = null;
    await m.load();
    expect(m.canEdit, true);
    m.dispose();
  });
  test('세트 삭제는 남은 번호를 유지하고 완료 세트/볼륨을 갱신한다', () async {
    final m = create();
    await m.load();
    await m.deleteSet(m.log!.sets.first);
    expect(m.log!.sets.single.number, 3);
    expect(m.log!.setCount, 1);
    expect(m.log!.volume, 160);
    m.dispose();
  });
  test('진행·중단 상태는 완료 세트 편집 대신 보존하고 명시적 로그 삭제만 허용한다', () async {
    for (final status in ['in_progress', 'aborted']) {
      repo.data['status'] = status;
      final m = create();
      await m.load();
      expect(m.canEdit, false);
      expect(m.canDelete, true);
      expect(
        await m.update(m.log!.sets.first, {
          'weight_kg': 65,
          'reps': 8,
          'is_done': true,
        }),
        false,
      );
      m.dispose();
    }
    final m = create();
    await m.load();
    expect(await m.delete(), true);
    expect(repo.cancels, 1);
    expect(m.deleted, true);
    expect(m.canDelete, false);
    m.dispose();
  });
  test('잘못된 값은 전송하지 않고 다른 곳에서 삭제된 기록은 404를 표시한다', () async {
    final m = create();
    await m.load();
    expect(
      await m.update(m.log!.sets.first, {
        'weight_kg': 501,
        'reps': 8,
        'is_done': true,
      }),
      false,
    );
    expect(repo.edits, isEmpty);
    repo.removed = true;
    await m.load();
    expect(m.missing, true);
    expect(m.canEdit, false);
    m.dispose();
  });
}
