import 'dart:convert';

import 'package:fe/features/auth/data/models/signup_request.dart';
import 'package:fe/features/auth/data/server_onboarding_repository.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/profile/data/models/body_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _me = {
  'user_id': 7,
  'email': 'user@example.com',
  'nickname': '유빈',
  'role': 'user',
  'consent_completed': true,
  'body_photo_agreed': true,
  'ai_processing_agreed': true,
  'created_at': '2026-10-12T10:00:00+09:00',
};
const _profileJson = {
  'profile_id': 3,
  'height_cm': 175.0,
  'weight_kg': 73.5,
  'age': 18,
  'gender': 'male',
  'goal_type': 'muscle',
  'weekly_frequency': 5,
  'experience_level': 'over1y',
  'measured_at': '2026-10-12T10:01:00+09:00',
};
const _profile = BodyProfile(
  heightCm: 175,
  weightKg: 73.5,
  age: 18,
  gender: Gender.male,
  goalType: GoalType.muscle,
  weeklyFrequency: 5,
  experienceLevel: ExperienceLevel.over1y,
);

http.Response _json(int status, Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _error(int status, String code, String message, [List<Map<String, String>>? fields]) => {
  'code': code,
  'message': message,
  'status': status,
  'fields': fields,
};

void main() {
  late MemoryTokenStore tokens;
  late List<http.BaseRequest> calls;

  ServerOnboardingRepository build(Future<http.Response> Function(http.Request) handler) {
    calls = [];
    return ServerOnboardingRepository(
      baseUrl: 'http://server.test/',
      tokenStore: tokens,
      client: MockClient((request) {
        calls.add(request);
        return handler(request);
      }),
    );
  }

  setUp(() => tokens = MemoryTokenStore());

  test('회원가입은 snake_case 본문으로 POST /api/users를 호출하고 토큰을 받지 않는다', () async {
    final repo = build((r) async {
      expect(r.method, 'POST');
      expect(r.url.toString(), 'http://server.test/api/users');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['email'], 'user@example.com');
      expect(body['terms_agreed'], true);
      expect(body['ai_processing_agreed'], true);
      return _json(201, {'user_id': 7, 'email': 'user@example.com', 'nickname': '유빈', 'created_at': '2026-10-12T10:00:00+09:00'});
    });
    final progress = await repo.register(const SignupRequest(
      nickname: ' 유빈 ',
      email: 'USER@example.com',
      password: 'abcd1234',
      termsAgreed: true,
      privacyAgreed: true,
      bodyPhotoAgreed: true,
      aiProcessingAgreed: true,
    ));
    expect(progress.signedIn, isFalse);
    expect(progress.account!.nickname, '유빈');
    expect(await tokens.read(), isNull);
  });

  test('로그인하면 토큰을 저장하고 내 정보를 조회하며, 설문 전이면 신체정보를 부르지 않는다', () async {
    final repo = build((r) async {
      if (r.url.path == '/api/auth/login') {
        expect(jsonDecode(r.body), {'email': 'user@example.com', 'password': 'abcd1234'});
        expect(r.headers.containsKey('Authorization'), isFalse);
        return _json(200, {'access_token': 'tok', 'token_type': 'Bearer', 'expires_in': 604800, 'onboarding_completed': false});
      }
      expect(r.headers['Authorization'], 'Bearer tok');
      return _json(200, {..._me, 'onboarding_completed': false});
    });
    final progress = await repo.login(email: ' User@Example.com ', password: 'abcd1234');
    expect(await tokens.read(), 'tok');
    expect(progress.signedIn, isTrue);
    expect(progress.profile, isNull);
    expect(progress.nextStep, 1);
    expect(calls.map((c) => c.url.path), ['/api/auth/login', '/api/users/me']);
  });

  test('설문을 마친 계정은 로그인 때 신체정보까지 읽어 홈으로 갈 수 있다', () async {
    final repo = build((r) async {
      if (r.url.path == '/api/auth/login') {
        return _json(200, {'access_token': 'tok', 'token_type': 'Bearer', 'expires_in': 604800, 'onboarding_completed': true});
      }
      if (r.url.path == '/api/users/me/profile') return _json(200, _profileJson);
      return _json(200, {..._me, 'onboarding_completed': true});
    });
    final progress = await repo.login(email: 'user@example.com', password: 'abcd1234');
    expect(progress.onboardingCompleted, isTrue);
    expect(progress.profile!.heightCm, 175.0);
    expect(progress.profile!.goalType, GoalType.muscle);
    expect(progress.nextStep, 2);
  });

  test('신체정보 저장은 POST하고, 이미 있으면 PATCH로 바꾼다', () async {
    var created = false;
    final repo = build((r) async {
      if (r.url.path == '/api/users/me/profile' && r.method == 'POST') {
        return _json(409, _error(409, 'PROFILE_ALREADY_EXISTS', '이미 신체정보가 등록되어 있어요.'));
      }
      if (r.url.path == '/api/users/me/profile' && r.method == 'PATCH') {
        created = true;
        expect(jsonDecode(r.body)['weekly_frequency'], 5);
        return _json(200, {..._profileJson, 'routine_refresh_recommended': false});
      }
      if (r.url.path == '/api/users/me/profile') return _json(200, _profileJson);
      return _json(200, {..._me, 'onboarding_completed': true});
    });
    await tokens.write('tok');
    final progress = await repo.saveProfile(_profile);
    expect(created, isTrue);
    expect(progress.profile!.weightKg, 73.5);
    expect(calls.where((c) => c.method == 'POST'), hasLength(1));
    expect(calls.where((c) => c.method == 'PATCH'), hasLength(1));
  });

  test('이메일 중복 같은 서버 오류는 서버 문구를 그대로 보여 준다', () async {
    final repo = build((r) async => _json(409, _error(409, 'EMAIL_DUPLICATED', '이미 가입된 이메일이에요.')));
    await expectLater(
      repo.register(const SignupRequest(
        nickname: '유빈', email: 'a@b.com', password: 'abcd1234',
        termsAgreed: true, privacyAgreed: true, bodyPhotoAgreed: true, aiProcessingAgreed: true,
      )),
      throwsA(isA<StateError>().having((e) => e.message, 'message', '이미 가입된 이메일이에요.')),
    );
  });

  test('입력 오류는 fields 목록의 첫 사유를 보여 준다', () async {
    final repo = build((r) async => _json(400, _error(400, 'VALIDATION_FAILED', '입력값을 확인해 주세요.', [
      {'field': 'password', 'reason': '8자 이상 영문+숫자 조합이어야 합니다.'},
    ])));
    await expectLater(
      repo.login(email: 'a@b.com', password: 'x'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', '8자 이상 영문+숫자 조합이어야 합니다.')),
    );
  });

  test('로그인 실패는 INVALID_CREDENTIALS 문구를 보여 주고 토큰을 저장하지 않는다', () async {
    final repo = build((r) async => _json(401, _error(401, 'INVALID_CREDENTIALS', '이메일 또는 비밀번호가 올바르지 않아요.')));
    await expectLater(
      repo.login(email: 'a@b.com', password: 'wrong1234'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', '이메일 또는 비밀번호가 올바르지 않아요.')),
    );
    expect(await tokens.read(), isNull);
  });

  test('저장된 토큰이 만료되면 토큰을 지우고 로그아웃 상태로 시작한다', () async {
    final repo = build((r) async => _json(401, _error(401, 'UNAUTHORIZED', '로그인이 필요해요.')));
    await tokens.write('expired');
    final progress = await repo.load();
    expect(progress.signedIn, isFalse);
    expect(progress.account, isNull);
    expect(await tokens.read(), isNull);
  });

  test('토큰이 없으면 서버를 부르지 않고 로그아웃 상태로 시작한다', () async {
    final repo = build((r) async => fail('호출되면 안 됨'));
    final progress = await repo.load();
    expect(progress.signedIn, isFalse);
    expect(calls, isEmpty);
  });

  test('서버에 연결하지 못하면 안내 문구를 보여 준다', () async {
    final repo = build((r) async => throw http.ClientException('refused'));
    await expectLater(
      repo.login(email: 'a@b.com', password: 'abcd1234'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('서버에 연결하지 못했어요'))),
    );
  });

  test('로그아웃은 토큰을 지운다', () async {
    final repo = build((r) async => fail('호출되면 안 됨'));
    await tokens.write('tok');
    await repo.signOut();
    expect(await tokens.read(), isNull);
  });
}
