import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';
import 'package:fe/features/body_analysis/presentation/analysis_dependencies.dart';
import 'package:fe/features/body_analysis/presentation/analysis_input_view_model.dart';
import 'package:fe/features/body_analysis/presentation/analysis_run_view_model.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import '../../fakes/fake_analysis_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';

ApiRequestError apiError(String code, int status) => ApiRequestError(
  ApiFailure(code: code, message: '서버 안내', status: status, fields: null),
);

void main() {
  test('로컬 미리보기에서는 사진이 있어도 업로드나 분석 요청을 보내지 않는다', () async {
    final repository = FakeAnalysisRepository();
    final photos = FakePhotoRepository();
    final model = AnalysisInputViewModel(
      AnalysisDependencies(
        repository: repository,
        photos: photos,
        picker: FakePhotoPicker()
          ..nextPhoto = const SelectedPhoto(path: 'front.jpg', byteLength: 10),
        pending: MemoryAnalysisPendingStore(),
        preparer: FakePhotoPreparer(),
        localPreview: true,
      ),
    );
    await model.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    expect(await model.finish(prepareAnalysis: true), isFalse);
    expect(model.error, contains('로컬 미리보기'));
    expect(photos.uploads, 0);
    expect(repository.starts, 0);
    expect(model.analysis.front, isNotNull);
    model.dispose();
  });

  test('업로드 후 요청 실패 시 사진을 보존하고 성공한 업로드를 재사용한다', () async {
    final repository = FakeAnalysisRepository()
      ..startError = StateError('다시 시도');
    final photos = FakePhotoRepository();
    final pending = MemoryAnalysisPendingStore();
    final model = AnalysisInputViewModel(
      AnalysisDependencies(
        repository: repository,
        photos: photos,
        picker: FakePhotoPicker()
          ..nextPhoto = const SelectedPhoto(path: 'front.jpg', byteLength: 10),
        pending: pending,
        preparer: FakePhotoPreparer(),
      ),
    );
    await model.initialize();
    expect(await model.finish(prepareAnalysis: true), isFalse);
    expect(photos.uploads, 0);
    await model.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    model.selectGoal(const AnalysisGoal(7, AnalysisStatus.done, null));
    expect(await model.finish(prepareAnalysis: true), isFalse);
    expect(model.analysis.front, isNotNull);
    expect(photos.uploads, 1);
    repository.startError = null;
    expect(await model.finish(prepareAnalysis: true), isTrue);
    expect(photos.uploads, 1);
    expect(repository.front, 1);
    expect(repository.goalId, 7);
    expect(await pending.read(), 31);
    expect(await model.finish(prepareAnalysis: true), isTrue);
    expect(repository.starts, 2); // 첫 실패+성공. 성공 후에는 다시 POST하지 않는다.
    model.dispose();
  });
  test('두 사진 업로드 후 요청 실패해도 업로드를 반복하지 않는다', () async {
    final repository = FakeAnalysisRepository();
    final photos = FakePhotoRepository();
    final picker = FakePhotoPicker()
      ..nextPhoto = const SelectedPhoto(path: 'front.jpg', byteLength: 10);
    final model = AnalysisInputViewModel(
      AnalysisDependencies(
        repository: repository,
        photos: photos,
        picker: picker,
        pending: MemoryAnalysisPendingStore(),
        preparer: FakePhotoPreparer(),
      ),
    );
    await model.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    picker.nextPhoto = const SelectedPhoto(path: 'side.jpg', byteLength: 10);
    await model.pickPhoto(PhotoSlot.side, PhotoSource.gallery);
    // 이 테스트는 요청 단계 실패에도 두 업로드가 유지되는지 확인한다.
    repository.startError = StateError('연결 실패');
    expect(await model.finish(prepareAnalysis: true), isFalse);
    expect(photos.uploads, 2);
    repository.startError = null;
    expect(await model.finish(prepareAnalysis: true), isTrue);
    expect(photos.uploads, 2);
    expect(repository.side, 2);
    model.dispose();
  });
  test('한도 소진 시 업로드하지 않고 초기화 시각을 보존한다', () async {
    final repository = FakeAnalysisRepository()
      ..currentUsage = AnalysisUsage(
        used: 3,
        limit: 3,
        remaining: 0,
        resetAt: DateTime(2026, 10, 27),
      );
    final photos = FakePhotoRepository();
    final model = AnalysisInputViewModel(
      AnalysisDependencies(
        repository: repository,
        photos: photos,
        picker: FakePhotoPicker()
          ..nextPhoto = const SelectedPhoto(path: 'a', byteLength: 1),
        pending: MemoryAnalysisPendingStore(),
        preparer: FakePhotoPreparer(),
      ),
    );
    await model.initialize();
    await model.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    expect(await model.finish(prepareAnalysis: true), isFalse);
    expect(photos.uploads, 0);
    expect(repository.starts, 0);
    expect(model.usage!.resetAt, DateTime(2026, 10, 27));
    model.dispose();
  });
  test('409 진행 중이면 목록에서 ID를 복원하여 중복 생성하지 않는다', () async {
    final repository = FakeAnalysisRepository()
      ..startError = apiError('ANALYSIS_IN_PROGRESS', 409)
      ..records = [
        AnalysisSummary(
          id: 42,
          status: AnalysisStatus.pending,
          createdAt: DateTime(2026),
        ),
      ];
    final pending = MemoryAnalysisPendingStore();
    final model = AnalysisInputViewModel(
      AnalysisDependencies(
        repository: repository,
        photos: FakePhotoRepository(),
        picker: FakePhotoPicker()
          ..nextPhoto = const SelectedPhoto(path: 'a', byteLength: 1),
        pending: pending,
        preparer: FakePhotoPreparer(),
      ),
    );
    await model.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    expect(await model.finish(prepareAnalysis: true), isTrue);
    expect(await pending.read(), 42);
    expect(repository.starts, 1);
    model.dispose();
  });
  testWidgets('pending → done: 2초 조회 후 저장 ID 해제, 명시적 루틴 생성만 허용', (
    tester,
  ) async {
    final repository = FakeAnalysisRepository();
    final store = MemoryAnalysisPendingStore()..id = 31;
    final model = AnalysisRunViewModel(
      repository,
      store,
      31,
      now: tester.binding.clock.now,
    );
    await model.resume();
    expect(model.phase, AnalysisRunPhase.pending);
    await model.generate();
    expect(repository.generated, 0);
    repository.response = result(AnalysisStatus.done);
    await tester.pump(const Duration(seconds: 2));
    expect(model.phase, AnalysisRunPhase.done);
    expect(await store.read(), isNull);
    expect(repository.generated, 0);
    await model.generate();
    await model.generate();
    expect(repository.generated, 1);
    expect(repository.generatedId, 31);
    model.dispose();
  });
  testWidgets('60초 후 조회 중단, 동일 번호로 재개하며 네트워크 오류는 분석 실패와 구별', (tester) async {
    final repository = FakeAnalysisRepository();
    final store = MemoryAnalysisPendingStore()..id = 31;
    final model = AnalysisRunViewModel(
      repository,
      store,
      31,
      now: tester.binding.clock.now,
    );
    await model.resume();
    await tester.pump(const Duration(seconds: 60));
    expect(model.phase, AnalysisRunPhase.timedOut);
    final count = repository.details;
    await tester.pump(const Duration(seconds: 20));
    expect(repository.details, count);
    expect(await store.read(), 31);
    repository.detailError = StateError('네트워크');
    await model.resume();
    expect(model.phase, AnalysisRunPhase.networkError);
    expect(await store.read(), 31);
    repository.detailError = null;
    repository.response = result(AnalysisStatus.failed);
    await model.resume();
    expect(model.phase, AnalysisRunPhase.failed);
    expect(await store.read(), isNull);
    expect(repository.starts, 0);
    model.dispose();
  });
  testWidgets('pause와 dispose 이후 늦게 온 응답을 무시한다', (tester) async {
    final completer = Completer<BodyAnalysis>();
    final repository = FakeAnalysisRepository()
      ..onDetail = () => completer.future;
    final store = MemoryAnalysisPendingStore()..id = 31;
    final model = AnalysisRunViewModel(
      repository,
      store,
      31,
      now: tester.binding.clock.now,
    );
    final request = model.resume();
    model.pause();
    completer.complete(result(AnalysisStatus.done));
    await request;
    expect(model.result, isNull);
    expect(await store.read(), 31);
    model.dispose();
    await tester.pump(const Duration(seconds: 5));
    expect(repository.details, 1);
  });
  test('nullable 수치와 알 수 없는 판정값을 0으로 바꾸지 않는다', () {
    final result = BodyAnalysis.fromJson({
      'analysis_id': 31,
      'status': 'done',
      'created_at': '2026-10-26T00:00:00Z',
      'balance_score': null,
      'measures': null,
      'judgements': [
        {'label': '골반', 'level': 'new_level', 'value': null},
      ],
    });
    expect(result.score, isNull);
    expect(result.measures.values.every((v) => v == null), isTrue);
    expect(result.judgements.single.level, 'new_level');
    expect(measurementReason('SIDE_PHOTO_MISSING'), contains('측면'));
  });
}
