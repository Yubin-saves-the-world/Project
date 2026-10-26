import 'models/exercise.dart';

abstract interface class ExerciseRepository {
  Future<ExercisePageData> list({
    ExerciseFilter filter = const ExerciseFilter(),
    int page = 1,
  });
  Future<Exercise> detail(int id);
}
