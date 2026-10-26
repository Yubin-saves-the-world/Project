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
  });
  final AnalysisRepository repository;
  final PhotoRepository photos;
  final PhotoPicker picker;
  final AnalysisPendingStore pending;
  final PhotoPreparer? preparer;
  final void Function()? onAccessRequired;
}
