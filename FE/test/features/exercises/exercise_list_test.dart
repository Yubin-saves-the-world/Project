import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/exercises/data/models/exercise.dart';
import 'package:fe/features/exercises/presentation/exercise_list_view_model.dart';
import '../../fakes/fake_exercise_repository.dart';

void main() {
  test('필터 변경 후 늦게 온 이전 결과는 무시한다', () async {
    final old = Completer<ExercisePageData>();
    final current = Completer<ExercisePageData>();
    final repository = FakeExerciseRepository()
      ..onList = (filter, page) =>
          filter.part == null ? old.future : current.future;
    final model = ExerciseListViewModel(repository);
    final loading = model.load();
    model.change(const ExerciseFilter(part: 'leg'));
    current.complete(ExercisePageData([exerciseFixture(2)], 1, 1));
    await Future<void>.delayed(Duration.zero);
    old.complete(ExercisePageData([exerciseFixture(1)], 1, 1));
    await loading;
    expect(model.items.single.id, 2);
    model.dispose();
  });
  testWidgets('검색 디바운스와 30자 초과 차단, dispose 후 타이머 취소', (tester) async {
    final repository = FakeExerciseRepository();
    final model = ExerciseListViewModel(repository);
    model.change(const ExerciseFilter(query: '스'), search: true);
    model.change(const ExerciseFilter(query: '스쿼트'), search: true);
    await tester.pump(const Duration(milliseconds: 299));
    expect(repository.requests, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.requests.length, 1);
    expect(repository.requests.single.$1.query, '스쿼트');
    model.change(ExerciseFilter(query: 'a' * 31), search: true);
    await model.load();
    expect(model.queryError, isNotNull);
    expect(repository.requests.length, 1);
    model.change(const ExerciseFilter(query: '로우'), search: true);
    model.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.requests.length, 1);
  });
  test('다음 페이지 실패는 기존 목록과 페이지를 유지하고 재시도한다', () async {
    var fail = true;
    final repository = FakeExerciseRepository()
      ..onList = (filter, page) async {
        if (page == 2 && fail) throw StateError('불러오기 실패');
        return ExercisePageData([exerciseFixture(page)], page, 2);
      };
    final model = ExerciseListViewModel(repository);
    await model.load();
    await model.more();
    expect(model.items.length, 1);
    expect(model.page, 1);
    expect(model.error, isNotNull);
    fail = false;
    await model.more();
    expect(model.items.length, 2);
    expect(model.hasMore, false);
    model.dispose();
  });
  test('필터 변경 중 늦은 더보기와 dispose 후 응답을 무시한다', () async {
    final next = Completer<ExercisePageData>();
    final repository = FakeExerciseRepository()
      ..onList = (filter, page) async {
        if (page == 2) return next.future;
        return ExercisePageData(
          [exerciseFixture(filter.part == null ? 1 : 3)],
          1,
          2,
        );
      };
    final model = ExerciseListViewModel(repository);
    await model.load();
    final more = model.more();
    model.change(const ExerciseFilter(part: 'arm'));
    await Future<void>.delayed(Duration.zero);
    next.complete(ExercisePageData([exerciseFixture(2)], 2, 2));
    await more;
    expect(model.items.single.id, 3);
    model.dispose();
  });
}
