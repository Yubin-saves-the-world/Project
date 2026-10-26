/// 발송 후 남은 시간과 재요청 간격만 관리한다. 인증 성공은 서버가 판단한다.
class EmailVerificationState {
  EmailVerificationState({DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  String? _email;
  DateTime? _issuedAt;
  final Map<String, List<DateTime>> _requests = {};

  Duration retryAfter(String email) {
    final times = _requests[email.trim().toLowerCase()];
    if (times == null) return Duration.zero;
    final now = _now();
    times.removeWhere(
      (time) => !now.isBefore(time.add(const Duration(hours: 1))),
    );
    if (times.isEmpty) return Duration.zero;
    final cooldown = times.last
        .add(const Duration(seconds: 60))
        .difference(now);
    final quota = times.length >= 5
        ? times.first.add(const Duration(hours: 1)).difference(now)
        : Duration.zero;
    final wait = cooldown > quota ? cooldown : quota;
    return wait.isNegative ? Duration.zero : wait;
  }

  String? requestError(String email) {
    final wait = retryAfter(email);
    if (wait == Duration.zero) return null;
    final seconds = (wait.inMilliseconds / 1000).ceil();
    return seconds > 60
        ? '시간당 5회까지 요청할 수 있어요. ${(seconds / 60).ceil()}분 후 다시 받아 주세요.'
        : '${seconds.toString()}초 후 인증번호를 다시 받아 주세요.';
  }

  void issue(String email) {
    final error = requestError(email);
    if (error != null) throw StateError(error);
    (_requests[email.trim().toLowerCase()] ??= []).add(_now());
    _email = email.trim().toLowerCase();
    _issuedAt = _now();
  }

  Duration? get remaining {
    if (_issuedAt == null) return null;
    final duration = const Duration(minutes: 5) - _now().difference(_issuedAt!);
    return duration.isNegative ? Duration.zero : duration;
  }

  String? validateContext(String email) {
    if (_email != email.trim().toLowerCase() || _issuedAt == null) {
      return '이메일 입력칸에서 인증번호를 받아 주세요.';
    }
    if (_now().difference(_issuedAt!) >= const Duration(minutes: 5)) {
      return '인증번호가 만료됐어요. 다시 받아 주세요.';
    }
    return null;
  }

  void clear() {
    _email = null;
    _issuedAt = null;
  }
}
