import 'dart:math';
import 'package:http/http.dart' as http;
import '../../../core/network/api_contract.dart';
import '../../../core/network/api_client.dart';

abstract class PasswordResetRepository {
  Future<void> request(String email);
  Future<String> verify(String email, String code) async =>
      throw StateError('이 환경에서는 인증번호 확인을 사용할 수 없어요.');
  Future<void> reset(String token, String newPassword);
  bool get isPreview => false;
  String? get previewToken => null;
  void dispose() {}
}

/// 인증번호 확인 후 받은 토큰으로 비밀번호를 변경한다.
class ServerPasswordResetRepository extends PasswordResetRepository {
  ServerPasswordResetRepository({
    required String baseUrl,
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
    ApiClient? apiClient,
  }) : api =
           apiClient ??
           ApiClient(baseUrl: baseUrl, client: client, timeout: timeout),
       _ownsApi = apiClient == null;
  final ApiClient api;
  final bool _ownsApi;
  @override
  Future<void> request(String email) => _send(
    'POST',
    ApiContract.passwordResetRequest,
    {'email': email.trim().toLowerCase()},
  );
  @override
  Future<String> verify(String email, String code) async {
    final json = await _send('POST', ApiContract.passwordResetVerification, {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });
    final token = json?['reset_token'];
    if (token is! String || token.isEmpty) {
      throw StateError('인증번호 확인 응답이 올바르지 않아요. 다시 시도해 주세요.');
    }
    return token;
  }

  @override
  Future<void> reset(String token, String newPassword) => _send(
    'PATCH',
    ApiContract.passwordReset,
    {'token': token, 'new_password': newPassword},
  );

  Future<Map<String, dynamic>?> _send(
    String method,
    String path,
    Map<String, String> body,
  ) => api.send(method, path, body: body, authorized: false);

  @override
  void dispose() {
    if (_ownsApi) api.dispose();
  }
}

/// 메일 발송과 비밀번호 저장 없이 UI 흐름만 검증하는 개발용 저장소입니다.
class PreviewPasswordResetRepository extends PasswordResetRepository {
  PreviewPasswordResetRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DateTime Function() _now;

  String? _token;
  DateTime? _issuedAt;
  @override
  bool get isPreview => true;
  @override
  String? get previewToken => _token;
  @override
  Future<void> request(String email) async {
    final random = Random.secure();
    _token = List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    _issuedAt = _now();
  }

  @override
  Future<void> reset(String token, String newPassword) async {
    if (_token == null ||
        token != _token ||
        _issuedAt == null ||
        _now().difference(_issuedAt!) >= const Duration(minutes: 30)) {
      throw StateError('재설정 링크가 만료됐거나 유효하지 않아요. 메일을 다시 요청해 주세요.');
    }
    _token = null;
    _issuedAt = null;
  }
}
