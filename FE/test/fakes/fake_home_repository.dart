import 'package:fe/features/home/data/home_preview_repository.dart';
import 'package:fe/features/home/data/models/weekly_schedule.dart';

class FakeHomeRepository implements HomePreviewRepository {
  FakeHomeRepository({bool emptySchedule = false}) {
    if (!emptySchedule) {
      weeklySchedule = WeeklySchedule(
        weekly: {
          for (var day = 1; day <= 7; day++)
            day: [
              RoutineRevision(
                DateTime(2000),
                [1, 3, 5].contains(day)
                    ? DayRoutine(
                        title: '하체 집중',
                        minutes: 52,
                        items: [
                          const RoutineItem(exercise: 0, sets: 4, reps: 12),
                          const RoutineItem(exercise: 1, sets: 4, reps: 10),
                          const RoutineItem(exercise: 2, sets: 3, reps: 15),
                          const RoutineItem(exercise: 3, sets: 3, reps: 12),
                        ],
                      )
                    : DayRoutine.rest(),
              ),
            ],
        },
      );
    }
  }
  WeeklySchedule? weeklySchedule;
  @override
  Future<WeeklySchedule?> loadWeeklySchedule() async => weeklySchedule;
  @override
  Future<void> saveWeeklySchedule(WeeklySchedule schedule) async {
    if (failSchedule) throw StateError('schedule save failed');
    weeklySchedule = WeeklySchedule.fromJson(schedule.toJson());
  }

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
