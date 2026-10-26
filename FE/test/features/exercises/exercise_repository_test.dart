import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/exercises/data/server_exercise_repository.dart';
import 'package:fe/features/exercises/data/local_exercise_repository.dart';
import 'package:fe/features/exercises/data/models/exercise.dart';
import 'package:fe/features/profile/data/models/body_profile.dart';

void main() {
  test('운동 목록 검색·필터·페이지와 상세 ID를 실제 계약으로 전달한다', () async {
    final requests = <http.Request>[];
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    final json = {
      'exercise_id': 42,
      'name': '바벨 스쿼트',
      'target_part': 'leg',
      'equipment': 'barbell',
      'difficulty': 4,
      'min_sets': 3,
      'max_sets': 5,
      'media_url': null,
      'description': '서버 설명',
    };
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(
              request.url.path.endsWith('/42')
                  ? json
                  : {
                      'items': [json],
                      'page': 2,
                      'total': 21,
                    },
            ),
          ),
          200,
        );
      }),
    );
    final repository = ServerExerciseRepository(api);
    final result = await repository.list(
      filter: const ExerciseFilter(
        query: ' 바벨 스쿼트 ',
        part: 'leg',
        equipment: 'barbell',
        difficulty: 4,
      ),
      page: 2,
    );
    expect(requests.last.url.queryParameters, {
      'q': '바벨 스쿼트',
      'target_part': 'leg',
      'equipment': 'barbell',
      'difficulty': '4',
      'page': '2',
      'page_size': '20',
    });
    expect(result.items.single.setsLabel, '권장 3~5세트');
    expect((await repository.detail(42)).description, '서버 설명');
    expect(requests.last.url.path, '/api/exercises/42');
    await repository.list();
    expect(requests.last.url.queryParameters, {'page': '1', 'page_size': '20'});
    api.dispose();
  });
  test('로컬 종목 24개·공백 무시 검색·필터·페이지·운동기간 변경', () async {
    var experience = ExperienceLevel.under3m;
    final repository = LocalExerciseRepository(() => experience);
    final first = await repository.list();
    expect(first.items.length, 20);
    expect(first.total, 24);
    expect((await repository.list(page: 2)).items.length, 4);
    final filtered = await repository.list(
      filter: const ExerciseFilter(
        query: '바벨스쿼트',
        part: 'leg',
        equipment: 'barbell',
        difficulty: 4,
      ),
    );
    expect(filtered.items.single.name, '바벨 스쿼트');
    expect(filtered.items.single.minSets, 2);
    expect(
      (await repository.list(
        filter: const ExerciseFilter(query: '바벨스쿼트', difficulty: 3),
      )).items,
      isEmpty,
    );
    experience = ExperienceLevel.over1y;
    expect((await repository.detail(12)).maxSets, 5);
  });
  test('미등록 영상·알 수 없는 값·잘못된 세트는 임의 수치로 바꾸지 않는다', () {
    const exercise = Exercise(
      id: 1,
      name: '운동',
      targetPart: 'new_part',
      equipment: 'new_equipment',
      difficulty: 9,
      mediaUrl: 'javascript:alert(1)',
    );
    expect(exercise.partLabel, '기타 부위');
    expect(exercise.equipmentLabel, '기타 기구');
    expect(exercise.mediaUri, isNull);
    expect(exercise.setsLabel, '권장 세트 정보 없음');
    const valid = Exercise(
      id: 2,
      name: '운동',
      targetPart: 'arm',
      equipment: 'dumbbell',
      difficulty: 1,
      mediaUrl: 'https://video.test/demo.mp4',
    );
    expect(valid.mediaUri!.scheme, 'https');
  });
}
