import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../body_analysis/data/models/analysis_input.dart';
import '../../profile/data/models/body_profile.dart';
import 'models/onboarding_progress.dart';
import 'models/signup_request.dart';
import 'onboarding_repository.dart';

/// 개발용 저장소. 실제 가입/중복 검사/로그인/AI 요청을 수행하지 않는다.
class LocalOnboardingRepository implements OnboardingRepository {
  LocalOnboardingRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _preferences;
  static const storageKey = 'vitality.onboarding.preview.v1';

  @override
  Future<void> signOut() async {
    await _save((await load()).copyWith(signedIn: false));
  }

  // Explicit local preview: no password verification or token is simulated.
  @override
  Future<OnboardingProgress> login({
    required String email,
    required String password,
  }) async {
    final current = await load();
    if (current.account == null ||
        current.account!.email != email.trim().toLowerCase() ||
        password.isEmpty ||
        password.length > 64) {
      throw StateError('이메일 또는 비밀번호를 확인해 주세요.');
    }
    return _save(current.copyWith(signedIn: true));
  }

  @override
  Future<OnboardingProgress> load() async {
    final raw = await _preferences.getString(storageKey);
    if (raw == null) return const OnboardingProgress();
    try {
      return OnboardingProgress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on FormatException {
      return const OnboardingProgress();
    } on TypeError {
      return const OnboardingProgress();
    } on ArgumentError {
      return const OnboardingProgress();
    }
  }

  Future<OnboardingProgress> _save(OnboardingProgress progress) async {
    await _preferences.setString(storageKey, jsonEncode(progress.toJson()));
    return progress;
  }

  @override
  Future<OnboardingProgress> acceptRequiredConsents() async {
    final current = await load();
    final account = current.account;
    if (account == null) throw StateError('로그인 정보를 확인해 주세요.');
    final next = current.copyWith(
      account: OnboardingAccount(
        nickname: account.nickname,
        email: account.email,
        bodyPhotoAgreed: true,
        aiProcessingAgreed: true,
      ),
    );
    return _save(next);
  }

  @override
  Future<OnboardingProgress> register(SignupRequest request) async {
    if (!request.termsAgreed ||
        !request.privacyAgreed ||
        !request.bodyPhotoAgreed ||
        !request.aiProcessingAgreed) {
      throw StateError('필수 항목에 동의해 주세요.');
    }
    return _save(
      const OnboardingProgress(signedIn: false).copyWith(
        account: OnboardingAccount(
          nickname: request.nickname.trim(),
          email: request.email.trim().toLowerCase(),
          bodyPhotoAgreed: request.bodyPhotoAgreed,
          aiProcessingAgreed: request.aiProcessingAgreed,
        ),
      ),
    );
  }

  @override
  Future<OnboardingProgress> saveProfile(BodyProfile profile) async {
    final current = await load();
    if (current.account == null) throw StateError('가입 정보를 먼저 입력해 주세요.');
    return _save(current.copyWith(profile: profile));
  }

  @override
  Future<OnboardingProgress> saveAnalysis(AnalysisInput input) async {
    return _save((await load()).copyWith(analysis: input));
  }

  @override
  Future<OnboardingProgress> complete({required bool prepareAnalysis}) async {
    final current = await load();
    if (current.account == null || current.profile == null) {
      throw StateError('신체 정보를 먼저 저장해 주세요.');
    }
    return _save(
      current.copyWith(completed: true, analysisPrepared: prepareAnalysis),
    );
  }
}
