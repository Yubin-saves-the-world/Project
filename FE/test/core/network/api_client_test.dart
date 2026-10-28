import 'dart:async';
import 'dart:convert';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response errorResponse(int status, [String code = 'UNAUTHORIZED']) =>
    http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'code': code,
          'message': '서버 안내',
          'status': status,
          'fields': [
            {'field': 'nickname', 'reason': '이미 사용 중이에요.'},
          ],
        }),
      ),
      status,
    );

void main() {
  test('인증 요청만 토큰을 보내고 오류의 code와 fields를 보존한다', () async {
    final tokens = MemoryTokenStore();
    await tokens.write('token');
    var count = 0;
    final api = ApiClient(
      baseUrl: 'http://server.test/',
      tokenStore: tokens,
      client: MockClient((request) async {
        expect(request.url.path, ApiContract.me);
        expect(
          request.headers['Authorization'],
          count++ == 0 ? 'Bearer token' : isNull,
        );
        return errorResponse(400, 'VALIDATION_FAILED');
      }),
    );
    for (final auth in [true, false]) {
      await expectLater(
        api.send('GET', ApiContract.me, authorized: auth),
        throwsA(
          isA<ApiRequestError>()
              .having((e) => e.code, 'code', 'VALIDATION_FAILED')
              .having(
                (e) => e.failure.fields!.single.field,
                'field',
                'nickname',
              )
              .having((e) => e.message, 'message', '이미 사용 중이에요.'),
        ),
      );
    }
  });
  test('공개 API의 401은 저장된 세션을 지우거나 만료 콜백을 부르지 않는다', () async {
    final tokens = MemoryTokenStore();
    await tokens.write('still-valid');
    var expired = 0;
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      onSessionExpired: () async {
        expired++;
      },
      client: MockClient(
        (_) async => errorResponse(401, 'INVALID_CREDENTIALS'),
      ),
    );
    await expectLater(
      api.send('POST', ApiContract.login, authorized: false),
      throwsStateError,
    );
    expect(expired, 0);
    expect(await tokens.read(), 'still-valid');
  });
  test('여러 인증 요청의 401은 토큰을 지우고 한 번만 로그인으로 보낸다', () async {
    final tokens = MemoryTokenStore();
    await tokens.write('expired');
    var expired = 0;
    final both = Completer<void>();
    var calls = 0;
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      onSessionExpired: () async {
        expect(await tokens.read(), isNull);
        expired++;
      },
      client: MockClient((_) async {
        if (++calls == 2) both.complete();
        await both.future;
        return errorResponse(401);
      }),
    );
    await Future.wait([
      for (var i = 0; i < 2; i++)
        expectLater(api.send('GET', ApiContract.me), throwsStateError),
    ]);
    expect(expired, 1);
    expect(await tokens.read(), isNull);
    await tokens.write('new-session');
    api.sessionStarted();
    await expectLater(api.send('GET', ApiContract.me), throwsStateError);
    expect(expired, 2);
  });
  test('옛 요청이 뒤늦게 401을 받아도 새 로그인 토큰을 삭제하지 않는다', () async {
    final tokens = MemoryTokenStore();
    await tokens.write('old');
    final response = Completer<http.Response>();
    final sent = Completer<void>();
    var expired = 0;
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      onSessionExpired: () async {
        expired++;
      },
      client: MockClient((_) {
        sent.complete();
        return response.future;
      }),
    );
    final pending = expectLater(
      api.send('GET', ApiContract.me),
      throwsStateError,
    );
    await sent.future;
    await tokens.write('new');
    api.sessionStarted();
    response.complete(errorResponse(401));
    await pending;
    expect(await tokens.read(), 'new');
    expect(expired, 0);
  });
  test('multipart는 인증을 붙이고 boundary와 파일 본문을 전송한다', () async {
    final tokens = MemoryTokenStore();
    await tokens.write('photo-token');
    final api = ApiClient(
      baseUrl: 'http://server.test',
      tokenStore: tokens,
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer photo-token');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data; boundary='),
        );
        expect(request.body, contains('name="image"; filename="front.jpg"'));
        expect(request.body, contains('name="type"'));
        return http.Response('', 204);
      }),
    );
    expect(
      await api.upload(
        ApiContract.photos,
        fields: {'type': 'current'},
        files: [
          http.MultipartFile.fromBytes('image', [
            1,
            2,
            3,
          ], filename: 'front.jpg'),
        ],
      ),
      isNull,
    );
  });
  test('비정상 JSON과 응답 지연은 다시 시도할 수 있는 오류다', () async {
    for (final response in ['<html>error</html>', '[1,2]']) {
      final api = ApiClient(
        baseUrl: 'http://server.test',
        client: MockClient((_) async => http.Response(response, 200)),
      );
      await expectLater(
        api.send('GET', ApiContract.me, authorized: false),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('다시 시도'),
          ),
        ),
      );
    }
    final api = ApiClient(
      baseUrl: 'http://server.test',
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    await expectLater(
      api.send('GET', ApiContract.me, authorized: false),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('응답이 늦어요'),
        ),
      ),
    );
  });
}
