import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/data/manual_exercise_resolver.dart';
import 'package:fe/features/exercises/data/models/exercise.dart';
import '../../fakes/fake_exercise_repository.dart';

Exercise squat(int id, {String name = '바벨 스쿼트', String part = 'leg'}) =>
    Exercise(
      id: id,
      name: name,
      targetPart: part,
      equipment: 'barbell',
      difficulty: 2,
    );
void main() {
  test('기존 인덱스 대신 다음 페이지에서 검증한 실제 서버 ID를 사용한다', () async {
    final repo = FakeExerciseRepository()
      ..onList = (_, page) async => ExercisePageData(
        [page == 1 ? squat(900, name: '다른 운동') : squat(1200)],
        page,
        2,
      );
    repo.exercise = squat(1200);
    final resolver = ManualExerciseResolver(repo);
    expect((await resolver.resolve(0)).id, 1200);
    expect(repo.requests.map((r) => r.$2), [1, 2]);
    expect(resolver.match(0)!.id, 1200);
  });
  test('이름이 유사하거나 부위가 다르면 임의로 연결하지 않는다', () async {
    for (final exercise in [squat(2, name: '스쿼트'), squat(3, part: 'chest')]) {
      final repo = FakeExerciseRepository()
        ..onList = (_, page) async => ExercisePageData([exercise], page, 1);
      await expectLater(
        ManualExerciseResolver(repo).resolve(0),
        throwsStateError,
      );
    }
  });
  test('동일 이름·부위의 서버 종목이 여러 개면 선택을 추측하지 않는다', () async {
    final repo = FakeExerciseRepository()
      ..onList = (_, page) async =>
          ExercisePageData([squat(10), squat(11)], page, 2);
    await expectLater(
      ManualExerciseResolver(repo).resolve(0),
      throwsStateError,
    );
  });
  test('반복되는 목록 페이지와 변경된 상세 정보는 시작 전에 차단한다', () async {
    final repo = FakeExerciseRepository()
      ..onList = (_, page) async => ExercisePageData([squat(10)], page, 2);
    await expectLater(
      ManualExerciseResolver(repo).resolve(0),
      throwsStateError,
    );
    repo.onList = (_, page) async => ExercisePageData([squat(10)], page, 1);
    repo.exercise = squat(10, name: '변경된 종목');
    await expectLater(
      ManualExerciseResolver(repo).resolve(0),
      throwsStateError,
    );
  });
}
