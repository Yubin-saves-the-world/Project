import 'email_verification_state.dart';

/// 로컬 미리보기에서만 사용하는 고정 인증번호 검사다.
class DevelopmentEmailVerification extends EmailVerificationState {
  DevelopmentEmailVerification({super.now});
  static const code = '123456';
  int _attempts = 0;

  @override
  void issue(String email) {
    super.issue(email);
    _attempts = 0;
  }

  String? validate(String email, String value) {
    final invalid = validateContext(email);
    if (invalid != null) return invalid;
    if (_attempts >= 5) return '입력 횟수를 초과했어요. 인증번호를 다시 받아 주세요.';
    if (value != code) {
      _attempts++;
      return '인증번호가 일치하지 않아요.';
    }
    return null;
  }

  @override
  void clear() {
    super.clear();
    _attempts = 0;
  }
}
