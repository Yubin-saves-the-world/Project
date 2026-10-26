import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import '../../routines/data/models/routine.dart';
import 'models/server_home_data.dart';

abstract interface class HomeServerRepository {
  Future<RecommendedRoutine?> today();
  Future<ServerWorkoutPage> records(
    DateTime start,
    DateTime end, {
    int page = 1,
    String? status,
  });
  Future<List<ServerWorkoutRecord>> active(DateTime today);
  Future<int> analysisCount();
}

class ApiHomeServerRepository implements HomeServerRepository {
  ApiHomeServerRepository(this.api);
  final ApiClient api;
  @override
  Future<RecommendedRoutine?> today() async {
    final json = (await api.send('GET', ApiContract.todayRoutine))!;
    if (json['routine'] == null) {
      if (json['is_rest_day'] != true) {
        throw StateError('오늘의 추천 루틴을 다시 확인해 주세요.');
      }
      return null;
    }
    return RecommendedRoutine.fromJson(
      Map<String, dynamic>.from(json['routine'] as Map),
    );
  }

  @override
  Future<ServerWorkoutPage> records(
    DateTime start,
    DateTime end, {
    int page = 1,
    String? status,
  }) async {
    final a = routineDate(start), b = routineDate(end);
    if (b.isBefore(a) || b.difference(a).inDays >= 92) {
      throw ArgumentError('조회 기간은 1~92일이어야 해요.');
    }
    return ServerWorkoutPage.fromJson(
      (await api.send(
        'GET',
        Uri(
          path: ApiContract.workoutLogs,
          queryParameters: {
            'start_date': routineDateKey(a),
            'end_date': routineDateKey(b),
            'page': '$page',
            'page_size': '50',
            'status': ?status,
          },
        ).toString(),
      ))!,
    );
  }

  @override
  Future<List<ServerWorkoutRecord>> active(DateTime today) async {
    final result = <ServerWorkoutRecord>[];
    var page = 1;
    while (true) {
      final response = await records(
        today.subtract(const Duration(days: 1)),
        today,
        page: page,
        status: 'in_progress',
      );
      result.addAll(response.items);
      if (result.length >= response.total) break;
      if (response.items.isEmpty) throw StateError('진행 중인 운동을 모두 확인하지 못했어요.');
      page++;
    }
    return List.unmodifiable(result);
  }

  @override
  Future<int> analysisCount() async =>
      ((await api.send(
            'GET',
            Uri(
              path: ApiContract.bodyAnalyses,
              queryParameters: {'page': '1', 'page_size': '1'},
            ).toString(),
          ))!['total']
          as int);
}
