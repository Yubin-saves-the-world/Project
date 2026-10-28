import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/body_analysis/data/server_analysis_repository.dart';

void main() {
  test('현재 API 경로·요청 키·목록 페이지·명시적 분석 ID를 그대로 사용한다', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: MemoryTokenStore()..write('token'),
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer token');
        final data = switch (request.url.path) {
          '/api/body-analyses/photo' => {
            'analysis_id': 31,
            'status': 'pending',
          },
          '/api/body-analyses' => {
            'items': [],
            'page': 2,
            'page_size': 20,
            'total': 0,
          },
          '/api/goal-bodies' => {
            'code': 'GOAL_NOT_FOUND',
            'message': '목표 없음',
            'status': 404,
          },
          '/api/routines' => {'analysis_id': 31, 'routines': []},
          _ => {
            'analysis_id': 31,
            'status': 'failed',
            'error_code': 'NO_PERSON',
            'created_at': '2026-10-26T00:00:00Z',
          },
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode(data)),
          request.url.path == '/api/goal-bodies' ? 404 : 200,
        );
      }),
    );
    final repository = ServerAnalysisRepository(api);
    expect(
      (await repository.start(photoId: 11, sidePhotoId: 12, goalId: 7)).id,
      31,
    );
    expect(jsonDecode(requests.last.body), {
      'photo_id': 11,
      'side_photo_id': 12,
      'goal_body_id': 7,
    });
    await repository.history(page: 2);
    expect(requests.last.url.queryParameters, {'page': '2', 'page_size': '20'});
    expect(await repository.goal(), isNull);
    expect((await repository.detail(31)).errorCode, 'NO_PERSON');
    await repository.generateRoutines(31);
    expect(jsonDecode(requests.last.body), {'analysis_id': 31});
    api.dispose();
  });
}
