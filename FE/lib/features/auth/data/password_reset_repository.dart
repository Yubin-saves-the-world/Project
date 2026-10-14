import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../../core/network/api_contract.dart';

abstract class PasswordResetRepository {
  Future<void> request(String email);
  Future<String> verify(String email, String code) async =>
      throw StateError('이 환경에서는 인증번호 확인을 사용할 수 없어요.');
  Future<void> reset(String token, String newPassword);
  bool get isPreview => false;
  String? get previewToken => null;
  void dispose() {}
}

/// F-13: 회원 존재 여부를 묻지 않고 링크 요청과 1회용 토큰 변경만 수행합니다.
class ServerPasswordResetRepository extends PasswordResetRepository {
  ServerPasswordResetRepository({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
       _client = client ?? http.Client(),
       _ownsClient = client == null;
  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

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
  ) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll(ApiContract.jsonHeaders(null))
      ..body = jsonEncode(body);
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      );
    } on TimeoutException {
      throw StateError('서버 응답이 늦어요. 잠시 후 다시 시도해 주세요.');
    } on http.ClientException {
      throw StateError('서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
    if (response.statusCode == 204) return null;
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && json is Map<String, dynamic>) {
        return json;
      }
      if (json is Map<String, dynamic> && json['code'] is String) {
        throw StateError(ApiFailure.fromJson(json).displayMessage);
      }
    } on FormatException {
      // HTML 오류 페이지 등 JSON이 아닌 응답도 화면에서 다시 시도할 수 있게 합니다.
    }
    throw StateError('비밀번호 재설정 요청을 처리하지 못했어요. 다시 시도해 주세요.');
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}

/// 메일 발송과 비밀번호 저장 없이 UI 흐름만 검증하는 개발용 저장소입니다.
class PreviewPasswordResetRepository extends PasswordResetRepository {
  PreviewPasswordResetRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final Map<String, DateTime> _lastRequests = {};
  String? _token;
  DateTime? _issuedAt;
  @override
  bool get isPreview => true;
  @override
  String? get previewToken => _token;
  @override
  Future<void> request(String email) async {
    final key = email.trim().toLowerCase();
    final last = _lastRequests[key];
    if (last != null && _now().difference(last) < const Duration(minutes: 5)) {
      return;
    }
    final random = Random.secure();
    _token = List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    _issuedAt = _now();
    _lastRequests[key] = _issuedAt!;
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
