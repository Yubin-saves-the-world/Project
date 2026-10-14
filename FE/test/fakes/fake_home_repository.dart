import 'package:fe/features/home/data/home_preview_repository.dart';

class FakeHomeRepository implements HomePreviewRepository {
  List<PreviewWorkout> workouts = [];
  bool fail = false, failLoad = false;
  int writes = 0;
  Map<String, bool> dayOverrides = {};
  bool failSchedule = false;
  @override
  Future<Map<String, bool>> loadDayOverrides() async => Map.of(dayOverrides);
  @override
  Future<void> saveDayOverrides(Map<String, bool> overrides) async {
    if (failSchedule) throw StateError('schedule save failed');
    dayOverrides = Map.of(overrides);
  }

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
