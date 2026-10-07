/// Server login response. Local preview never creates an instance or fake JWT.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.onboardingCompleted,
  });
  final String accessToken, tokenType;
  final int expiresIn;
  final bool onboardingCompleted;
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['access_token'] as String,
    tokenType: json['token_type'] as String,
    expiresIn: json['expires_in'] as int,
    onboardingCompleted: json['onboarding_completed'] as bool,
  );
}

class CurrentUser {
  const CurrentUser({
    required this.userId,
    required this.email,
    required this.nickname,
    required this.role,
    required this.onboardingCompleted,
    required this.consentCompleted,
    required this.bodyPhotoAgreed,
    required this.aiProcessingAgreed,
    required this.createdAt,
  });
  final int userId;
  final String? email;
  final String nickname, role;
  final bool onboardingCompleted,
      consentCompleted,
      bodyPhotoAgreed,
      aiProcessingAgreed;
  final DateTime createdAt;
  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
    userId: json['user_id'] as int,
    email: json['email'] as String?,
    nickname: json['nickname'] as String,
    role: json['role'] as String,
    onboardingCompleted: json['onboarding_completed'] as bool,
    consentCompleted: json['consent_completed'] as bool,
    bodyPhotoAgreed: json['body_photo_agreed'] as bool,
    aiProcessingAgreed: json['ai_processing_agreed'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
  String get initialDestination => !consentCompleted
      ? 'consent'
      : !onboardingCompleted
      ? 'profile'
      : 'home';
}
