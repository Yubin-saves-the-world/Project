import 'package:fe/features/goal_body/data/local_goal_repository.dart';
import 'package:fe/features/photos/data/local_photo_repository.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/goal_body/presentation/goal_dependencies.dart';
import 'package:fe/features/goal_body/presentation/goal_view_model.dart';
import 'package:fe/features/goal_body/data/models/goal_body.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';
import 'package:fe/features/body_analysis/presentation/analysis_dependencies.dart';
import 'package:fe/features/body_analysis/presentation/analysis_input_view_model.dart';
import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import 'package:fe/features/photos/data/models/body_photo.dart';
import '../../fakes/fake_analysis_repository.dart';
import '../../fakes/fake_goal_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';

class RecordingGoalPhotos extends FakePhotoRepository {
  BodyPhotoType? type;
  BodyPhotoSide? side;
  @override
  Future<BodyPhoto> upload(
    Uint8List jpeg, {
    required BodyPhotoType type,
    required BodyPhotoSide side,
  }) {
    this.type = type;
    this.side = side;
    return super.upload(jpeg, type: type, side: side);
  }
}

void main() {
  test('로컬 목표 사진을 선택·등록·교체·삭제하고 계정별로 분리한다', () async {
    final photos = LocalPhotoRepository();
    final repository = LocalGoalRepository(photos: photos);
    final picker = FakePhotoPicker()
      ..nextPhoto = const SelectedPhoto(path: 'goal.jpg', byteLength: 4);
    final model = GoalViewModel(
      GoalDependencies(
        repository: repository,
        photos: photos,
        picker: picker,
        preparer: FakePhotoPreparer(),
        localPreview: true,
      ),
    );
    await model.load();
    await model.pick(PhotoSource.gallery);
    expect(model.photo, isNotNull);
    expect(await model.save(), true);
    expect(model.goal!.previewBytes, isNotEmpty);
    expect(model.goal!.summary, isNull);
    expect((await photos.list(type: BodyPhotoType.goal)).items, isEmpty);
    expect(picker.discarded, contains('goal.jpg'));
    model.setDescription('나의 참고 사진');
    expect(await model.save(), true);
    expect(model.goal!.previewBytes, isNotEmpty);
    picker.nextPhoto = const SelectedPhoto(path: 'new.jpg', byteLength: 4);
    await model.pick(PhotoSource.gallery);
    expect(await model.save(), true);
    expect(picker.discarded, contains('new.jpg'));
    expect(
      await LocalGoalRepository(photos: LocalPhotoRepository()).load(),
      isNull,
    );
    expect(await model.delete(), true);
    expect(await repository.load(), isNull);
    model.dispose();
  });

  test('수정 대상이 사라진 404는 재조회 후 새 목표 등록으로 이어진다', () async {
    final repository = FakeGoalRepository()
      ..goal = goalFixture()
      ..saveError = ApiRequestError(
        const ApiFailure(
          code: 'NOT_FOUND',
          message: '목표 없음',
          status: 404,
          fields: null,
        ),
      );
    final model = GoalViewModel(
      GoalDependencies(
        repository: repository,
        photos: FakePhotoRepository(),
        picker: FakePhotoPicker(),
      ),
    );
    await model.load();
    model.setDescription('새 목표');
    expect(await model.save(), false);
    expect(model.loaded, false);
    expect(await model.save(), false);
    expect(repository.updates, 1);
    repository.goal = null;
    repository.saveError = null;
    await model.load();
    expect(model.description, '새 목표');
    expect(await model.save(), true);
    expect(repository.creates, 1);
    model.dispose();
  });

  test('설명만 등록·수정·삭제하며 빈 입력과 200자 초과를 차단한다', () async {
    final repository = FakeGoalRepository();
    final photos = FakePhotoRepository();
    final model = GoalViewModel(
      GoalDependencies(
        repository: repository,
        photos: photos,
        picker: FakePhotoPicker(),
      ),
    );
    await model.load();
    expect(await model.save(), false);
    expect(repository.creates, 0);
    model.setDescription('a' * 201);
    expect(await model.save(), false);
    model.setDescription('  균형 잡힌 체형  ');
    expect(await model.save(), true);
    expect(repository.description, '균형 잡힌 체형');
    expect(repository.photoId, isNull);
    expect(photos.uploads, 0);
    expect(model.canSelect, true);
    model.setDescription('등 근육 발달');
    expect(await model.save(), true);
    expect(repository.updates, 1);
    expect(await model.delete(), true);
    expect(model.goal, isNull);
    expect(model.description, isEmpty);
    model.dispose();
  });
  test('사진은 goal/front로 업로드하고 요청 실패 재시도에 업로드를 재사용한다', () async {
    final repository = FakeGoalRepository()..saveError = StateError('연결 실패');
    final photos = RecordingGoalPhotos();
    final picker = FakePhotoPicker()
      ..nextPhoto = const SelectedPhoto(path: 'goal.jpg', byteLength: 10);
    final model = GoalViewModel(
      GoalDependencies(
        repository: repository,
        photos: photos,
        picker: picker,
        preparer: FakePhotoPreparer(),
      ),
    );
    await model.load();
    await model.pick(PhotoSource.gallery);
    expect(await model.save(), false);
    expect(model.photo, isNotNull);
    expect(photos.type, BodyPhotoType.goal);
    expect(photos.side, BodyPhotoSide.front);
    repository.saveError = null;
    expect(await model.save(), true);
    expect(photos.uploads, 1);
    expect(model.photo, isNull);
    expect(picker.discarded, contains('goal.jpg'));
    expect(model.processing, true);
    expect(model.canSelect, false);
    expect(await model.save(), false);
    expect(repository.creates, 2);
    model.dispose();
  });
  test('1시간 지난 임시 사진은 새로 업로드한다', () async {
    var now = DateTime(2026, 10, 26);
    final photos = FakePhotoRepository();
    final repository = FakeGoalRepository()..saveError = StateError('서버 연결 실패');
    final model = GoalViewModel(
      GoalDependencies(
        repository: repository,
        photos: photos,
        picker: FakePhotoPicker()
          ..nextPhoto = const SelectedPhoto(path: 'a', byteLength: 1),
        preparer: FakePhotoPreparer(),
      ),
      now: () => now,
    );
    await model.load();
    await model.pick(PhotoSource.gallery);
    await model.save();
    expect(photos.uploads, 1);
    now = now.add(const Duration(hours: 1));
    await model.save();
    expect(photos.uploads, 2);
    model.dispose();
  });
  test('409 중복은 현재 목표를 불러오고 사용자 재확인 전 자동으로 덮어쓰지 않는다', () async {
    final repository = FakeGoalRepository()
      ..saveError = ApiRequestError(
        const ApiFailure(
          code: 'GOAL_ALREADY_EXISTS',
          message: '이미 존재',
          status: 409,
          fields: null,
        ),
      );
    final model = GoalViewModel(
      GoalDependencies(
        repository: repository,
        photos: FakePhotoRepository(),
        picker: FakePhotoPicker(),
      ),
    );
    await model.load();
    model.setDescription('내 새 목표');
    repository.goal = goalFixture();
    expect(await model.save(), false);
    expect(repository.updates, 0);
    expect(model.goal!.id, 7);
    expect(model.description, '내 새 목표');
    repository.saveError = null;
    expect(await model.save(), true);
    expect(repository.updates, 1);
    model.dispose();
  });
  testWidgets('사진 pending은 2초 조회 후 done일 때만 선택 가능하다', (tester) async {
    final repository = FakeGoalRepository()
      ..goal = goalFixture(status: AnalysisStatus.pending);
    final model = GoalViewModel(
      GoalDependencies(
        repository: repository,
        photos: FakePhotoRepository(),
        picker: FakePhotoPicker(),
      ),
      now: tester.binding.clock.now,
    );
    await model.load();
    expect(model.canSelect, false);
    repository.goal = goalFixture();
    await tester.pump(const Duration(seconds: 2));
    expect(model.canSelect, true);
    expect(model.checking, false);
    model.dispose();
  });
  testWidgets('60초 뒤 조회 중단·재개, 네트워크 오류와 failed 상태 구분', (tester) async {
    final repository = FakeGoalRepository()
      ..goal = goalFixture(status: AnalysisStatus.pending);
    final model = GoalViewModel(
      GoalDependencies(
        repository: repository,
        photos: FakePhotoRepository(),
        picker: FakePhotoPicker(),
      ),
      now: tester.binding.clock.now,
    );
    await model.load();
    await tester.pump(const Duration(seconds: 60));
    expect(model.timedOut, true);
    final count = repository.loads;
    await tester.pump(const Duration(seconds: 10));
    expect(repository.loads, count);
    repository.loadError = StateError('네트워크 오류');
    await model.load();
    expect(model.error, contains('네트워크'));
    expect(model.goal!.status, AnalysisStatus.pending);
    repository.loadError = null;
    repository.goal = goalFixture(status: AnalysisStatus.failed);
    await model.load();
    expect(model.goal!.errorMessage, '사진이 흐려요.');
    expect(model.canSelect, false);
    expect(model.canEdit, true);
    model.dispose();
  });
  testWidgets('백그라운드의 늦은 조회는 무시하고 재개 때 현재 목표를 복원한다', (tester) async {
    final repository = FakeGoalRepository();
    final response = Completer<GoalBody?>();
    repository.onLoad = () => response.future;
    final model = GoalViewModel(
      GoalDependencies(
        repository: repository,
        photos: FakePhotoRepository(),
        picker: FakePhotoPicker(),
      ),
    );
    final loading = model.load();
    model.suspend();
    response.complete(goalFixture());
    await loading;
    expect(model.goal, isNull);
    repository.onLoad = null;
    repository.goal = goalFixture();
    await model.resume();
    expect(model.goal!.id, 7);
    model.dispose();
  });
  test('삭제 실패 때 데이터 유지 및 재조회 후 재시도', () async {
    final repository = FakeGoalRepository()
      ..goal = goalFixture()
      ..deleteError = StateError('삭제 실패');
    final model = GoalViewModel(
      GoalDependencies(
        repository: repository,
        photos: FakePhotoRepository(),
        picker: FakePhotoPicker(),
      ),
    );
    await model.load();
    expect(await model.delete(), false);
    expect(model.goal, isNotNull);
    expect(model.loaded, false);
    repository.deleteError = null;
    await model.load();
    expect(await model.delete(), true);
    model.dispose();
  });
  test('선택한 목표가 삭제되면 분석 업로드 전에 재선택 안내', () async {
    final photos = FakePhotoRepository();
    final goals = FakeGoalRepository();
    final picker = FakePhotoPicker()
      ..nextPhoto = const SelectedPhoto(path: 'front', byteLength: 10);
    final goalDependencies = GoalDependencies(
      repository: goals,
      photos: photos,
      picker: picker,
    );
    final repository = FakeAnalysisRepository();
    final model = AnalysisInputViewModel(
      AnalysisDependencies(
        repository: repository,
        photos: photos,
        picker: picker,
        pending: MemoryAnalysisPendingStore(),
        preparer: FakePhotoPreparer(),
        goals: goalDependencies,
      ),
    );
    await model.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    model.selectGoal(const AnalysisGoal(7, AnalysisStatus.done, '이전 목표'));
    expect(await model.finish(prepareAnalysis: true), false);
    expect(photos.uploads, 0);
    expect(repository.starts, 0);
    expect(model.selectedGoal, isNull);
    model.dispose();
  });
}
