import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/auth/data/development_email_verification.dart';

void main() {
  test('5분이 지나면 올바른 코드도 만료되고 재발급할 수 있다', () {
    var now = DateTime(2026, 10, 7);
    final verification = DevelopmentEmailVerification(now: () => now);
    verification.issue('a@example.com');
    expect(verification.remaining, const Duration(minutes: 5));
    now = now.add(const Duration(minutes: 5, seconds: 1));
    expect(verification.remaining, Duration.zero);
    expect(verification.validate('a@example.com', '123456'), contains('만료'));
    verification.issue('a@example.com');
    expect(verification.validate('a@example.com', '123456'), isNull);
  });
  test('코드는 발급한 이메일에만 적용되고 재발급하면 실패 횟수가 초기화된다', () {
    final verification = DevelopmentEmailVerification();
    expect(verification.validate('a@example.com', '123456'), isNotNull);
    verification.issue('A@example.com');
    expect(verification.validate('b@example.com', '123456'), isNotNull);
    expect(verification.validate('a@example.com', '123456'), isNull);
    for (var i = 0; i < 5; i++) {
      expect(verification.validate('a@example.com', '000000'), isNotNull);
    }
    expect(verification.validate('a@example.com', '123456'), isNotNull);
    verification.issue('a@example.com');
    expect(verification.validate('a@example.com', '123456'), isNull);
    verification.clear();
    expect(verification.validate('a@example.com', '123456'), isNotNull);
  });
}
