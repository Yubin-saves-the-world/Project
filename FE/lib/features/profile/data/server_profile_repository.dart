import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import 'models/body_profile.dart';
import 'profile_repository.dart';

class ServerProfileRepository implements ProfileRepository {
  ServerProfileRepository(this.api);
  final ApiClient api;
  @override
  Future<BodyProfile?> load() async {
    try {
      return BodyProfile.fromJson(
        (await api.send('GET', ApiContract.profile))!,
      );
    } on ApiRequestError catch (e) {
      if (e.code == 'PROFILE_NOT_FOUND') return null;
      rethrow;
    }
  }

  @override
  Future<ProfileSaveResult> save(
    BodyProfile profile, {
    required bool create,
  }) async {
    Map<String, dynamic>? result;
    try {
      result = await api.send(
        create ? 'POST' : 'PATCH',
        ApiContract.profile,
        body: profile.toJson(),
      );
    } on ApiRequestError catch (e) {
      if (!create || e.code != 'PROFILE_ALREADY_EXISTS') rethrow;
      result = await api.send(
        'PATCH',
        ApiContract.profile,
        body: profile.toJson(),
      );
    }
    return ProfileSaveResult(
      BodyProfile.fromJson(result!),
      routineRefreshRecommended: result['routine_refresh_recommended'] == true,
    );
  }
}
