import 'dart:io';

import 'package:fe/features/auth/data/models/signup_request.dart';
import 'package:fe/features/auth/data/password_reset_repository.dart';
import 'package:fe/features/auth/presentation/password_reset_view_model.dart';
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

Future<String> _newCodeFor(String email, String previous) async {
  for (var i = 0; i < 60; i++) {
    final code = await _codeFor(email);
    if (code.isNotEmpty && code != previous) return code;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('새 인증번호 메일이 오지 않았어요.');
}

void main() {
  final run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final email = 'live$run@example.com';
  const password = 'abcd1234';

  test(
    '가입 → 로그인 → 설문 저장 → 재시작 후 홈 상태를 실제 서버와 확인한다',
    () async {
      final tokens = MemoryTokenStore();
      ServerOnboardingRepository repo() =>
          ServerOnboardingRepository(baseUrl: _baseUrl!, tokenStore: tokens);

      await repo().sendEmailCode(email);
      await expectLater(
        repo().confirmEmailCode(email: email, code: '000000'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            '인증번호가 일치하지 않아요.',
          ),
        ),
      );
      final token = await repo().confirmEmailCode(
        email: email,
        code: await _codeFor(email),
      );

      final registered = await repo().register(
        SignupRequest(
          nickname: '라이브$run'.substring(0, 8),
          email: email,
          password: password,
          termsAgreed: true,
          privacyAgreed: true,
          bodyPhotoAgreed: true,
          aiProcessingAgreed: true,
          emailVerificationToken: token,
        ),
      );
      expect(registered.signedIn, isFalse);

      await expectLater(
        repo().sendEmailCode(email.toUpperCase()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            '이미 가입된 이메일이에요.',
          ),
        ),
      );
      await expectLater(
        repo().register(
          SignupRequest(
            nickname: '무토큰$run'.substring(0, 8),
            email: 'other$run@example.com',
            password: password,
            termsAgreed: true,
            privacyAgreed: true,
            bodyPhotoAgreed: true,
            aiProcessingAgreed: true,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      await expectLater(
        repo().login(email: email, password: 'wrong1234'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            '이메일 또는 비밀번호가 올바르지 않아요.',
          ),
        ),
      );

      final loggedIn = await repo().login(email: email, password: password);
      expect(loggedIn.signedIn, isTrue);
      expect(loggedIn.consentCompleted, isTrue);
      expect(loggedIn.onboardingCompleted, isFalse);
      expect(loggedIn.nextStep, 1);

      final saved = await repo().saveProfile(
        const BodyProfile(
          heightCm: 175,
          weightKg: 73.5,
          age: 18,
          gender: Gender.male,
          goalType: GoalType.muscle,
          weeklyFrequency: 5,
          experienceLevel: ExperienceLevel.over1y,
        ),
      );
      expect(saved.onboardingCompleted, isTrue);
      expect(saved.profile!.weightKg, 73.5);

      final restarted = await repo().load();
      expect(restarted.signedIn, isTrue);
      expect(restarted.onboardingCompleted, isTrue);
      expect(restarted.profile!.heightCm, 175.0);
      expect(restarted.nextStep, 2);

      final edited = await repo().saveProfile(
        const BodyProfile(
          heightCm: 175,
          weightKg: 71,
          age: 18,
          gender: Gender.male,
          goalType: GoalType.diet,
          weeklyFrequency: 3,
          experienceLevel: ExperienceLevel.over1y,
        ),
      );
      expect(edited.profile!.weightKg, 71.0);
      expect(edited.profile!.goalType, GoalType.diet);
    },
    skip: (_baseUrl == null || _mailPeekUrl == null)
        ? 'LIVE_API_BASE_URL, LIVE_MAIL_PEEK_URL을 지정하면 실제 서버로 실행한다'
        : false,
  );

  test(
    '비밀번호 찾기: 인증번호 확인 → 새 비밀번호 → 새 비밀번호로만 로그인',
    () async {
      final resetEmail = 'reset$run@example.com';
      const newPassword = 'newpass99';
      final tokens = MemoryTokenStore();
      ServerOnboardingRepository auth() =>
          ServerOnboardingRepository(baseUrl: _baseUrl!, tokenStore: tokens);

      await auth().sendEmailCode(resetEmail);
      final signupCode = await _codeFor(resetEmail);
      final token = await auth().confirmEmailCode(
        email: resetEmail,
        code: signupCode,
      );
      await auth().register(
        SignupRequest(
          nickname: '재설정$run'.substring(0, 8),
          email: resetEmail,
          password: password,
          termsAgreed: true,
          privacyAgreed: true,
          bodyPhotoAgreed: true,
          aiProcessingAgreed: true,
          emailVerificationToken: token,
        ),
      );

      final repository = ServerPasswordResetRepository(baseUrl: _baseUrl!);
      final unknown = PasswordResetViewModel(repository);
      await unknown.request('nobody$run@example.com');
      expect(unknown.error, isNull);

      final model = PasswordResetViewModel(repository);
      expect(await model.request(resetEmail), isTrue);
      final code = await _newCodeFor(resetEmail, signupCode);
      expect(
        await model.resetWithServerCode(
          resetEmail,
          code == '000000' ? '111111' : '000000',
          newPassword,
        ),
        isFalse,
      );
      expect(model.error, '인증번호가 일치하지 않아요.');
      expect(
        await model.resetWithServerCode(resetEmail, code, newPassword),
        isTrue,
      );
      expect(model.step, PasswordResetStep.complete);

      await expectLater(
        auth().login(email: resetEmail, password: password),
        throwsA(isA<StateError>()),
      );
      final loggedIn = await auth().login(
        email: resetEmail,
        password: newPassword,
      );
      expect(loggedIn.signedIn, isTrue);
      repository.dispose();
    },
    skip: (_baseUrl == null || _mailPeekUrl == null)
        ? 'LIVE_API_BASE_URL, LIVE_MAIL_PEEK_URL을 지정하면 실제 서버로 실행한다'
        : false,
  );
}
