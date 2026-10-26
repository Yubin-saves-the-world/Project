import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/routines/data/models/routine.dart';
import 'package:fe/features/routines/data/server_routine_repository.dart';

void main() {
  test('월요일 주간 조회·상세·상태 PATCH와 null 무게를 API 그대로 처리한다', () async {
    final requests = <http.Request>[];
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final body = {
      'routine_id': 44,
      'analysis_id': 31,
      'scheduled_date': '2026-10-26',
      'title': '하체 집중',
      'target_part': 'leg',
      'estimated_minutes': 35,
      'status': 'skipped',
      'items': [
        {
          'item_id': 201,
          'order_no': 1,
          'target_sets': 3,
          'target_reps': 12,
          'target_weight_kg': null,
          'rest_sec': 90,
          'reason': null,
          'done': false,
          'exercise': {
            'exercise_id': 12,
            'name': '바벨 스쿼트',
            'target_part': 'leg',
            'equipment': 'barbell',
            'difficulty': 4,
            'min_sets': 3,
            'max_sets': 5,
            'media_url': null,
          },
        },
      ],
    };
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer token');
        final json = request.url.path.endsWith('/weekly')
            ? {
                'week_start': '2026-10-26',
                'days': [
                  for (var i = 0; i < 7; i++)
                    {
                      'date': routineDateKey(
                        DateTime(2026, 10, 26).add(Duration(days: i)),
                      ),
                      'is_rest_day': true,
                      'routine': null,
                    },
                ],
              }
            : body;
        return http.Response.bytes(utf8.encode(jsonEncode(json)), 200);
      }),
    );
    final repository = ServerRoutineRepository(api);
    await repository.weekly(DateTime(2026, 10, 26));
    expect(requests.last.url.queryParameters, {'week_start': '2026-10-26'});
    final detail = await repository.detail(44);
    expect(detail.items.single.weightKg, isNull);
    expect(detail.items.single.weightLabel, '직접 입력');
    await repository.setStatus(44, RoutineStatus.skipped);
    expect(requests.last.method, 'PATCH');
    expect(jsonDecode(requests.last.body), {'status': 'skipped'});
    await repository.setStatus(44, RoutineStatus.planned);
    expect(jsonDecode(requests.last.body), {'status': 'planned'});
    await expectLater(
      repository.weekly(DateTime(2026, 10, 27)),
      throwsArgumentError,
    );
    await expectLater(
      repository.setStatus(44, RoutineStatus.done),
      throwsArgumentError,
    );
    api.dispose();
  });
  test('날짜를 월요일로 정규화하고 불완전한 주간 응답을 휴식일로 만들지 않는다', () {
    expect(routineDateKey(routineMonday(DateTime(2027, 1, 1))), '2026-12-28');
    expect(
      () => RecommendedRoutineWeek.fromJson({
        'week_start': '2026-10-26',
        'days': [],
      }),
      throwsFormatException,
    );
    expect(routineStatus('future_status'), RoutineStatus.unknown);
  });
}
