import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/data/models/server_home_data.dart';
import 'package:fe/features/workout/presentation/workout_history_view_model.dart';
import '../../fakes/fake_workout_history.dart';

void main() {
  test('월 단위 조회는 윤년에도 92일을 넘지 않고 미래 선택은 막는다', () async {
    final repo = FakeWorkoutHistory();
    final m = WorkoutHistoryViewModel(repo, today: DateTime.utc(2024, 2, 29));
    await m.refresh();
    expect(repo.requests.first.$1, DateTime.utc(2024, 2));
    expect(repo.requests.first.$2, DateTime.utc(2024, 2, 29));
    await m.select(DateTime.utc(2024, 3, 1));
    expect(m.selected, DateTime.utc(2024, 2, 29));
    await m.changeMonth(-1);
    expect(m.month, DateTime.utc(2024, 1));
    expect(repo.requests.every((e) => e.$2.difference(e.$1).inDays < 92), true);
    m.dispose();
  });
  test('월 합계·날짜 표시는 페이지 전체 summary, 상태 필터는 날짜 목록에만 적용한다', () async {
    final repo = FakeWorkoutHistory()..pageSize = 1;
    final m = WorkoutHistoryViewModel(
      repo,
      date: DateTime.utc(2026, 10, 26),
      today: DateTime.utc(2026, 10, 27),
    );
    await m.refresh();
    expect(m.summary!.count, 1);
    expect(m.summary!.seconds, 612);
    expect(m.summary!.dates, {'2026-10-26'});
    expect(m.items.length, 1);
    await m.more();
    expect(m.items.length, 2);
    await m.more();
    expect(m.items.length, 3);
    expect(m.hasMore, false);
    await m.filter('aborted');
    expect(m.items.single.status, 'aborted');
    expect(repo.requests.last.$4, 'aborted');
    expect(m.summary!.count, 1);
    m.dispose();
  });
  test('빠르게 날짜·월을 바꿔도 늦은 이전 응답으로 돌아가지 않는다', () async {
    final repo = FakeWorkoutHistory();
    final pending = Completer<ServerWorkoutPage>();
    repo.handler = (a, b, p, s) {
      if (a == DateTime.utc(2026, 10, 26) && a == b) return pending.future;
      return Future.value(
        ServerWorkoutPage(
          items: [],
          page: p,
          total: 0,
          count: 0,
          sets: 0,
          volume: 0,
          dates: {},
        ),
      );
    };
    final m = WorkoutHistoryViewModel(
      repo,
      date: DateTime.utc(2026, 10, 26),
      today: DateTime.utc(2026, 10, 27),
    );
    final old = m.loadDay();
    await m.select(DateTime.utc(2026, 9, 12));
    pending.complete(
      ServerWorkoutPage(
        items: [historyRecord(87)],
        page: 1,
        total: 1,
        count: 1,
        sets: 2,
        volume: 760,
        dates: {'2026-10-26'},
      ),
    );
    await old;
    expect(m.selected, DateTime.utc(2026, 9, 12));
    expect(m.items, isEmpty);
    expect(m.month, DateTime.utc(2026, 9));
    m.dispose();
  });
  test('오류는 빈 기록으로 표시하지 않고 월/날짜 재시도로 복구한다', () async {
    final repo = FakeWorkoutHistory()..error = StateError('통신 오류');
    final m = WorkoutHistoryViewModel(
      repo,
      date: DateTime.utc(2026, 10, 26),
      today: DateTime.utc(2026, 10, 27),
    );
    await m.refresh();
    expect(m.monthError, isNotNull);
    expect(m.dayError, isNotNull);
    expect(m.summary, isNull);
    repo.error = null;
    await m.refresh();
    expect(m.monthError, isNull);
    expect(m.dayError, isNull);
    expect(m.items.length, 3);
    m.dispose();
  });
  test('페이지 응답이 늦어도 상태 필터를 바꾼 새 목록에 합쳐지지 않는다', () async {
    final repo = FakeWorkoutHistory();
    final wait = Completer<ServerWorkoutPage>();
    ServerWorkoutPage data(int id, {int total = 2, int page = 1}) =>
        ServerWorkoutPage(
          items: [historyRecord(id)],
          page: page,
          total: total,
          count: 1,
          sets: 2,
          volume: 760,
          dates: {'2026-10-26'},
        );
    repo.handler = (a, b, page, status) async {
      if (page == 2) return wait.future;
      return data(status == null ? 87 : 88, total: status == null ? 2 : 1);
    };
    final m = WorkoutHistoryViewModel(
      repo,
      date: DateTime.utc(2026, 10, 26),
      today: DateTime.utc(2026, 10, 27),
    );
    await m.loadDay();
    final more = m.more();
    await m.filter('aborted');
    wait.complete(data(90, page: 2));
    await more;
    expect(m.items.single.id, 88);
    expect(m.hasMore, false);
    m.dispose();
  });
  test('중복 페이지만 반복하는 응답은 기존 목록을 보존하고 재시도를 제공한다', () async {
    final repo = FakeWorkoutHistory();
    repo.handler = (a, b, page, status) async => ServerWorkoutPage(
      items: [historyRecord(87)],
      page: page,
      total: 2,
      count: 1,
      sets: 2,
      volume: 760,
      dates: {'2026-10-26'},
    );
    final m = WorkoutHistoryViewModel(
      repo,
      date: DateTime.utc(2026, 10, 26),
      today: DateTime.utc(2026, 10, 27),
    );
    await m.loadDay();
    await m.more();
    expect(m.items.length, 1);
    expect(m.dayError, isNotNull);
    m.dispose();
  });
  test('다음 날·다음 달 앱 복귀 후 새 날짜를 선택할 수 있다', () async {
    var clock = DateTime.utc(2026, 10, 31);
    final repo = FakeWorkoutHistory();
    final m = WorkoutHistoryViewModel(repo, now: () => clock);
    await m.refresh();
    clock = DateTime.utc(2026, 11, 1);
    await m.refresh();
    expect(m.today, clock);
    await m.select(clock);
    expect(m.month, DateTime.utc(2026, 11));
    expect(m.selected, clock);
    m.dispose();
  });
}
