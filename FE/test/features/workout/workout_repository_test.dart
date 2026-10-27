import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/workout/data/workout_repository.dart';
import '../../fakes/fake_workout_repository.dart';

void main() {
  for (final status in [200, 201]) {
    test('시작 $status 응답은 같은 log를 조회해 기존 세트를 복원하고 계약대로 저장한다', () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'http://server.test',
        tokenStore: MemoryTokenStore(),
        client: MockClient((q) async {
          requests.add(q);
          if (q.method == 'DELETE') return http.Response('', 204);
          final json = q.method == 'POST' && q.url.path == '/api/workout-logs'
              ? {'log_id': 87, 'resumed': status == 200}
              : workoutJson(sets: []);
          return http.Response.bytes(
            utf8.encode(jsonEncode(json)),
            q.method == 'POST' && q.url.path == '/api/workout-logs'
                ? status
                : 200,
          );
        }),
      );
      final repo = ServerWorkoutRepository(api);
      final log = await repo.start(7, routineId: 44);
      expect(log.id, 87);
      expect(jsonDecode(requests.first.body), {
        'exercise_id': 7,
        'routine_id': 44,
      });
      expect(requests[1].url.path, '/api/workout-logs/87');
      final set = WorkoutSet.fromJson({
        'set_id': 842,
        'client_set_id': 'id',
        'set_no': 1,
        'version': 4,
        'weight_kg': 60,
        'reps': 10,
        'rest_sec': 90,
        'is_done': true,
      });
      await repo.add(87, {
        'client_set_id': 'uuid',
        'set_no': 1,
        'weight_kg': 60,
        'reps': 10,
      });
      expect(requests.last.url.path, '/api/workout-logs/87/sets');
      await repo.update(87, set, {'reps': 8});
      expect(requests.last.method, 'PATCH');
      expect(jsonDecode(requests.last.body), {'version': 4, 'reps': 8});
      await repo.deleteSet(87, 842);
      expect(requests.last.url.path, '/api/workout-logs/87/sets/842');
      expect(requests.last.method, 'DELETE');
      await repo.complete(87);
      expect(requests.last.url.path, '/api/workout-logs/87/complete');
      expect(jsonDecode(requests.last.body), {});
      await repo.cancel(87);
      expect(requests.last.url.path, '/api/workout-logs/87');
      api.dispose();
    });
  }
}
