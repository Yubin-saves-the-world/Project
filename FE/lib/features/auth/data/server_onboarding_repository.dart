import 'package:http/http.dart' as http;

import '../../../core/network/api_contract.dart';
import '../../../core/network/api_client.dart';
import '../../body_analysis/data/models/analysis_input.dart';
import '../../profile/data/models/body_profile.dart';
import 'models/auth_session.dart';
import 'models/onboarding_progress.dart';
import 'models/signup_request.dart';
import 'onboarding_repository.dart';
import 'token_store.dart';

/// 인증·설문 서버 연결. 분석 입력의 서버 연동은 별도 작업이다.
class ServerOnboardingRepository implements OnboardingRepository {
  ServerOnboardingRepository({
    required String baseUrl,
    http.Client? client,
    TokenStore? tokenStore,
    Duration timeout = const Duration(seconds: 10),
    ApiClient? apiClient,
    Future<void> Function()? onSessionExpired,
  }) : api =
           apiClient ??
           ApiClient(
             baseUrl: baseUrl,
             client: client,
             tokenStore: tokenStore,
             timeout: timeout,
             onSessionExpired: onSessionExpired,
           );
  final ApiClient api;
  TokenStore get _tokens => api.tokens;

  void clearSessionData() {
    _analysis = const AnalysisInput();
    _completed = false;
    _analysisPrepared = false;
  }

  AnalysisInput _analysis = const AnalysisInput();
  bool _completed = false;
  bool _analysisPrepared = false;

  @override
  bool get usesRealEmailVerification => true;

  @override
  Future<void> sendEmailCode(String email) async {
    await _send(
      'POST',
      ApiContract.emailVerifications,
      body: {'email': email.trim().toLowerCase()},
      authorized: false,
    );
  }

  @override
  Future<String> confirmEmailCode({
    required String email,
    required String code,
  }) async {
    final json = await _send(
      'POST',
      ApiContract.emailVerificationConfirm,
      body: {'email': email.trim().toLowerCase(), 'code': code.trim()},
      authorized: false,
    );
    final token = json?['verification_token'];
    if (token is! String || token.isEmpty) {
      throw StateError('인증 응답을 확인하지 못했어요. 다시 시도해 주세요.');
    }
    return token;
  }

  @override
  Future<OnboardingProgress> register(SignupRequest request) async {
    await _send(
      'POST',
      ApiContract.users,
      body: request.toJson(),
      authorized: false,
    );
    return OnboardingProgress(
      signedIn: false,
      account: OnboardingAccount(
        nickname: request.nickname.trim(),
        email: request.email.trim().toLowerCase(),
        bodyPhotoAgreed: request.bodyPhotoAgreed,
        aiProcessingAgreed: request.aiProcessingAgreed,
      ),
    );
  }

  @override
  Future<OnboardingProgress> login({
    required String email,
    required String password,
  }) async {
    final json = await _send(
      'POST',
      ApiContract.login,
      body: {'email': email.trim().toLowerCase(), 'password': password},
      authorized: false,
    );
    await _tokens.write(AuthSession.fromJson(json!).accessToken);
    api.sessionStarted();
    return _fetchProgress();
  }

  @override
  Future<OnboardingProgress> load() async {
    if (await _tokens.read() == null) {
      return const OnboardingProgress(signedIn: false);
    }
    try {
      return await _fetchProgress();
    } on ServerRequestError catch (failure) {
      if (failure.status == 401) {
        clearSessionData();
        return const OnboardingProgress(signedIn: false);
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _tokens.clear();
    clearSessionData();
  }

  @override
  Future<OnboardingProgress> saveProfile(BodyProfile profile) async {
    try {
      await _send('POST', ApiContract.profile, body: profile.toJson());
    } on ServerRequestError catch (failure) {
      if (failure.code != 'PROFILE_ALREADY_EXISTS') rethrow;
      await _send('PATCH', ApiContract.profile, body: profile.toJson());
    }
    return _fetchProgress();
  }

  @override
  Future<OnboardingProgress> acceptRequiredConsents() async {
    await _send(
      'PATCH',
      ApiContract.me,
      body: {
        'terms_agreed': true,
        'privacy_agreed': true,
        'body_photo_agreed': true,
        'ai_processing_agreed': true,
      },
    );
    return _fetchProgress();
  }

  @override
  Future<OnboardingProgress> saveAnalysis(AnalysisInput input) async {
    _analysis = input;
    return _fetchProgress();
  }

  @override
  Future<OnboardingProgress> complete({required bool prepareAnalysis}) async {
    _completed = true;
    _analysisPrepared = prepareAnalysis;
    return _fetchProgress();
  }

  Future<OnboardingProgress> _fetchProgress() async {
    final me = CurrentUser.fromJson((await _send('GET', ApiContract.me))!);
    BodyProfile? profile;
    if (me.onboardingCompleted &&
        (me.consentCompleted ||
            !me.bodyPhotoAgreed ||
            !me.aiProcessingAgreed)) {
      try {
        profile = BodyProfile.fromJson(
          (await _send('GET', ApiContract.profile))!,
        );
      } on ServerRequestError catch (failure) {
        if (failure.code != 'PROFILE_NOT_FOUND') rethrow;
      }
    }
    return OnboardingProgress(
      serverConsentCompleted: me.consentCompleted,
      account: OnboardingAccount(
        userId: me.userId,
        nickname: me.nickname,
        email: me.email ?? '',
        bodyPhotoAgreed: me.bodyPhotoAgreed,
        aiProcessingAgreed: me.aiProcessingAgreed,
      ),
      profile: profile,
      analysis: _analysis,
      completed: _completed,
      analysisPrepared: _analysisPrepared,
      signedIn: true,
    );
  }

  Future<Map<String, dynamic>?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authorized = true,
  }) => api.send(method, path, body: body, authorized: authorized);
}

typedef ServerRequestError = ApiRequestError;
