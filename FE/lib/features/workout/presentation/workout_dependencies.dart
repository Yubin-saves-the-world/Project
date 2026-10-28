import '../../routines/data/routine_repository.dart';
import '../data/workout_repository.dart';
import '../data/workout_draft_store.dart';

class WorkoutDependencies {
  const WorkoutDependencies({
    required this.repository,
    required this.drafts,
    this.onAccessRequired,
    this.routines,
    this.onHome,
  });
  final WorkoutRepository repository;
  final RoutineRepository? routines;
  final void Function()? onHome;
  final WorkoutDraftStore drafts;
  final void Function()? onAccessRequired;
}
