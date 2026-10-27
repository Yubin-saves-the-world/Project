import 'package:fe/features/settings/data/account_repository.dart';
import 'package:fe/features/auth/data/models/auth_session.dart';

Map<String, dynamic> accountJson({
  String nickname = '유빈',
  bool photo = true,
  bool ai = true,
}) => {
  'user_id': 7,
  'email': 'user@example.com',
  'nickname': nickname,
  'role': 'user',
  'onboarding_completed': true,
  'consent_completed': photo && ai,
  'body_photo_agreed': photo,
  'ai_processing_agreed': ai,
  'created_at': '2026-10-06T10:00:00Z',
};

class FakeAccountRepository implements AccountRepository {
  CurrentUser user = CurrentUser.fromJson(accountJson());
  Object? loadError, patchError, deleteError;
  int reads = 0, deletions = 0;
  final patches = <Map<String, dynamic>>[];
  @override
  Future<CurrentUser> load() async {
    reads++;
    if (loadError != null) throw loadError!;
    return user;
  }

  @override
  Future<CurrentUser> update(Map<String, dynamic> body) async {
    patches.add(Map.of(body));
    if (patchError != null) throw patchError!;
    return user = CurrentUser.fromJson(
      accountJson(
        nickname: body['nickname'] as String? ?? user.nickname,
        photo: body['body_photo_agreed'] as bool? ?? user.bodyPhotoAgreed,
        ai: body['ai_processing_agreed'] as bool? ?? user.aiProcessingAgreed,
      ),
    );
  }

  @override
  Future<void> delete() async {
    deletions++;
    if (deleteError != null) throw deleteError!;
  }
}
