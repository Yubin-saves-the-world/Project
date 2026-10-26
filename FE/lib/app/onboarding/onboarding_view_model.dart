import 'package:flutter/foundation.dart';

import '../../core/media/image_picker_service.dart';
import '../../core/validation/input_validators.dart';
import '../../features/auth/data/models/onboarding_progress.dart';
import '../../features/auth/data/models/signup_request.dart';
import '../../features/auth/data/onboarding_repository.dart';
import '../../features/auth/data/server_onboarding_repository.dart';
import '../../features/auth/data/development_email_verification.dart';
import '../../features/auth/data/email_verification_state.dart';
import '../../features/body_analysis/data/models/analysis_input.dart';
import '../../features/photos/data/models/selected_photo.dart';
import '../../features/profile/data/models/body_profile.dart';

class OnboardingViewModel extends ChangeNotifier {
  OnboardingViewModel({
    required this.repository,
    required this.photoPicker,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final OnboardingRepository repository;
  final PhotoPicker photoPicker;

  OnboardingProgress progress = const OnboardingProgress();
  AnalysisInput analysis = const AnalysisInput();
  bool loading = true;
  bool busy = false;
  bool _disposed = false;
  int step = 0;
  String? error;
  bool showLogin = false;
  bool _registrationPendingLogin = false;
  late final EmailVerificationState emailVerification =
      usesRealEmailVerification
      ? EmailVerificationState(now: _now)
      : DevelopmentEmailVerification(now: _now);
  String verificationCode = '';
  bool issueVerification() {
    try {
      emailVerification.issue(email);
      error = null;
      _notify();
      return true;
    } on StateError catch (e) {
      showError(e.message);
      return false;
    }
  }

  String? emailVerificationToken;
  String? _verifiedEmail;
  DateTime? _verificationExpiresAt;
  String? verificationError;
  Map<String, String> fieldErrors = {};
  bool get usesRealEmailVerification => repository.usesRealEmailVerification;

  Future<bool> sendVerification() async {
    if (busy || loading) return false;
    final target = email.trim().toLowerCase();
    final invalid =
        InputValidators.email(target) ?? emailVerification.requestError(target);
    if (invalid != null) {
      showError(invalid);
      return false;
    }
    if (!usesRealEmailVerification) return issueVerification();
    return _run(() async {
      await repository.sendEmailCode(target);
      resetEmailVerification();
      emailVerification.issue(target);
    });
  }

  Future<String?> verifyEmailCode(String emailInput, String code) async {
    if (busy || loading) return '처리 중이에요. 잠시만 기다려 주세요.';
    verificationError = null;
    final target = emailInput.trim().toLowerCase();
    if (!usesRealEmailVerification) {
      return verificationError =
          (emailVerification as DevelopmentEmailVerification).validate(
            target,
            code,
          );
    }
    if (emailVerificationToken != null &&
        _verifiedEmail == target &&
        _verificationExpiresAt != null &&
        _now().isBefore(_verificationExpiresAt!)) {
      return null;
    }
    emailVerificationToken = null;
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      return verificationError = '인증번호 6자리를 입력해 주세요.';
    }
    final success = await _run(() async {
      emailVerificationToken = await repository.confirmEmailCode(
        email: target,
        code: code.trim(),
      );
      _verifiedEmail = target;
      _verificationExpiresAt = _now().add(const Duration(minutes: 30));
    });
    if (!success) verificationError = error;
    return verificationError;
  }

  void resetEmailVerification() {
    if (error == verificationError || fieldErrors.containsValue(error)) {
      error = null;
    }
    emailVerification.clear();
    verificationCode = '';
    emailVerificationToken = null;
    _verifiedEmail = null;
    _verificationExpiresAt = null;
    verificationError = null;
    fieldErrors = {};
  }

  void clearFieldError(String field) {
    final previous = fieldErrors.remove(field);
    if (previous != null) {
      if (error == previous) error = null;
      _notify();
    }
  }

  int loginFailures = 0;
  bool get suggestPasswordReset => loginFailures >= 5;

  String nickname = '', email = '', password = '', passwordConfirmation = '';
  bool termsAgreed = false, privacyAgreed = false;
  bool bodyPhotoAgreed = false, aiProcessingAgreed = false;
  String height = '', weight = '', age = '';
  Gender? gender;
  GoalType? goalType;
  int? frequency;
  ExperienceLevel? experienceLevel;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize({bool startWithLogin = false}) async {
    loading = true;
    error = null;
    _notify();
    try {
      final saved = await repository.load();
      if (saved.account != null && !saved.signedIn) {
        _clearDraft();
        progress = const OnboardingProgress(signedIn: false);
        step = 0;
        showLogin = true;
        return;
      }
      progress = saved;
      step = progress.nextStep;
      showLogin = progress.account == null
          ? startWithLogin
          : !progress.signedIn;
      final account = progress.account;
      if (account != null) {
        nickname = account.nickname;
        email = account.email;
        termsAgreed = privacyAgreed = true;
        bodyPhotoAgreed = account.bodyPhotoAgreed;
        aiProcessingAgreed = account.aiProcessingAgreed;
      }
      final profile = progress.profile;
      if (profile != null) {
        height = _number(profile.heightCm);
        weight = _number(profile.weightKg);
        age = '${profile.age}';
        gender = profile.gender == Gender.none ? null : profile.gender;
        goalType = profile.goalType;
        frequency = profile.weeklyFrequency;
        experienceLevel = profile.experienceLevel;
      }
      analysis = progress.analysis;
      for (final slot in PhotoSlot.values) {
        final photo = photoFor(slot);
        if (photo != null && !await photoPicker.exists(photo)) {
          analysis = analysis.copyWith(slot: slot, photo: null);
        }
      }
      final recovered = await photoPicker.recover();
      if (recovered != null && bodyPhotoAgreed) {
        analysis = analysis.copyWith(slot: recovered.$1, photo: recovered.$2);
        progress = await repository.saveAnalysis(analysis);
      }
      step = progress.nextStep;
      if (progress.signedIn && progress.onboardingCompleted) {
        progress = progress.copyWith(completed: true);
      }
    } catch (_) {
      error = '저장된 정보를 불러오지 못했어요. 다시 시도해 주세요.';
    } finally {
      loading = false;
      _notify();
    }
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  void updateConsent({bool? terms, bool? privacy, bool? photo, bool? ai}) {
    termsAgreed = terms ?? termsAgreed;
    privacyAgreed = privacy ?? privacyAgreed;
    bodyPhotoAgreed = photo ?? bodyPhotoAgreed;
    aiProcessingAgreed = ai ?? aiProcessingAgreed;
    if (!bodyPhotoAgreed) {
      for (final slot in PhotoSlot.values) {
        analysis = analysis.copyWith(slot: slot, photo: null);
      }
    }
    error = null;
    _notify();
  }

  void updateProfile({
    Gender? gender,
    GoalType? goal,
    int? frequency,
    ExperienceLevel? experience,
  }) {
    this.gender = gender ?? this.gender;
    goalType = goal ?? goalType;
    this.frequency = frequency ?? this.frequency;
    experienceLevel = experience ?? experienceLevel;
    error = null;
    _notify();
  }

  void setMethod(AnalysisMethod method) {
    analysis = analysis.copyWith(method: method);
    error = null;
    _notify();
  }

  void setText(String value) {
    analysis = analysis.copyWith(text: value);
  }

  void setGoalDescription(String value) {
    analysis = analysis.copyWith(goalDescription: value);
  }

  SelectedPhoto? photoFor(PhotoSlot slot) => switch (slot) {
    PhotoSlot.front => analysis.front,
    PhotoSlot.side => analysis.side,
    PhotoSlot.goal => analysis.goal,
  };

  void back() {
    if (busy || step == 0) return;
    step--;
    error = null;
    _notify();
  }

  void showError(String message) {
    error = message;
    _notify();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy || loading) return false;
    busy = true;
    error = null;
    fieldErrors = {};
    _notify();
    try {
      await action();
      return true;
    } catch (failure) {
      if (failure is ServerRequestError) {
        fieldErrors = {
          for (final item in failure.failure.fields ?? [])
            item.field: item.reason,
        };
        final field = switch (failure.code) {
          'EMAIL_DUPLICATED' => 'email',
          'NICKNAME_DUPLICATED' => 'nickname',
          _ => null,
        };
        if (field != null) fieldErrors[field] = failure.message;
        if (failure.code == 'EMAIL_NOT_VERIFIED') {
          emailVerificationToken = null;
          _verificationExpiresAt = null;
        }
      }
      error = failure is PhotoPickerException
          ? failure.message
          : failure is StateError
          ? failure.message.toString()
          : '저장하지 못했어요. 입력은 유지되니 다시 시도해 주세요.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> submitAccount() async {
    final validation =
        InputValidators.nickname(nickname) ??
        InputValidators.email(email) ??
        InputValidators.password(password);
    if (validation != null) {
      showError(validation);
      return false;
    }
    if (!termsAgreed ||
        !privacyAgreed ||
        !bodyPhotoAgreed ||
        !aiProcessingAgreed) {
      showError('가입하려면 필수 동의 4개를 모두 확인해 주세요.');
      return false;
    }
    return _run(() async {
      final previousAnalysis = progress.analysis;
      if (progress.account != null && progress.signedIn) {
        step = 1;
        return;
      }
      if (!_registrationPendingLogin) {
        if (usesRealEmailVerification &&
            (emailVerificationToken == null ||
                _verifiedEmail != email.trim().toLowerCase() ||
                _verificationExpiresAt == null ||
                !_now().isBefore(_verificationExpiresAt!))) {
          throw StateError('이메일 인증을 먼저 완료해 주세요.');
        }
        progress = await repository.register(
          SignupRequest(
            emailVerificationToken: usesRealEmailVerification
                ? emailVerificationToken
                : null,
            nickname: nickname,
            email: email,
            password: password,
            termsAgreed: termsAgreed,
            privacyAgreed: privacyAgreed,
            bodyPhotoAgreed: bodyPhotoAgreed,
            aiProcessingAgreed: aiProcessingAgreed,
          ),
        );
        _registrationPendingLogin = true;
      }
      progress = await repository.login(email: email, password: password);
      _registrationPendingLogin = false;
      await _discardRemoved(previousAnalysis, analysis);
      step = 1;
    });
  }

  Future<bool> submitProfile() async {
    final validation =
        InputValidators.metric(
          height,
          label: '키',
          min: 100,
          max: 250,
          decimalPlaces: 1,
        ) ??
        InputValidators.metric(
          weight,
          label: '몸무게',
          min: 30,
          max: 250,
          decimalPlaces: 1,
        ) ??
        InputValidators.metric(
          age,
          label: '나이',
          min: 10,
          max: 100,
          integer: true,
        );
    if (validation != null) {
      showError('신체 정보의 입력 범위를 확인해 주세요.');
      return false;
    }
    if (frequency == null || frequency! < 1 || frequency! > 7) {
      showError('주 운동 횟수를 선택해 주세요.');
      return false;
    }
    if (gender == null || gender == Gender.none) {
      showError('성별을 선택해 주세요.');
      return false;
    }
    if (goalType == null || experienceLevel == null) {
      showError('운동 목적과 운동 기간을 선택해 주세요.');
      return false;
    }
    return _run(() async {
      progress = await repository.saveProfile(
        BodyProfile(
          heightCm: double.parse(height),
          weightKg: double.parse(weight),
          age: int.parse(age),
          gender: gender!,
          goalType: goalType!,
          weeklyFrequency: frequency!,
          experienceLevel: experienceLevel!,
        ),
      );
      step = 2;
    });
  }

  Future<void> pickPhoto(PhotoSlot slot, PhotoSource source) async {
    if (!bodyPhotoAgreed) {
      showError('사진 이용 동의가 필요해요. 첫 단계에서 동의를 선택해 주세요.');
      return;
    }
    await _run(() async {
      final selected = await photoPicker.pick(slot, source);
      if (selected != null) {
        final previous = analysis;
        final next = analysis.copyWith(slot: slot, photo: selected);
        try {
          progress = await repository.saveAnalysis(next);
        } catch (_) {
          await photoPicker.discard(selected);
          rethrow;
        }
        analysis = next;
        await _discardRemoved(previous, next);
      }
    });
  }

  Future<void> removePhoto(PhotoSlot slot) async {
    await _run(() async {
      final previous = analysis;
      final next = analysis.copyWith(slot: slot, photo: null);
      progress = await repository.saveAnalysis(next);
      analysis = next;
      await _discardRemoved(previous, next);
    });
  }

  Future<void> _discardRemoved(
    AnalysisInput before,
    AnalysisInput after,
  ) async {
    final active = {after.front?.path, after.side?.path, after.goal?.path};
    for (final photo in [before.front, before.side, before.goal]) {
      if (photo != null && !active.contains(photo.path)) {
        await photoPicker.discard(photo);
      }
    }
  }

  Future<bool> finish({required bool prepareAnalysis}) async {
    if (analysis.text.length > 500 || analysis.goalDescription.length > 200) {
      showError('몸 상태는 500자, 목표 설명은 200자 이하로 적어 주세요.');
      return false;
    }
    if (prepareAnalysis) {
      if (!aiProcessingAgreed ||
          (analysis.method == AnalysisMethod.photo && !bodyPhotoAgreed)) {
        showError('분석을 준비하려면 첫 단계에서 사진·AI 이용 동의를 확인해 주세요.');
        return false;
      }
      if (analysis.method == AnalysisMethod.photo && analysis.front == null) {
        showError('정면 사진을 추가해 주세요. 측면과 목표 사진은 선택이에요.');
        return false;
      }
      if (analysis.method == AnalysisMethod.text &&
          analysis.text.trim().isEmpty) {
        showError('몸 상태나 고민을 글로 적어 주세요.');
        return false;
      }
    }
    return _run(() async {
      progress = await repository.saveAnalysis(analysis);
      progress = await repository.complete(prepareAnalysis: prepareAnalysis);
      password = passwordConfirmation = '';
    });
  }

  Future<bool> login(String emailInput, String passwordInput) async {
    if (InputValidators.email(emailInput) != null ||
        passwordInput.isEmpty ||
        passwordInput.length > 64) {
      showError('이메일 또는 비밀번호를 확인해 주세요.');
      return false;
    }
    final success = await _run(() async {
      try {
        progress = await repository.login(
          email: emailInput,
          password: passwordInput,
        );
      } on ServerRequestError catch (e) {
        if (e.code == 'INVALID_CREDENTIALS') loginFailures++;
        rethrow;
      } on StateError catch (e) {
        if (e.message.contains('이메일') && e.message.contains('비밀번호')) {
          loginFailures++;
        }
        rethrow;
      }
    });
    if (success) {
      loginFailures = 0;
      await initialize();
      if (progress.onboardingCompleted) {
        progress = progress.copyWith(completed: true);
      }
      showLogin = false;
      _notify();
    }
    return success;
  }

  Future<bool> acceptRequiredConsents() async {
    if (!termsAgreed ||
        !privacyAgreed ||
        !bodyPhotoAgreed ||
        !aiProcessingAgreed) {
      showError('필수 동의 4개를 모두 확인해 주세요.');
      return false;
    }
    return _run(() async {
      progress = await repository.acceptRequiredConsents();
      if (progress.onboardingCompleted) {
        progress = progress.copyWith(completed: true);
      }
      step = progress.nextStep;
    });
  }

  void openSignup() {
    if (busy) return;
    showLogin = false;
    step = 0;
    error = null;
    _notify();
  }

  void openLogin() {
    if (busy) return;
    showLogin = true;
    error = null;
    _notify();
  }

  Future<bool> signOut() => _run(() async {
    await repository.signOut();
    progress = const OnboardingProgress(signedIn: false);
    analysis = const AnalysisInput();
    step = 0;
    showLogin = true;
    _clearDraft();
  });

  void _clearDraft() {
    analysis = const AnalysisInput();
    nickname = email = password = passwordConfirmation = '';
    resetEmailVerification();
    _registrationPendingLogin = false;
    termsAgreed = privacyAgreed = bodyPhotoAgreed = aiProcessingAgreed = false;
    height = weight = age = '';
    gender = null;
    goalType = null;
    frequency = null;
    experienceLevel = null;
  }

  @override
  void dispose() {
    _disposed = true;
    password = passwordConfirmation = '';
    resetEmailVerification();
    super.dispose();
  }
}
