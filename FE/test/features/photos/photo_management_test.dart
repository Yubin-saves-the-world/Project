import 'dart:convert';
import 'dart:typed_data';
import 'package:fe/core/media/image_picker_service.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/photos/data/models/body_photo.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import 'package:fe/features/photos/data/server_photo_repository.dart';
import 'package:fe/features/photos/presentation/photo_management_view_model.dart';
import 'package:fe/features/photos/presentation/pages/photo_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';

void main() {
  test('업로드 전처리가 먼저 실행되고 실패 시 사진을 유지하여 다시 올릴 수 있다', () async {
    final repo = FakePhotoRepository()..writeError = StateError('연결 실패');
    final picker = FakePhotoPicker()
      ..nextPhoto = const SelectedPhoto(
        path: '/tmp/body-test.jpg',
        byteLength: 4,
      );
    final prepare = FakePhotoPreparer();
    final model = PhotoManagementViewModel(
      repository: repo,
      picker: picker,
      preparer: prepare,
    );
    await model.load();
    await model.add(PhotoSource.gallery, BodyPhotoSide.side);
    expect(prepare.calls, 1);
    expect(repo.uploads, 1);
    expect(repo.lastUpload, [255, 216, 255, 217]);
    expect(model.pending, isNotNull);
    expect(picker.discarded, isEmpty);
    repo.writeError = null;
    await model.retryUpload();
    expect(model.pending, isNull);
    expect(model.total, 1);
    expect(picker.discarded, ['/tmp/body-test.jpg']);
    model.dispose();
  });
  test('전처리 실패·선택 취소는 업로드하지 않는다', () async {
    final repo = FakePhotoRepository();
    final picker = FakePhotoPicker();
    final prepare = FakePhotoPreparer()
      ..failure = const PhotoPickerException('JPG 또는 PNG 사진을 선택해 주세요.');
    final model = PhotoManagementViewModel(
      repository: repo,
      picker: picker,
      preparer: prepare,
    );
    await model.load();
    await model.add(PhotoSource.gallery, BodyPhotoSide.front);
    expect(repo.uploads, 0);
    picker.nextPhoto = const SelectedPhoto(
      path: '/tmp/bad-photo',
      byteLength: 3,
    );
    await model.add(PhotoSource.gallery, BodyPhotoSide.front);
    expect(repo.uploads, 0);
    expect(model.error, contains('JPG'));
    model.dispose();
  });
  test('사진 20장 한도와 로드 실패는 추가·삭제를 막고 재조회할 수 있다', () async {
    final repo = FakePhotoRepository()
      ..items = List.generate(20, (i) => testPhoto(i));
    final picker = FakePhotoPicker();
    final model = PhotoManagementViewModel(
      repository: repo,
      picker: picker,
      preparer: FakePhotoPreparer(),
    );
    await model.load();
    expect(model.canAdd, false);
    await model.add(PhotoSource.camera, BodyPhotoSide.front);
    expect(picker.calls, 0);
    repo.listError = StateError('불러오기 실패');
    await model.load();
    await model.remove(repo.items.first);
    expect(repo.deletes, 0);
    expect(model.hasLoaded, false);
    repo.listError = null;
    await model.load();
    expect(model.hasLoaded, true);
    model.dispose();
  });
  test('삭제 성공과 부분 삭제 후 목록을 갱신하고 PHOTO_IN_USE는 유지한다', () async {
    final repo = FakePhotoRepository()..items = [testPhoto(1), testPhoto(2)];
    final model = PhotoManagementViewModel(
      repository: repo,
      picker: FakePhotoPicker(),
      preparer: FakePhotoPreparer(),
    );
    await model.load();
    repo.writeError = ApiRequestError(
      const ApiFailure(
        code: 'PHOTO_IN_USE',
        message: '사용 중',
        status: 409,
        fields: null,
      ),
    );
    await model.remove(repo.items.first);
    expect(model.total, 2);
    expect(model.error, contains('처리가 끝나면'));
    repo.writeError = null;
    repo.deleteResult = const PhotoDeleteResult(deleted: 1, skipped: 1);
    await model.removeAll();
    expect(model.total, 1);
    expect(model.notice, contains('1장'));
    expect(repo.lists, 2);
    await model.remove(repo.items.first);
    expect(model.total, 0);
    model.dispose();
  });
  test('서버 사진 계약: 필터·JPEG multipart·인증·삭제 응답', () async {
    final tokens = MemoryTokenStore();
    await tokens.write('photo-token');
    final calls = <http.Request>[];
    final photo = {
      'photo_id': 7,
      'type': 'current',
      'side': 'front',
      'url': 'http://photo.test/a',
      'url_expires_at': '2026-10-26T13:00:00+09:00',
      'created_at': '2026-10-26T12:00:00+09:00',
    };
    final repo = ServerPhotoRepository(
      ApiClient(
        baseUrl: 'http://server.test',
        tokenStore: tokens,
        client: MockClient((r) async {
          calls.add(r);
          expect(r.headers['Authorization'], 'Bearer photo-token');
          if (r.method == 'POST') {
            expect(r.headers['content-type'], contains('boundary='));
            expect(
              latin1.decode(r.bodyBytes).toLowerCase(),
              contains('content-type: image/jpeg'),
            );
            expect(latin1.decode(r.bodyBytes), contains('name="type"'));
            return http.Response(jsonEncode(photo), 201);
          }
          if (r.method == 'DELETE' && r.url.path.endsWith('/7')) {
            return http.Response('', 204);
          }
          if (r.method == 'DELETE') {
            return http.Response(
              jsonEncode({'deleted_count': 1, 'skipped_count': 0}),
              200,
            );
          }
          expect(r.url.queryParameters, {
            'type': 'current',
            'page': '1',
            'page_size': '20',
          });
          return http.Response(
            jsonEncode({
              'items': [photo],
              'total': 1,
              'page': 1,
              'page_size': 20,
            }),
            200,
          );
        }),
      ),
    );
    expect((await repo.list()).total, 1);
    expect(
      (await repo.upload(
        Uint8List.fromList([255, 216, 255, 217]),
        type: BodyPhotoType.current,
        side: BodyPhotoSide.front,
      )).id,
      7,
    );
    await repo.delete(7);
    expect((await repo.deleteAll()).deleted, 1);
    expect(calls.length, 4);
  });
  for (final code in [
    'IMAGE_TOO_LARGE',
    'IMAGE_INVALID_TYPE',
    'PHOTO_LIMIT_EXCEEDED',
    'CONSENT_REQUIRED',
  ]) {
    test('서버 $code는 안내로 표시하고 업로드할 사진을 유지한다', () async {
      final repo = FakePhotoRepository()
        ..writeError = ApiRequestError(
          ApiFailure(code: code, message: '서버 오류', status: 400, fields: null),
        );
      final picker = FakePhotoPicker()
        ..nextPhoto = const SelectedPhoto(path: '/tmp/x.jpg', byteLength: 4);
      final model = PhotoManagementViewModel(
        repository: repo,
        picker: picker,
        preparer: FakePhotoPreparer(),
      );
      await model.load();
      await model.add(PhotoSource.gallery, BodyPhotoSide.front);
      expect(model.error, isNot('서버 오류'));
      expect(model.pending, isNotNull);
      model.dispose();
    });
  }
  testWidgets('작은 화면·큰 글꼴에서 목록 오류 재시도와 삭제 취소를 지원한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakePhotoRepository()..listError = StateError('불러오지 못했어요.');
    await tester.pumpWidget(
      MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        home: PhotoManagementPage(
          repository: repo,
          picker: FakePhotoPicker(),
          preparer: FakePhotoPreparer(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('목록 다시 불러오기'), findsOneWidget);
    repo.listError = null;
    repo.items = [testPhoto(1)];
    await tester.tap(find.text('목록 다시 불러오기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
