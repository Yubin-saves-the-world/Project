import '../../routines/data/routine_repository.dart';
import '../../exercises/data/exercise_repository.dart';
import '../data/home_server_repository.dart';
import '../data/recommendation_choice_store.dart';

class HomeServerDependencies {
  const HomeServerDependencies({
    required this.repository,
    required this.routines,
    required this.choices,
    this.exercises,
    this.onAccessRequired,
  });
  final HomeServerRepository repository;
  final RoutineRepository routines;
  final RecommendationChoiceStore choices;
  final ExerciseRepository? exercises;
  final void Function()? onAccessRequired;
}
