import 'package:fe/features/home/data/home_preview_repository.dart';

class FakeHomeRepository implements HomePreviewRepository {
  List<PreviewWorkout> workouts = [];
  bool fail = false, failLoad = false;
  int writes = 0;
  @override
  Future<List<PreviewWorkout>> load() async {
    if (failLoad) throw StateError('load failed');
    return workouts;
  }

  @override
  Future<void> save(List<PreviewWorkout> value) async {
    if (fail) throw StateError('failed');
    writes++;
    workouts = value;
  }
}
