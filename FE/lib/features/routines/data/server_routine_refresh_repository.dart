import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import 'routine_refresh_repository.dart';

class ServerRoutineRefreshRepository implements RoutineRefreshRepository {
  ServerRoutineRefreshRepository(this.api);
  final ApiClient api;
  @override
  Future<void> regenerate() async {
    var page = 1;
    while (true) {
      final path = Uri(
        path: ApiContract.bodyAnalyses,
        queryParameters: {'page': '$page', 'page_size': '50'},
      ).toString();
      final response = (await api.send('GET', path))!;
      final items = response['items'] as List;
      for (final item in items) {
        if (item is Map &&
            item['status'] == 'done' &&
            item['analysis_id'] is int) {
          await api.send(
            'POST',
            ApiContract.routines,
            body: {'analysis_id': item['analysis_id']},
          );
          return;
        }
      }
      final total = response['total'] as int;
      if (items.isEmpty || page * 50 >= total) break;
      page++;
    }
    throw StateError('완료된 체형 분석이 필요해요. 분석을 마친 뒤 추천 루틴을 만들어 주세요.');
  }
}
