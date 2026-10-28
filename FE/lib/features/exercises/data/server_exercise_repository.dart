import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import 'exercise_repository.dart';
import 'models/exercise.dart';

class ServerExerciseRepository implements ExerciseRepository {
  ServerExerciseRepository(this.api);
  final ApiClient api;
  @override
  Future<ExercisePageData> list({
    ExerciseFilter filter = const ExerciseFilter(),
    int page = 1,
  }) async {
    final query = filter.query.trim();
    final uri = Uri(
      path: ApiContract.exercises,
      queryParameters: {
        'page': '$page',
        'page_size': '20',
        if (query.isNotEmpty) 'q': query,
        'target_part': ?filter.part,
        'equipment': ?filter.equipment,
        if (filter.difficulty != null) 'difficulty': '${filter.difficulty}',
      },
    );
    return ExercisePageData.fromJson((await api.send('GET', uri.toString()))!);
  }

  @override
  Future<Exercise> detail(int id) async =>
      Exercise.fromJson((await api.send('GET', ApiContract.exercise(id)))!);
}
