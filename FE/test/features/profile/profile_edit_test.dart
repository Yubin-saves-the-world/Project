import 'dart:convert';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/profile/data/models/body_profile.dart';
import 'package:fe/features/profile/data/server_profile_repository.dart';
import 'package:fe/features/profile/presentation/profile_edit_view_model.dart';
import 'package:fe/features/profile/presentation/my_page_view_model.dart';
import 'package:fe/features/routines/data/server_routine_refresh_repository.dart';
import 'package:fe/features/profile/presentation/pages/profile_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../../fakes/fake_profile_photo_repositories.dart';

http.Response _response(String body, int status) =>
    http.Response.bytes(utf8.encode(body), status);

void main() {
  test('정보 수정은 PATCH이고 새 등록 충돌 때만 POST에서 PATCH로 전환한다', () async {
    final calls = <String>[];
    final tokens = MemoryTokenStore();
    await tokens.write('tok');
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      client: MockClient((r) async {
        calls.add(r.method);
        expect(r.headers['Authorization'], 'Bearer tok');
        if (r.method == 'POST') {
          return _response(
            jsonEncode({
              'code': 'PROFILE_ALREADY_EXISTS',
              'message': '등록됨',
              'status': 409,
            }),
            409,
          );
        }
        return _response(
          jsonEncode({
            ...editableProfile.toJson(),
            'routine_refresh_recommended': true,
          }),
          200,
        );
      }),
    );
    final repository = ServerProfileRepository(api);
    expect(
      (await repository.save(
        editableProfile,
        create: false,
      )).routineRefreshRecommended,
      true,
    );
    await repository.save(editableProfile, create: true);
    expect(calls, ['PATCH', 'POST', 'PATCH']);
  });
  test('프로필 미등록은 빈 값이고 알 수 없는 enum은 앱을 종료시키지 않는다', () async {
    final tokens = MemoryTokenStore();
    final repository = ServerProfileRepository(
      ApiClient(
        baseUrl: 'http://server.test',
        tokenStore: tokens,
        client: MockClient(
          (_) async => _response(
            jsonEncode({
              'code': 'PROFILE_NOT_FOUND',
              'message': '없음',
              'status': 404,
            }),
            404,
          ),
        ),
      ),
    );
    expect(await repository.load(), isNull);
    final p = BodyProfile.fromJson({
      ...editableProfile.toJson(),
      'goal_type': 'new-value',
      'experience_level': 'new-value',
      'gender': 'new-value',
    });
    expect(p.goalType, GoalType.unknown);
    expect(p.experienceLevel, ExperienceLevel.unknown);
    expect(p.gender, Gender.unknown);
  });
  test('정확한 주 4회·소수 수치를 복원하고 저장 실패 시 입력을 보존한다', () async {
    final repository = FakeProfileRepository();
    final model = ProfileEditViewModel(repository);
    await model.load();
    expect(model.height, '174.5');
    expect(model.frequency, 4);
    model.weight = '70.5';
    repository.saveError = StateError('서버 연결 실패');
    expect(await model.submitProfile(), false);
    expect(model.weight, '70.5');
    repository.saveError = null;
    repository.refresh = true;
    expect(await model.submitProfile(), true);
    expect(model.saved!.routineRefreshRecommended, true);
    expect(repository.profile!.weightKg, 70.5);
    model.dispose();
  });
  test('범위 밖 입력과 선택 누락은 서버에 저장하지 않는다', () async {
    final repo = FakeProfileRepository(profile: null);
    final model = ProfileEditViewModel(repo);
    await model.load();
    model.height = '999';
    model.weight = '65';
    model.age = '18';
    expect(await model.submitProfile(), false);
    expect(repo.writes, 0);
    model.height = '170';
    expect(await model.submitProfile(), false);
    expect(repo.writes, 0);
    model.dispose();
  });
  for (final scale in [1.0, 1.3]) {
    testWidgets('320폭·글꼴 $scale에서 수정 값을 보존하고 저장 버튼을 고정한다', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ProfileEditPage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('profile-height')))
            .controller!
            .text,
        '174.5',
      );
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('4회'), findsOneWidget);
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      expect(find.text('저장'), findsOneWidget);
      final rect = tester.getRect(find.widgetWithText(FilledButton, '저장'));
      expect(rect.bottom, lessThanOrEqualTo(640));
      expect(tester.takeException(), isNull);
    });
  }
  test('재생성은 최근 완료한 분석만 사용하고 분석이 없으면 생성 API를 호출하지 않는다', () async {
    for (final ready in [true, false]) {
      final tokens = MemoryTokenStore();
      final calls = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'http://server.test',
        tokenStore: tokens,
        client: MockClient((r) async {
          calls.add(r);
          if (r.method == 'POST') return _response('{}', 201);
          return _response(
            jsonEncode({
              'items': [
                {'analysis_id': 9, 'status': 'pending'},
                if (ready) {'analysis_id': 8, 'status': 'done'},
              ],
              'total': ready ? 2 : 1,
            }),
            200,
          );
        }),
      );
      final repo = ServerRoutineRefreshRepository(api);
      if (ready) {
        await repo.regenerate();
        expect(calls.last.url.path, '/api/routines');
        expect(jsonDecode(calls.last.body), {'analysis_id': 8});
      } else {
        await expectLater(repo.regenerate(), throwsStateError);
        expect(calls.length, 1);
      }
    }
  });
  test('신체정보 저장만으로 추천을 생성하지 않으며 별도 요청 실패는 재시도할 수 있다', () async {
    final routine = FakeRoutineRefreshRepository()
      ..error = StateError('다시 시도해 주세요.');
    final repo = FakeProfileRepository();
    final model = MyPageViewModel(repo, routines: routine);
    await model.load();
    expect(routine.calls, 0);
    expect(await model.regenerate(), false);
    expect(model.error, contains('다시 시도'));
    routine.error = null;
    expect(await model.regenerate(), true);
    expect(routine.calls, 2);
    model.dispose();
  });
}
