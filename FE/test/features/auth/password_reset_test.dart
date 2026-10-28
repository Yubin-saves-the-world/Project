import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/features/auth/data/password_reset_repository.dart';
import 'package:fe/features/auth/data/development_email_verification.dart';
import 'package:fe/features/auth/presentation/password_reset_view_model.dart';
import 'package:fe/features/auth/presentation/pages/password_reset_page.dart';
import 'package:fe/ui/core/theme/app_theme.dart';

void main() {
  test('F-13 메일 요청과 변경 API는 인증 헤더 없이 정확한 본문을 전송한다', () async {
    final requests = <http.Request>[];
    final repository = ServerPasswordResetRepository(
      baseUrl: 'http://localhost:8080/',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );
    await repository.request(' USER@EXAMPLE.COM ');
    await repository.reset('0123456789abcdef0123456789abcdef', 'abcd1234');
    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, '/api/auth/password/reset-request');
    expect(jsonDecode(requests[0].body), {'email': 'user@example.com'});
    expect(requests[1].method, 'PATCH');
    expect(requests[1].url.path, '/api/auth/password/reset');
    expect(jsonDecode(requests[1].body), {
      'token': '0123456789abcdef0123456789abcdef',
      'new_password': 'abcd1234',
    });
    expect(
      requests.every((r) => !r.headers.containsKey('Authorization')),
      isTrue,
    );
  });
  test('서버 만료 토큰 메시지와 HTML 오류도 예외 없이 화면 상태에 남는다', () async {
    final repository = ServerPasswordResetRepository(
      baseUrl: 'http://localhost:8080',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'code': 'RESET_TOKEN_INVALID',
            'message': '만료된 링크입니다.',
            'status': 400,
            'fields': null,
          }),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final model = PasswordResetViewModel(
      repository,
      initialToken: '0123456789abcdef0123456789abcdef',
    );
    expect(await model.reset('abcd1234', 'abcd1234'), isFalse);
    expect(model.error, '만료된 링크입니다.');
    expect(model.step, PasswordResetStep.password);
    final htmlRepo = ServerPasswordResetRepository(
      baseUrl: 'http://localhost:8080',
      client: MockClient((_) async => http.Response('<html>error</html>', 500)),
    );
    final second = PasswordResetViewModel(htmlRepo);
    expect(await second.request('user@example.com'), isFalse);
    expect(second.error, contains('다시 시도'));
    model.dispose();
    second.dispose();
  });
  test('개발용 링크는 30분·1회용이며 링크 URL에서 토큰을 읽는다', () async {
    var now = DateTime(2026, 10, 14, 12);
    final repository = PreviewPasswordResetRepository(now: () => now);
    await repository.request('user@example.com');
    final token = repository.previewToken!;
    expect(
      PasswordResetViewModel.parseToken(
        'https://example.com/password-reset?token=$token',
      ),
      token,
    );
    expect(PasswordResetViewModel.parseToken('invalid'), isNull);
    await repository.reset(token, 'abcd1234');
    await expectLater(repository.reset(token, 'abcd1234'), throwsStateError);
    now = now.add(const Duration(minutes: 5));
    await repository.request('user@example.com');
    final secondToken = repository.previewToken!;
    now = now.add(const Duration(minutes: 30));
    await expectLater(
      repository.reset(secondToken, 'abcd1234'),
      throwsStateError,
    );
  });
  test('개발용 인증은 5회 제한·만료·이메일 변경을 검사한다', () async {
    var now = DateTime(2026, 10, 14, 12);
    final repository = PreviewPasswordResetRepository(now: () => now);
    final verification = DevelopmentEmailVerification(now: () => now);
    final model = PasswordResetViewModel(
      repository,
      verification: verification,
    );
    await model.request('user@example.com');
    for (var i = 0; i < 5; i++) {
      expect(
        await model.resetWithCode('user@example.com', '000000', 'abcd1234'),
        isFalse,
      );
    }
    expect(
      await model.resetWithCode('user@example.com', '123456', 'abcd1234'),
      isFalse,
    );
    expect(model.codeError, contains('입력 횟수'));
    now = now.add(const Duration(seconds: 60));
    await model.request('user@example.com');
    now = now.add(const Duration(minutes: 5));
    expect(
      await model.resetWithCode('user@example.com', '123456', 'abcd1234'),
      isFalse,
    );
    expect(model.codeError, contains('만료'));
    await model.request('user@example.com');
    model.emailChanged();
    expect(
      await model.resetWithCode('other@example.com', '123456', 'abcd1234'),
      isFalse,
    );
    model.dispose();
  });
  testWidgets('비밀번호 찾기는 한 화면에서 발송·오류 검증·변경 완료를 제공한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PasswordResetPage(repository: PreviewPasswordResetRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reset-email')), findsOneWidget);
    expect(find.byKey(const Key('reset-code')), findsOneWidget);
    expect(find.byKey(const Key('reset-password')), findsOneWidget);
    await tester.tap(find.text('인증번호 받기'));
    await tester.pumpAndSettle();
    expect(find.text('올바른 이메일 주소를 입력해 주세요.'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('reset-email')),
        matching: find.byType(TextFormField),
      ),
      'user@example.com',
    );
    await tester.tap(find.text('인증번호 받기'));
    await tester.pumpAndSettle();
    expect(find.text('인증번호를 보냈어요'), findsOneWidget);
    expect(find.text('5분'), findsOneWidget);
    expect(find.text('5회'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    final code = find.descendant(
      of: find.byKey(const Key('reset-code')),
      matching: find.byType(TextFormField),
    );
    final password = find.descendant(
      of: find.byKey(const Key('reset-password')),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(code, '000000');
    await tester.enterText(password, 'abc123');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('비밀번호 변경'));
    await tester.tap(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();
    expect(find.text('인증번호가 일치하지 않아요.'), findsOneWidget);
    expect(find.text('8~64자, 영문과 숫자를 함께 사용해 주세요.'), findsOneWidget);
    await tester.enterText(code, '123456');
    await tester.enterText(password, 'abcd1234');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('비밀번호 변경'));
    await tester.tap(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호 변경 요청 완료'), findsOneWidget);
    expect(find.text('로그인하러 가기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('메일 링크로 진입한 서버 화면은 인증번호를 토큰으로 보내지 않는다', (tester) async {
    final requests = <http.Request>[];
    final repository = ServerPasswordResetRepository(
      baseUrl: 'http://localhost:8080',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );
    const token = '0123456789abcdef0123456789abcdef';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PasswordResetPage(repository: repository, initialToken: token),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('reset-password')),
        matching: find.byType(TextFormField),
      ),
      'abcd1234',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('비밀번호 변경'));
    await tester.tap(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();
    expect(requests.single.method, 'PATCH');
    expect(jsonDecode(requests.single.body)['token'], token);
    expect(find.text('비밀번호가 변경됐어요'), findsOneWidget);
  });
  testWidgets('작은 화면과 큰 글꼴에서도 비밀번호 찾기를 입력한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PasswordResetPage(repository: PreviewPasswordResetRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('비밀번호 변경'));
    expect(tester.takeException(), isNull);
  });

  MockClient serverClient(
    List<http.Request> requests, {
    int verifyStatus = 200,
    Map<String, dynamic>? verifyBody,
  }) => MockClient((request) async {
    requests.add(request);
    if (request.url.path == '/api/auth/password/reset-verification') {
      return http.Response(
        jsonEncode(
          verifyBody ??
              {
                'reset_token': 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789abcdefg',
                'expires_in': 1800,
              },
        ),
        verifyStatus,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('', 204);
  });
  test('서버 인증번호 확인은 이메일·번호를 보내고 재설정 토큰을 돌려받는다', () async {
    final requests = <http.Request>[];
    final repository = ServerPasswordResetRepository(
      baseUrl: 'http://localhost:8080',
      client: serverClient(requests),
    );
    final token = await repository.verify(' USER@EXAMPLE.COM ', ' 123456 ');
    expect(token, 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789abcdefg');
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/auth/password/reset-verification');
    expect(jsonDecode(requests.single.body), {
      'email': 'user@example.com',
      'code': '123456',
    });
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
  });
  test('서버 인증번호로 변경하면 확인 후 받은 토큰으로 비밀번호를 바꾼다', () async {
    final requests = <http.Request>[];
    final model = PasswordResetViewModel(
      ServerPasswordResetRepository(
        baseUrl: 'http://localhost:8080',
        client: serverClient(requests),
      ),
    );
    expect(
      await model.resetWithServerCode('user@example.com', '123456', 'abcd1234'),
      isTrue,
    );
    expect(requests.map((r) => '${r.method} ${r.url.path}').toList(), [
      'POST /api/auth/password/reset-verification',
      'PATCH /api/auth/password/reset',
    ]);
    expect(jsonDecode(requests[1].body), {
      'token': 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789abcdefg',
      'new_password': 'abcd1234',
    });
    expect(model.step, PasswordResetStep.complete);
    model.dispose();
  });
  test('서버 인증번호가 틀리면 변경 요청을 보내지 않고 서버 문구를 보여준다', () async {
    final requests = <http.Request>[];
    final model = PasswordResetViewModel(
      ServerPasswordResetRepository(
        baseUrl: 'http://localhost:8080',
        client: serverClient(
          requests,
          verifyStatus: 400,
          verifyBody: {
            'code': 'EMAIL_CODE_INVALID',
            'message': '인증번호가 일치하지 않아요.',
            'status': 400,
            'fields': null,
          },
        ),
      ),
    );
    expect(
      await model.resetWithServerCode('user@example.com', '000000', 'abcd1234'),
      isFalse,
    );
    expect(model.error, '인증번호가 일치하지 않아요.');
    expect(requests.length, 1);
    expect(model.step, isNot(PasswordResetStep.complete));
    expect(
      await model.resetWithServerCode('user@example.com', '12', 'abcd1234'),
      isFalse,
    );
    expect(model.codeError, '6자리 인증번호를 입력해 주세요.');
    expect(requests.length, 1);
    model.dispose();
  });
  testWidgets('서버 연결 화면도 인증번호를 입력해 한 번에 비밀번호를 바꾼다', (tester) async {
    final requests = <http.Request>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PasswordResetPage(
          repository: ServerPasswordResetRepository(
            baseUrl: 'http://localhost:8080',
            client: serverClient(requests),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('인증번호 받기'), findsOneWidget);
    expect(find.text('재설정 링크'), findsNothing);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('reset-email')),
        matching: find.byType(TextFormField),
      ),
      'user@example.com',
    );
    await tester.tap(find.text('인증번호 받기'));
    await tester.pumpAndSettle();
    expect(find.text('인증번호를 보냈어요'), findsOneWidget);
    expect(find.textContaining('개발용'), findsNothing);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('reset-code')),
        matching: find.byType(TextFormField),
      ),
      '482916',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('reset-password')),
        matching: find.byType(TextFormField),
      ),
      'abcd1234',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('비밀번호 변경'));
    await tester.tap(find.text('비밀번호 변경'));
    await tester.pumpAndSettle();
    expect(requests.map((r) => r.url.path).toList(), [
      '/api/auth/password/reset-request',
      '/api/auth/password/reset-verification',
      '/api/auth/password/reset',
    ]);
    expect(jsonDecode(requests[1].body)['code'], '482916');
    expect(find.text('비밀번호가 변경됐어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('비밀번호 저장 응답이 끊기면 확인 토큰을 보존하고 변경 요청만 다시 보낸다', () async {
    var confirms = 0, resets = 0;
    final model = PasswordResetViewModel(
      ServerPasswordResetRepository(
        baseUrl: 'http://server.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/reset-verification')) {
            confirms++;
            return http.Response(
              jsonEncode({
                'reset_token': 'server-reset-token-123456789',
                'expires_in': 1800,
              }),
              200,
            );
          }
          if (++resets == 1) throw http.ClientException('connection lost');
          expect(
            jsonDecode(request.body)['token'],
            'server-reset-token-123456789',
          );
          return http.Response('', 204);
        }),
      ),
    );
    expect(
      await model.resetWithServerCode('user@example.com', '482916', 'abcd1234'),
      false,
    );
    expect(
      await model.resetWithServerCode('user@example.com', '482916', 'abcd1234'),
      true,
    );
    expect(confirms, 1);
    expect(resets, 2);
    model.dispose();
  });
}
