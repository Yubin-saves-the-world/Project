/// Local preview only. No email is sent and no server verification proof is issued.
class DevelopmentEmailVerification {
  DevelopmentEmailVerification({DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  static const code = '123456';
  String? _email;
  DateTime? _issuedAt;
  int _attempts = 0;
  void issue(String email) {
    _email = email.trim().toLowerCase();
    _issuedAt = _now();
    _attempts = 0;
  }

  Duration? get remaining {
    if (_issuedAt == null) return null;
    final duration = const Duration(minutes: 5) - _now().difference(_issuedAt!);
    return duration.isNegative ? Duration.zero : duration;
  }

  String? validate(String email, String value) {
    if (_email != email.trim().toLowerCase() || _issuedAt == null) {
      return '이메일 입력칸에서 인증번호를 받아 주세요.';
    }
    if (_now().difference(_issuedAt!) > const Duration(minutes: 5)) {
      return '인증번호가 만료됐어요. 다시 받아 주세요.';
    }
    if (_attempts >= 5) return '입력 횟수를 초과했어요. 인증번호를 다시 받아 주세요.';
    if (value != code) {
      _attempts++;
      return '인증번호가 일치하지 않아요.';
    }
    return null;
  }

  void clear() {
    _email = null;
    _issuedAt = null;
    _attempts = 0;
  }
}
