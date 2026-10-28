import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/goal_body/data/server_goal_repository.dart';

void main() {
  test('GET 404는 빈 목표, POST/PATCH/DELETE는 실제 계약과 인증을 사용한다', () async {
    final requests = <http.Request>[];
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer token');
        if (request.method == 'GET') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'GOAL_NOT_FOUND',
                'message': '목표 없음',
                'status': 404,
              }),
            ),
            404,
          );
        }
        if (request.method == 'DELETE') return http.Response('', 204);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'goal_body_id': 7,
              'status': 'done',
              'summary': null,
              'description': '어깨 근육',
              'created_at': '2026-10-26T00:00:00Z',
            }),
          ),
          request.method == 'POST' ? 201 : 200,
        );
      }),
    );
    final repository = ServerGoalRepository(api);
    expect(await repository.load(), isNull);
    final goal = await repository.create(description: '어깨 근육');
    expect(goal.comparison.summary, '어깨 근육');
    expect(requests.last.url.path, '/api/goal-bodies');
    expect(jsonDecode(requests.last.body), {'description': '어깨 근육'});
    await repository.update(7, photoId: 15, description: '등 근육');
    expect(requests.last.method, 'PATCH');
    expect(requests.last.url.path, '/api/goal-bodies/7');
    expect(jsonDecode(requests.last.body), {
      'photo_id': 15,
      'description': '등 근육',
    });
    await repository.delete(7);
    expect(requests.last.method, 'DELETE');
    api.dispose();
  });
}
