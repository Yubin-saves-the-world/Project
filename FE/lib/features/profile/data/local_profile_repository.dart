import '../../auth/data/onboarding_repository.dart';
import 'models/body_profile.dart';
import 'profile_repository.dart';

class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this.onboarding);
  final OnboardingRepository onboarding;
  @override
  Future<BodyProfile?> load() async => (await onboarding.load()).profile;
  @override
  Future<ProfileSaveResult> save(
    BodyProfile profile, {
    required bool create,
  }) async {
    final before = await load();
    final saved = await onboarding.saveProfile(profile);
    return ProfileSaveResult(
      saved.profile!,
      routineRefreshRecommended:
          before != null &&
          (before.goalType != profile.goalType ||
              before.weeklyFrequency != profile.weeklyFrequency ||
              before.experienceLevel != profile.experienceLevel),
    );
  }
}
