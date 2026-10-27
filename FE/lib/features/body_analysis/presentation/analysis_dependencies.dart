import '../../workout/presentation/workout_dependencies.dart';
import '../../routines/data/routine_repository.dart';
import '../../exercises/data/exercise_repository.dart';
import '../../goal_body/presentation/goal_dependencies.dart';
import '../../../core/media/image_picker_service.dart';
import '../../photos/data/photo_repository.dart';
import '../../photos/data/photo_preparer.dart';
import '../data/analysis_repository.dart';
import '../data/analysis_pending_store.dart';

class AnalysisDependencies {
  const AnalysisDependencies({
    required this.repository,
    required this.photos,
    required this.picker,
    required this.pending,
    this.preparer,
    this.onAccessRequired,
    this.goals,
    this.routines,
    this.exercises,
    this.workouts,
  });
  final RoutineRepository? routines;
  final ExerciseRepository? exercises;
  final WorkoutDependencies? workouts;
  final GoalDependencies? goals;
  final AnalysisRepository repository;
  final PhotoRepository photos;
  final PhotoPicker picker;
  final AnalysisPendingStore pending;
  final PhotoPreparer? preparer;
  final void Function()? onAccessRequired;
}
