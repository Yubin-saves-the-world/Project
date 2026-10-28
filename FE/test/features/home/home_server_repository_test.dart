import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/home/data/home_server_repository.dart';

void main() {
  test('홈 오늘/기록 기간/상태/페이지/분석 수는 실제 API와 인증을 사용한다', () async {
    final requests = <http.Request>[];
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer token');
        final body = request.url.path.endsWith('/today')
            ? {'is_rest_day': true, 'routine': null}
            : request.url.path.endsWith('/body-analyses')
            ? {'total': 0}
            : {
                'items': [],
                'page': 1,
                'total': 0,
                'summary': {
                  'log_count': 0,
                  'total_sets': 0,
                  'total_volume_kg': 0,
                  'total_duration_sec': 720,
                  'workout_dates': [],
                },
              };
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      }),
    );
    final repository = ApiHomeServerRepository(api);
    expect(await repository.today(), isNull);
    expect(requests.last.url.path, '/api/routines/today');
    final records = await repository.records(
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31),
      page: 2,
      status: 'completed',
    );
    expect(records.seconds, 720);
    expect(requests.last.url.queryParameters, {
      'start_date': '2026-10-01',
      'end_date': '2026-10-31',
      'page': '2',
      'page_size': '50',
      'status': 'completed',
    });
    await repository.active(DateTime(2026, 10, 26));
    expect(requests.last.url.queryParameters['start_date'], '2026-10-25');
    expect(requests.last.url.queryParameters['status'], 'in_progress');
    expect(await repository.analysisCount(), 0);
    expect(requests.last.url.queryParameters, {'page': '1', 'page_size': '1'});
    await expectLater(
      repository.records(DateTime(2026, 1, 1), DateTime(2026, 5, 1)),
      throwsArgumentError,
    );
    api.dispose();
  });
}
