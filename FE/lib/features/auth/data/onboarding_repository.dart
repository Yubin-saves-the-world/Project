import '../../body_analysis/data/models/analysis_input.dart';
import '../../profile/data/models/body_profile.dart';
import 'models/onboarding_progress.dart';
import 'models/signup_request.dart';

abstract interface class OnboardingRepository {
  Future<OnboardingProgress> load();

  /// Clear local session data; never delete a server account.
  Future<void> signOut();
  Future<OnboardingProgress> login({
    required String email,
    required String password,
  });

  Future<OnboardingProgress> loginWithGoogleIdToken(String idToken);

  Future<OnboardingProgress> loginWithKakaoAccessToken(String accessToken);

  /// Consent boundary: server adapter uses PATCH /api/users/me.
  Future<OnboardingProgress> acceptRequiredConsents();
  Future<OnboardingProgress> register(SignupRequest request);
  Future<OnboardingProgress> saveProfile(BodyProfile profile);
  Future<OnboardingProgress> saveAnalysis(AnalysisInput input);
  Future<OnboardingProgress> complete({required bool prepareAnalysis});

  /// true면 서버가 실제 메일로 인증번호를 보낸다. false면 앱 안의 개발용 인증을 쓴다.
  bool get usesRealEmailVerification;

  /// 이메일로 6자리 인증번호를 보낸다.
  Future<void> sendEmailCode(String email);

  /// 인증번호를 확인하고, 회원가입 요청에 넣을 일회용 토큰을 돌려준다.
  Future<String> confirmEmailCode({
    required String email,
    required String code,
  });
}
