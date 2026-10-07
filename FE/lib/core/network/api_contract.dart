/// Team API baseline received 2026-10-06. Final requirements, API and ERD are in docs/final-specs.
abstract final class ApiContract {
  static const prefix = '/api';
  static const users = '$prefix/users';
  static const login = '$prefix/auth/login';
  static const logout = '$prefix/auth/logout';
  static const googleLogin = '$prefix/auth/oauth/google';
  static const kakaoLogin = '$prefix/auth/oauth/kakao';
  static const me = '$prefix/users/me';
  static const profile = '$me/profile';
  static const photos = '$prefix/photos';
  static String photo(int id) => '$photos/$id';
  static const accessTokenLifetimeSeconds = 604800;
  static const maxPhotoBytes = 10 * 1024 * 1024;
  static const photoMaxEdge = 1024;
  static const photoLimit = 20;
  static const signedUrlLifetimeSeconds = 3600;
  static Map<String, String> jsonHeaders(String? accessToken) => {
    'Content-Type': 'application/json; charset=utf-8',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };
  // Multipart requests must let their transport set the boundary.
}

class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    required this.status,
    required this.fields,
  });
  final String code, message;
  final int status;
  final Map<String, dynamic>? fields;
  factory ApiFailure.fromJson(Map<String, dynamic> json) => ApiFailure(
    code: json['code'] as String,
    message: json['message'] as String,
    status: json['status'] as int,
    fields: json['fields'] == null
        ? null
        : Map<String, dynamic>.from(json['fields'] as Map),
  );
}
