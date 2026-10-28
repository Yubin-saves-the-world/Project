import '../../exercises/data/exercise_repository.dart';
import '../../exercises/data/models/exercise.dart';
import 'models/exercise_catalog.dart';

/// Old schedule indices are never used as server IDs. Resolve only a unique,
/// exact server name/part match, and verify its current detail before starting.
class ManualExerciseResolver {
  ManualExerciseResolver(this.repository);
  final ExerciseRepository repository;
  List<Exercise> _catalog = [];

  Future<void> load() async {
    final items = <Exercise>[];
    var page = 1;
    while (true) {
      final result = await repository.list(page: page);
      if (result.page != page ||
          result.total < items.length ||
          result.items.any((e) => items.any((old) => old.id == e.id)) ||
          result.items.map((e) => e.id).toSet().length != result.items.length) {
        throw StateError('서버 운동 목록을 다시 확인해 주세요.');
      }
      items.addAll(result.items);
      if (items.length >= result.total) break;
      if (result.items.isEmpty) throw StateError('서버 운동 목록을 모두 확인하지 못했어요.');
      page++;
    }
    _catalog = List.unmodifiable(items);
  }

  Exercise? match(int index) {
    if (index < 0 || index >= workoutCatalog.length) return null;
    final local = workoutCatalog[index];
    final matches = _catalog
        .where(
          (e) =>
              e.name == local.name &&
              (local.category.isEmpty || e.partLabel == local.category),
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  Future<Exercise> resolve(int index) async {
    await load();
    final found = match(index);
    if (found == null) {
      throw StateError(
        '이 종목을 서버에서 확인하지 못했어요. 일정 수정에서 현재 지원하는 종목을 선택해 주세요. 기존 기록은 유지돼요.',
      );
    }
    final current = await repository.detail(found.id);
    if (current.id != found.id ||
        current.name != found.name ||
        current.targetPart != found.targetPart ||
        current.equipment != found.equipment) {
      throw StateError('운동 정보가 변경됐어요. 목록을 다시 확인해 주세요.');
    }
    return current;
  }
}
