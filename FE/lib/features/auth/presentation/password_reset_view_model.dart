import 'package:flutter/foundation.dart';
import '../../../core/validation/input_validators.dart';
import '../data/password_reset_repository.dart';
import '../data/development_email_verification.dart';

enum PasswordResetStep { email, sent, password, complete }

class PasswordResetViewModel extends ChangeNotifier {
  PasswordResetViewModel(
    this.repository, {
    String? initialToken,
    DevelopmentEmailVerification? verification,
  }) : verification = verification ?? DevelopmentEmailVerification() {
    if (initialToken != null) openLink(initialToken);
  }
  final PasswordResetRepository repository;
  final DevelopmentEmailVerification verification;
  String? codeError;

  void emailChanged() {
    if (busy) return;
    verification.clear();
    codeError = null;
    _token = '';
    error = null;
    step = PasswordResetStep.email;
    _notify();
  }

  bool validateCode(String email, String code) {
    codeError = verification.remaining == Duration.zero
        ? '인증번호가 만료됐어요. 다시 받아 주세요.'
        : verification.validate(email, code);
    _notify();
    return codeError == null;
  }

  Future<bool> resetWithCode(String email, String code, String password) async {
    if (busy) return false;
    error = null;
    if (!validateCode(email, code)) return false;
    final token = repository.previewToken;
    if (!repository.isPreview || token == null) {
      error = '개발용 인증은 실제 비밀번호 변경에 사용할 수 없어요.';
      _notify();
      return false;
    }
    _token = token;
    final success = await reset(password, password);
    if (success) verification.clear();
    return success;
  }

  Future<bool> resetWithServerCode(
    String email,
    String code,
    String password,
  ) async {
    if (busy) return false;
    codeError = RegExp(r'^\d{6}$').hasMatch(code.trim())
        ? null
        : '6자리 인증번호를 입력해 주세요.';
    error = codeError ?? InputValidators.password(password);
    if (error != null) {
      _notify();
      return false;
    }
    return _run(() async {
      final token = await repository.verify(email, code);
      await repository.reset(token, password);
      verification.clear();
      step = PasswordResetStep.complete;
    });
  }

  PasswordResetStep step = PasswordResetStep.email;
  bool busy = false, _disposed = false;
  String? error;
  String _token = '';

  static String? parseToken(String value) {
    final text = value.trim();
    final uri = Uri.tryParse(text);
    final token = uri != null && uri.hasQuery
        ? uri.queryParameters['token']
        : text;
    return token != null &&
            token.length >= 20 &&
            token.length <= 200 &&
            !RegExp(r'\s').hasMatch(token)
        ? token
        : null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void openLink(String value) {
    if (busy) return;
    final token = parseToken(value);
    if (token == null) {
      error = '메일의 재설정 링크를 확인해 주세요.';
    } else {
      _token = token;
      error = null;
      step = PasswordResetStep.password;
    }
    _notify();
  }

  void requestAgain() {
    if (busy) return;
    _token = '';
    error = null;
    step = PasswordResetStep.email;
    _notify();
  }

  Future<bool> request(String email) async {
    if (busy) return false;
    error = InputValidators.email(email);
    if (error != null) {
      _notify();
      return false;
    }
    return _run(() async {
      await repository.request(email);
      verification.issue(email);
      codeError = null;
      step = PasswordResetStep.sent;
    });
  }

  Future<bool> reset(String password, String confirmation) async {
    if (busy) return false;
    error = InputValidators.password(password);
    if (error == null && password != confirmation) error = '비밀번호가 일치하지 않아요.';
    if (error != null) {
      _notify();
      return false;
    }
    if (_token.isEmpty) {
      error = '메일의 재설정 링크로 다시 진행해 주세요.';
      _notify();
      return false;
    }
    return _run(() async {
      await repository.reset(_token, password);
      _token = '';
      step = PasswordResetStep.complete;
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    _notify();
    try {
      await action();
      return true;
    } on StateError catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = '요청을 처리하지 못했어요. 다시 시도해 주세요.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    verification.clear();
    _token = '';
    super.dispose();
  }
}
