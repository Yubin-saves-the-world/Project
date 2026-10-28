import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../../../core/config/app_config.dart';

class OAuthService {
  static final _google = GoogleSignIn(
    clientId: AppConfig.googleClientId.isNotEmpty ? AppConfig.googleClientId : null,
    scopes: ['email', 'profile'],
  );

  static Future<String?> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.idToken;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> signInWithKakao() async {
    try {
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      return token.accessToken;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOutGoogle() async {
    await _google.signOut();
  }
}
