import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PreviewWorkout {
  const PreviewWorkout({
    required this.date,
    required this.exercise,
    required this.startedAt,
    this.weight = 0,
    this.reps = 0,
    this.sets = 0,
    this.completed = false,
    this.aborted = false,
  });
  final DateTime date, startedAt;
  final int exercise, reps, sets;
  final double weight;
  final bool completed, aborted;
  double get volume => weight * reps * sets;
  PreviewWorkout markAborted() => PreviewWorkout(
    date: date,
    exercise: exercise,
    startedAt: startedAt,
    weight: weight,
    reps: reps,
    sets: sets,
    completed: false,
    aborted: true,
  );
  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'exercise': exercise,
    'started_at': startedAt.toIso8601String(),
    'weight': weight,
    'reps': reps,
    'sets': sets,
    'completed': completed,
    'aborted': aborted,
  };
  factory PreviewWorkout.fromJson(Map<String, dynamic> j) => PreviewWorkout(
    date: DateTime.parse(j['date'] as String),
    exercise: j['exercise'] as int,
    startedAt: DateTime.parse(j['started_at'] as String),
    weight: (j['weight'] as num).toDouble(),
    reps: j['reps'] as int,
    sets: j['sets'] as int,
    completed: j['completed'] as bool,
    aborted: j['aborted'] as bool? ?? false,
  );
}

abstract interface class HomePreviewRepository {
  Future<List<PreviewWorkout>> load();
  Future<void> save(List<PreviewWorkout> workouts);
  Future<Map<String, bool>> loadDayOverrides();
  Future<void> saveDayOverrides(Map<String, bool> overrides);
}

/// Device-only demonstration records, separate from production API data.
class LocalHomePreviewRepository implements HomePreviewRepository {
  LocalHomePreviewRepository(String owner)
    : _key = 'vitality.home.preview.v1.$owner';
  final String _key;
  SharedPreferencesAsync get _preferences => SharedPreferencesAsync();
  @override
  Future<Map<String, bool>> loadDayOverrides() async {
    final raw = await _preferences.getString('$_key.schedule');
    if (raw == null) return {};
    return Map<String, bool>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<void> saveDayOverrides(Map<String, bool> overrides) =>
      _preferences.setString('$_key.schedule', jsonEncode(overrides));

  @override
  Future<List<PreviewWorkout>> load() async {
    final raw = await _preferences.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map(
          (j) => PreviewWorkout.fromJson(Map<String, dynamic>.from(j as Map)),
        )
        .toList();
  }

  @override
  Future<void> save(List<PreviewWorkout> workouts) => _preferences.setString(
    _key,
    jsonEncode(workouts.map((w) => w.toJson()).toList()),
  );
}
