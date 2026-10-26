import '../../../core/media/image_picker_service.dart';
import '../../photos/data/photo_repository.dart';
import '../../photos/data/photo_preparer.dart';
import '../data/goal_repository.dart';

class GoalDependencies {
  const GoalDependencies({
    required this.repository,
    required this.photos,
    required this.picker,
    this.preparer,
    this.localPreview = false,
    this.onAccessRequired,
  });
  final GoalRepository repository;
  final PhotoRepository photos;
  final PhotoPicker picker;
  final PhotoPreparer? preparer;
  final bool localPreview;
  final void Function()? onAccessRequired;
}
