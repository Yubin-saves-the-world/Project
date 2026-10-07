class SignupRequest {
  const SignupRequest({
    required this.nickname,
    required this.email,
    required this.password,
    required this.termsAgreed,
    required this.privacyAgreed,
    required this.bodyPhotoAgreed,
    required this.aiProcessingAgreed,
    this.policyVersion,
  });

  final String nickname;
  final String email;
  final String password;
  final bool termsAgreed;
  final bool privacyAgreed;
  final bool bodyPhotoAgreed;
  final bool aiProcessingAgreed;
  final String? policyVersion;

  Map<String, dynamic> toJson() => {
    'nickname': nickname.trim(),
    'email': email.trim().toLowerCase(),
    'password': password,
    'terms_agreed': termsAgreed,
    'privacy_agreed': privacyAgreed,
    'body_photo_agreed': bodyPhotoAgreed,
    'ai_processing_agreed': aiProcessingAgreed,
    if (policyVersion != null) 'policy_version': policyVersion,
  };
}
