import '../../profile/data/models/body_profile.dart';
import 'exercise_repository.dart';
import 'models/exercise.dart';

/// 서버 시드의 미리보기. ID는 이 저장소에서만 쓰며 기존 수동 일정의 배열 번호와 섞지 않는다.
class LocalExerciseRepository implements ExerciseRepository {
  LocalExerciseRepository(this.experience);
  final ExperienceLevel? Function() experience;
  List<Exercise> _all() {
    final sets = switch (experience()) {
      ExperienceLevel.under3m => (2, 3),
      ExperienceLevel.under1y => (3, 4),
      ExperienceLevel.over1y => (3, 5),
      _ => null,
    };
    return [
      for (var i = 0; i < _seed.length; i++)
        Exercise(
          id: i + 1,
          name: _seed[i].name,
          targetPart: _seed[i].part,
          equipment: _seed[i].equipment,
          difficulty: _seed[i].difficulty,
          minSets: sets?.$1,
          maxSets: sets?.$2,
          description: _seed[i].description,
        ),
    ];
  }

  @override
  Future<ExercisePageData> list({
    ExerciseFilter filter = const ExerciseFilter(),
    int page = 1,
  }) async {
    final query = filter.query.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final items = _all()
        .where(
          (e) =>
              (filter.part == null || e.targetPart == filter.part) &&
              (filter.equipment == null || e.equipment == filter.equipment) &&
              (filter.difficulty == null ||
                  e.difficulty <= filter.difficulty!) &&
              e.name
                  .replaceAll(RegExp(r'\s+'), '')
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return ExercisePageData(
      items.skip((page - 1) * 20).take(20).toList(),
      page,
      items.length,
    );
  }

  @override
  Future<Exercise> detail(int id) async {
    if (id < 1 || id > _seed.length) throw StateError('종목을 찾을 수 없어요.');
    return _all()[id - 1];
  }
}

class _Seed {
  const _Seed(
    this.name,
    this.part,
    this.equipment,
    this.difficulty,
    this.description,
  );
  final String name, part, equipment, description;
  final int difficulty;
}

// BE V1_1__seed_exercises.sql의 24개 종목. 자동으로 실제 서버 ID에 매핑하지 않는다.
const _seed = [
  _Seed(
    '푸시업',
    'chest',
    'bodyweight',
    1,
    '손을 어깨너비보다 약간 넓게 짚고 가슴이 바닥에 가까워질 때까지 내려갔다 올라옵니다.',
  ),
  _Seed('덤벨 벤치프레스', 'chest', 'dumbbell', 2, '벤치에 누워 덤벨을 가슴 위로 밀어 올립니다.'),
  _Seed('바벨 벤치프레스', 'chest', 'barbell', 3, '벤치에 누워 바벨을 가슴 중앙까지 내렸다가 밀어 올립니다.'),
  _Seed('체스트 프레스 머신', 'chest', 'machine', 1, '등을 붙이고 손잡이를 앞으로 밉니다.'),
  _Seed('랫 풀다운', 'back', 'machine', 1, '바를 가슴 쪽으로 끌어내리며 날개뼈를 모읍니다.'),
  _Seed('시티드 로우', 'back', 'machine', 1, '상체를 세운 채 손잡이를 배 쪽으로 당깁니다.'),
  _Seed('덤벨 로우', 'back', 'dumbbell', 2, '벤치에 한 손을 짚고 덤벨을 옆구리 쪽으로 당깁니다.'),
  _Seed('바벨 로우', 'back', 'barbell', 4, '상체를 숙인 채 바벨을 배 쪽으로 당깁니다.'),
  _Seed(
    '바디웨이트 스쿼트',
    'leg',
    'bodyweight',
    1,
    '발을 어깨너비로 벌리고 엉덩이를 뒤로 빼며 앉았다 일어납니다.',
  ),
  _Seed('레그 프레스', 'leg', 'machine', 1, '발판을 밀어 무릎을 펴고 천천히 돌아옵니다.'),
  _Seed('고블릿 스쿼트', 'leg', 'dumbbell', 2, '덤벨을 가슴 앞에 들고 스쿼트합니다.'),
  _Seed('바벨 스쿼트', 'leg', 'barbell', 4, '바벨을 어깨 뒤에 얹고 스쿼트합니다.'),
  _Seed('숄더 프레스 머신', 'shoulder', 'machine', 1, '손잡이를 머리 위로 밀어 올립니다.'),
  _Seed('덤벨 숄더 프레스', 'shoulder', 'dumbbell', 2, '덤벨을 어깨 높이에서 머리 위로 밀어 올립니다.'),
  _Seed('사이드 레터럴 레이즈', 'shoulder', 'dumbbell', 2, '팔을 옆으로 어깨 높이까지 들어 올립니다.'),
  _Seed('바벨 오버헤드 프레스', 'shoulder', 'barbell', 4, '바벨을 쇄골 위에서 머리 위로 밀어 올립니다.'),
  _Seed('덤벨 컬', 'arm', 'dumbbell', 1, '팔꿈치를 고정하고 덤벨을 어깨 쪽으로 올립니다.'),
  _Seed('해머 컬', 'arm', 'dumbbell', 1, '손바닥이 마주 보게 잡고 덤벨을 올립니다.'),
  _Seed('트라이셉스 푸시다운', 'arm', 'machine', 1, '케이블을 아래로 눌러 팔을 폅니다.'),
  _Seed('벤치 딥스', 'arm', 'bodyweight', 2, '벤치를 뒤로 짚고 팔꿈치를 굽혔다 폅니다.'),
  _Seed(
    '플랭크',
    'core',
    'bodyweight',
    1,
    '팔꿈치와 발끝으로 몸을 일직선으로 유지합니다. 세트당 시간으로 센다.',
  ),
  _Seed('크런치', 'core', 'bodyweight', 1, '누워서 상체를 말아 올립니다.'),
  _Seed('레그 레이즈', 'core', 'bodyweight', 2, '누워서 다리를 곧게 들어 올렸다 내립니다.'),
  _Seed('케이블 크런치', 'core', 'machine', 3, '케이블을 잡고 상체를 말아 내립니다.'),
];
