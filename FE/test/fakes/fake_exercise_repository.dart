import 'package:fe/features/exercises/data/exercise_repository.dart';
import 'package:fe/features/exercises/data/models/exercise.dart';

Exercise exerciseFixture(int id, {String? mediaUrl}) => Exercise(
  id: id,
  name: '운동 $id',
  targetPart: 'chest',
  equipment: 'dumbbell',
  difficulty: 2,
  minSets: 2,
  maxSets: 3,
  description: '서버의 운동 설명',
  mediaUrl: mediaUrl,
);

class FakeExerciseRepository implements ExerciseRepository {
  final requests = <(ExerciseFilter, int)>[];
  Future<ExercisePageData> Function(ExerciseFilter, int)? onList;
  Exercise? exercise;
  Object? detailError;
  @override
  Future<ExercisePageData> list({
    ExerciseFilter filter = const ExerciseFilter(),
    int page = 1,
  }) async {
    requests.add((filter, page));
    if (onList != null) return onList!(filter, page);
    return ExercisePageData([exerciseFixture(1)], page, 1);
  }

  @override
  Future<Exercise> detail(int id) async {
    if (detailError != null) throw detailError!;
    return exercise ?? exerciseFixture(id);
  }
}
