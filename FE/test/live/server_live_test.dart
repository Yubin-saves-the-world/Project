import 'dart:io';

import 'package:fe/features/auth/data/models/signup_request.dart';
import 'package:fe/features/auth/data/server_onboarding_repository.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/profile/data/models/body_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

final _baseUrl = Platform.environment['LIVE_API_BASE_URL'];
final _mailPeekUrl = Platform.environment['LIVE_MAIL_PEEK_URL'];

/// 테스트용 메일 서버가 마지막으로 받은 인증번호를 읽는다.
Future<String> _codeFor(String email) async {
  final res = await http.get(Uri.parse('$_mailPeekUrl/last?to=$email'));
  return res.body.trim();
}

void main() {
  final run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final email = 'live$run@example.com';
  const password = 'abcd1234';

  test('가입 → 로그인 → 설문 저장 → 재시작 후 홈 상태를 실제 서버와 확인한다', () async {
    final tokens = MemoryTokenStore();
    ServerOnboardingRepository repo() =>
        ServerOnboardingRepository(baseUrl: _baseUrl!, tokenStore: tokens);

    await repo().sendEmailCode(email);
    await expectLater(
      repo().confirmEmailCode(email: email, code: '000000'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', '인증번호가 일치하지 않아요.')),
    );
    final token = await repo().confirmEmailCode(email: email, code: await _codeFor(email));

    final registered = await repo().register(SignupRequest(
      nickname: '라이브$run'.substring(0, 8),
      email: email,
      password: password,
      termsAgreed: true,
      privacyAgreed: true,
      bodyPhotoAgreed: true,
      aiProcessingAgreed: true,
      emailVerificationToken: token,
    ));
    expect(registered.signedIn, isFalse);

    await expectLater(
      repo().sendEmailCode(email.toUpperCase()),
      throwsA(isA<StateError>().having((e) => e.message, 'message', '이미 가입된 이메일이에요.')),
    );
    await expectLater(
      repo().register(SignupRequest(
        nickname: '무토큰$run'.substring(0, 8),
        email: 'other$run@example.com',
        password: password,
        termsAgreed: true,
        privacyAgreed: true,
        bodyPhotoAgreed: true,
        aiProcessingAgreed: true,
      )),
      throwsA(isA<StateError>()),
    );

    await expectLater(
      repo().login(email: email, password: 'wrong1234'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', '이메일 또는 비밀번호가 올바르지 않아요.')),
    );

    final loggedIn = await repo().login(email: email, password: password);
    expect(loggedIn.signedIn, isTrue);
    expect(loggedIn.consentCompleted, isTrue);
    expect(loggedIn.onboardingCompleted, isFalse);
    expect(loggedIn.nextStep, 1);

    final saved = await repo().saveProfile(const BodyProfile(
      heightCm: 175,
      weightKg: 73.5,
      age: 18,
      gender: Gender.male,
      goalType: GoalType.muscle,
      weeklyFrequency: 5,
      experienceLevel: ExperienceLevel.over1y,
    ));
    expect(saved.onboardingCompleted, isTrue);
    expect(saved.profile!.weightKg, 73.5);

    final restarted = await repo().load();
    expect(restarted.signedIn, isTrue);
    expect(restarted.onboardingCompleted, isTrue);
    expect(restarted.profile!.heightCm, 175.0);
    expect(restarted.nextStep, 2);

    final edited = await repo().saveProfile(const BodyProfile(
      heightCm: 175,
      weightKg: 71,
      age: 18,
      gender: Gender.male,
      goalType: GoalType.diet,
      weeklyFrequency: 3,
      experienceLevel: ExperienceLevel.over1y,
    ));
    expect(edited.profile!.weightKg, 71.0);
    expect(edited.profile!.goalType, GoalType.diet);
  }, skip: (_baseUrl == null || _mailPeekUrl == null) ? 'LIVE_API_BASE_URL, LIVE_MAIL_PEEK_URL을 지정하면 실제 서버로 실행한다' : false);
}
