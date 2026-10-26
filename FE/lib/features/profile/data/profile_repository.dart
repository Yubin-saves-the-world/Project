import 'models/body_profile.dart';

class ProfileSaveResult {
  const ProfileSaveResult(
    this.profile, {
    this.routineRefreshRecommended = false,
  });
  final BodyProfile profile;
  final bool routineRefreshRecommended;
}

abstract interface class ProfileRepository {
  Future<BodyProfile?> load();
  Future<ProfileSaveResult> save(BodyProfile profile, {required bool create});
}
