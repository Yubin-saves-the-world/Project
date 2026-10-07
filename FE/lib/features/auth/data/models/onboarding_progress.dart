import '../../../body_analysis/data/models/analysis_input.dart';
import '../../../profile/data/models/body_profile.dart';

class OnboardingAccount {
  const OnboardingAccount({
    required this.nickname,
    required this.email,
    required this.bodyPhotoAgreed,
    required this.aiProcessingAgreed,
  });
  final String nickname;
  final String email;
  final bool bodyPhotoAgreed;
  final bool aiProcessingAgreed;

  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'email': email,
    'body_photo_agreed': bodyPhotoAgreed,
    'ai_processing_agreed': aiProcessingAgreed,
  };
  factory OnboardingAccount.fromJson(Map<String, dynamic> json) =>
      OnboardingAccount(
        nickname: json['nickname'] as String,
        email: json['email'] as String,
        bodyPhotoAgreed: json['body_photo_agreed'] as bool,
        aiProcessingAgreed: json['ai_processing_agreed'] as bool,
      );
}

class OnboardingProgress {
  const OnboardingProgress({
    this.account,
    this.profile,
    this.analysis = const AnalysisInput(),
    this.completed = false,
    this.analysisPrepared = false,
    this.signedIn = true,
  });
  final OnboardingAccount? account;
  final BodyProfile? profile;
  final AnalysisInput analysis;
  final bool completed;
  final bool analysisPrepared;
  final bool signedIn;
  bool get onboardingCompleted => profile != null;
  bool get consentCompleted =>
      account != null &&
      account!.bodyPhotoAgreed &&
      account!.aiProcessingAgreed;
  int get nextStep => profile != null
      ? 2
      : account != null
      ? 1
      : 0;

  OnboardingProgress copyWith({
    OnboardingAccount? account,
    BodyProfile? profile,
    AnalysisInput? analysis,
    bool? completed,
    bool? analysisPrepared,
    bool? signedIn,
  }) => OnboardingProgress(
    account: account ?? this.account,
    profile: profile ?? this.profile,
    analysis: analysis ?? this.analysis,
    completed: completed ?? this.completed,
    analysisPrepared: analysisPrepared ?? this.analysisPrepared,
    signedIn: signedIn ?? this.signedIn,
  );

  // 비밀번호·토큰은 로컬 미리보기 데이터에 저장하지 않는다.
  Map<String, dynamic> toJson() => {
    'account': account?.toJson(),
    'profile': profile?.toJson(),
    'analysis': analysis.toJson(),
    'analysis_setup_completed': completed,
    'onboarding_completed': onboardingCompleted,
    'preview_signed_in': signedIn,
    'analysis_prepared': analysisPrepared,
  };
  factory OnboardingProgress.fromJson(Map<String, dynamic> json) =>
      OnboardingProgress(
        account: json['account'] == null
            ? null
            : OnboardingAccount.fromJson(
                Map<String, dynamic>.from(json['account'] as Map),
              ),
        profile: json['profile'] == null
            ? null
            : BodyProfile.fromJson(
                Map<String, dynamic>.from(json['profile'] as Map),
              ),
        analysis: AnalysisInput.fromJson(
          Map<String, dynamic>.from(json['analysis'] as Map),
        ),
        completed:
            (json['analysis_setup_completed'] ?? json['completed']) as bool? ??
            false,
        signedIn: json['preview_signed_in'] as bool? ?? true,
        analysisPrepared: json['analysis_prepared'] as bool? ?? false,
      );
}
