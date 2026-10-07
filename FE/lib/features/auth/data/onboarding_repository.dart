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

  /// Consent boundary: server adapter uses PATCH /api/users/me.
  Future<OnboardingProgress> acceptRequiredConsents();
  Future<OnboardingProgress> register(SignupRequest request);
  Future<OnboardingProgress> saveProfile(BodyProfile profile);
  Future<OnboardingProgress> saveAnalysis(AnalysisInput input);
  Future<OnboardingProgress> complete({required bool prepareAnalysis});
}
