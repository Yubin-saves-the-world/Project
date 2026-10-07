import 'package:flutter_test/flutter_test.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/auth/data/models/auth_session.dart';
import 'package:fe/features/auth/data/models/signup_request.dart';

void main() {
  test('약관 버전을 지정하지 않으면 서버 기본값을 사용한다', () {
    const request = SignupRequest(
      nickname: '유빈',
      email: 'USER@EXAMPLE.COM',
      password: 'abcd1234',
      termsAgreed: true,
      privacyAgreed: true,
      bodyPhotoAgreed: true,
      aiProcessingAgreed: true,
    );
    expect(request.toJson().containsKey('policy_version'), isFalse);
    expect(request.toJson()['email'], 'user@example.com');
  });
  test('동의 → 신체정보 → 홈 순서로 서버 상태를 분기한다', () {
    final json = {
      'user_id': 1,
      'email': 'user@example.com',
      'nickname': '유빈',
      'role': 'user',
      'onboarding_completed': true,
      'consent_completed': false,
      'body_photo_agreed': false,
      'ai_processing_agreed': true,
      'created_at': '2026-10-06T19:02:10+09:00',
    };
    expect(CurrentUser.fromJson(json).initialDestination, 'consent');
    json['consent_completed'] = true;
    json['onboarding_completed'] = false;
    expect(CurrentUser.fromJson(json).initialDestination, 'profile');
    json['onboarding_completed'] = true;
    expect(CurrentUser.fromJson(json).initialDestination, 'home');
  });
  test('카카오 계정의 이메일 null을 허용한다', () {
    final user = CurrentUser.fromJson({
      'user_id': 1,
      'email': null,
      'nickname': '유빈',
      'role': 'user',
      'onboarding_completed': true,
      'consent_completed': true,
      'body_photo_agreed': true,
      'ai_processing_agreed': true,
      'created_at': '2026-10-06T19:02:10+09:00',
    });
    expect(user.email, isNull);
    expect(user.initialDestination, 'home');
  });

  test('JWT 만료시간과 서버 오류 필드 형식을 읽는다', () {
    final session = AuthSession.fromJson({
      'access_token': 'token',
      'token_type': 'Bearer',
      'expires_in': 604800,
      'onboarding_completed': false,
    });
    expect(session.expiresIn, ApiContract.accessTokenLifetimeSeconds);
    final error = ApiFailure.fromJson({
      'code': 'VALIDATION_FAILED',
      'message': '입력 오류',
      'status': 400,
      'fields': {'email': '잘못된 이메일'},
    });
    expect(error.fields?['email'], '잘못된 이메일');
    expect(
      ApiContract.jsonHeaders(session.accessToken)['Authorization'],
      'Bearer token',
    );
  });
}
