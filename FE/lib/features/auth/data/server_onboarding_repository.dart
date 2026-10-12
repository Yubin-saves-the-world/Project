import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_contract.dart';
import '../../body_analysis/data/models/analysis_input.dart';
import '../../profile/data/models/body_profile.dart';
import 'models/auth_session.dart';
import 'models/onboarding_progress.dart';
import 'models/signup_request.dart';
import 'onboarding_repository.dart';
import 'token_store.dart';

/// Spring 서버와 통신하는 저장소. 체형분석 입력은 서버 API가 없어 메모리에만 둔다.
class ServerOnboardingRepository implements OnboardingRepository {
  ServerOnboardingRepository({
    required String baseUrl,
    http.Client? client,
    TokenStore? tokenStore,
    this.timeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _client = client ?? http.Client(),
       _tokens = tokenStore ?? PreferencesTokenStore();

  final String _baseUrl;
  final http.Client _client;
  final TokenStore _tokens;
  final Duration timeout;

  AnalysisInput _analysis = const AnalysisInput();
  bool _completed = false;
  bool _analysisPrepared = false;

  @override
  Future<OnboardingProgress> register(SignupRequest request) async {
    await _send('POST', ApiContract.users, body: request.toJson());
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
        await _tokens.clear();
        return const OnboardingProgress(signedIn: false);
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _tokens.clear();
    _analysis = const AnalysisInput();
    _completed = false;
    _analysisPrepared = false;
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
    final progress = await _fetchProgress();
    if (!progress.consentCompleted) {
      throw StateError('필수 동의를 저장하는 기능이 아직 준비되지 않았어요.');
    }
    return progress;
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
    final me = CurrentUser.fromJson(
      (await _send('GET', ApiContract.me))!,
    );
    BodyProfile? profile;
    if (me.onboardingCompleted) {
      profile = BodyProfile.fromJson(
        (await _send('GET', ApiContract.profile))!,
      );
    }
    return OnboardingProgress(
      account: OnboardingAccount(
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
  }) async {
    final token = authorized ? await _tokens.read() : null;
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll(ApiContract.jsonHeaders(token));
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      );
    } on TimeoutException {
      throw StateError('서버 응답이 늦어요. 잠시 후 다시 시도해 주세요.');
    } on http.ClientException {
      throw StateError('서버에 연결하지 못했어요. 네트워크를 확인해 주세요.');
    }

    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded as Map<String, dynamic>?;
    }
    if (decoded is Map<String, dynamic> && decoded['code'] is String) {
      throw ServerRequestError(ApiFailure.fromJson(decoded));
    }
    throw StateError('서버 오류가 발생했어요. 잠시 후 다시 시도해 주세요.');
  }
}

/// 화면의 오류 표시는 StateError 메시지를 쓰므로, 서버 문구를 그대로 담아 전달한다.
class ServerRequestError extends StateError {
  ServerRequestError(this.failure) : super(failure.displayMessage);
  final ApiFailure failure;

  String get code => failure.code;
  int get status => failure.status;
}
