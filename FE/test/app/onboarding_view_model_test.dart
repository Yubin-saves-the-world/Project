import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fe/app/onboarding/onboarding_view_model.dart';
import 'package:fe/core/media/image_picker_service.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/body_analysis/data/models/analysis_input.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import 'package:fe/features/profile/data/models/body_profile.dart';

import '../fakes/fake_onboarding_repository.dart';

void main() {
  late FakeOnboardingRepository repository;
  late FakePhotoPicker picker;
  late OnboardingViewModel model;
  setUp(() async {
    repository = FakeOnboardingRepository();
    picker = FakePhotoPicker();
    model = OnboardingViewModel(repository: repository, photoPicker: picker);
    await model.initialize();
  });
  tearDown(() => model.dispose());

  test('로그아웃은 계정·사진을 유지하고 세션·메모리 입력만 정리한다', () async {
    const photo = SelectedPhoto(
      path: '/app/onboarding_photos/front.jpg',
      byteLength: 123,
    );
    repository.progress = const OnboardingProgress(
      account: previewAccount,
      profile: previewProfile,
      completed: true,
      analysis: AnalysisInput(front: photo),
    );
    await model.initialize();
    model.password = model.passwordConfirmation = 'password123';
    expect(await model.signOut(), isTrue);
    expect(picker.discarded, isEmpty);
    expect((await repository.load()).account, isNotNull);
    expect((await repository.load()).signedIn, isFalse);
    expect(model.showLogin, isTrue);
    expect(model.step, 0);
    expect(model.nickname, isEmpty);
    expect(model.password, isEmpty);
    expect(model.passwordConfirmation, isEmpty);
    expect(model.termsAgreed, isFalse);
    expect(model.analysis.front, isNull);
  });

  test('로그아웃·재실행 후 새 가입 초안은 비어 있고 기존 로그인은 저장 정보를 복원한다', () async {
    repository.progress = const OnboardingProgress(
      account: previewAccount,
      profile: previewProfile,
      completed: true,
    );
    await model.initialize();
    await model.signOut();
    model.openSignup();
    expect(model.nickname, isEmpty);
    expect(model.email, isEmpty);
    expect(model.height, isEmpty);
    expect(model.weight, isEmpty);
    expect(model.age, isEmpty);
    expect(model.gender, isNull);
    expect(model.goalType, isNull);
    expect(model.frequency, isNull);
    expect(model.experienceLevel, isNull);
    expect(model.progress.account, isNull);
    expect(model.progress.profile, isNull);
    await model.initialize();
    model.openSignup();
    expect(model.nickname, isEmpty);
    expect(model.email, isEmpty);
    expect(model.height, isEmpty);
    expect(model.progress.profile, isNull);
    expect(repository.progress.account, previewAccount);
    expect(repository.progress.profile, previewProfile);
    expect(await model.login('yubin@example.com', 'password123'), isTrue);
    expect(model.nickname, previewAccount.nickname);
    expect(model.height, '174');
    expect(model.weight, '68');
    expect(model.age, '20');
  });

  void account() {
    model.nickname = '유빈';
    model.email = 'yubin@example.com';
    model.password = model.passwordConfirmation = 'password123';
    model.updateConsent(terms: true, privacy: true, photo: true, ai: true);
  }

  void profile() {
    model.height = '174';
    model.weight = '68.5';
    model.age = '20';
    model.updateProfile(
      gender: Gender.male,
      goal: GoalType.muscle,
      frequency: 7,
      experience: ExperienceLevel.under3m,
    );
  }

  test('필수 동의를 확인하고 중복 제출을 막는다', () async {
    account();
    model.updateConsent(terms: false);
    expect(await model.submitAccount(), isFalse);
    model.updateConsent(terms: true);
    final results = await Future.wait([
      model.submitAccount(),
      model.submitAccount(),
    ]);
    expect(results.where((v) => v), hasLength(1));
    expect(repository.accountWrites, 1);
    expect(repository.loginCalls, 1);
    expect(model.step, 1);
    expect(
      jsonEncode(repository.progress.toJson()),
      isNot(contains('password123')),
    );
  });

  test('가입 시 사진·AI 동의도 필수다', () async {
    account();
    for (final photo in [false, true]) {
      model.updateConsent(photo: photo, ai: !photo);
      expect(await model.submitAccount(), isFalse);
      expect(repository.accountWrites, 0);
    }
  });

  test('가입 성공 뒤 로그인 실패는 가입 요청을 반복하지 않는다', () async {
    account();
    repository.failLoginOnce = true;
    expect(await model.submitAccount(), isFalse);
    expect(repository.accountWrites, 1);
    expect(await model.submitAccount(), isTrue);
    expect(repository.accountWrites, 1);
    expect(repository.loginCalls, 2);
  });

  test('신체정보 등록으로 온보딩 완료, 재실행 시 홈 진입 가능', () async {
    account();
    await model.submitAccount();
    profile();
    await model.submitProfile();
    expect(model.progress.onboardingCompleted, isTrue);
    expect(model.progress.analysisPrepared, isFalse);
    await model.initialize();
    expect(model.progress.completed, isTrue);
  });

  test('성별 선택 없이 프로필을 저장할 수 없다', () async {
    account();
    await model.submitAccount();
    profile();
    model.gender = null;
    expect(await model.submitProfile(), isFalse);
    expect(model.error, '성별을 선택해 주세요.');
    model.gender = Gender.none;
    expect(await model.submitProfile(), isFalse);
    model.updateProfile(gender: Gender.female);
    expect(await model.submitProfile(), isTrue);
    expect(repository.progress.profile!.gender, Gender.female);
  });

  test('신체 범위와 선택을 검사하고 뒤로 가도 초안이 유지된다', () async {
    account();
    await model.submitAccount();
    profile();
    model.age = '20.5';
    expect(await model.submitProfile(), isFalse);
    model.age = '20';
    expect(await model.submitProfile(), isTrue);
    model.back();
    expect(model.height, '174');
    expect(model.frequency, 7);
    expect(repository.progress.profile!.weeklyFrequency, 7);
  });

  test('저장 실패가 단계를 넘기지 않고 재시도 가능하다', () async {
    account();
    repository.failNext = true;
    expect(await model.submitAccount(), isFalse);
    expect(model.step, 0);
    expect(model.email, 'yubin@example.com');
    expect(model.busy, isFalse);
    expect(await model.submitAccount(), isTrue);
  });

  test('사진 동의 없이 네이티브 선택기를 열지 않는다', () async {
    await model.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    expect(picker.calls, 0);
    model.updateConsent(photo: true);
    picker.failure = const PhotoPickerException('권한을 확인해 주세요.');
    await model.pickPhoto(PhotoSlot.front, PhotoSource.camera);
    expect(model.error, '권한을 확인해 주세요.');
    expect(model.busy, isFalse);
  });

  test('사진·글 분석 입력 및 동의를 검사하며 건너뛰기는 허용한다', () async {
    account();
    await model.submitAccount();
    profile();
    await model.submitProfile();
    expect(await model.finish(prepareAnalysis: true), isFalse);
    model.updateConsent(photo: true, ai: true);
    expect(await model.finish(prepareAnalysis: true), isFalse);
    model.setMethod(AnalysisMethod.text);
    model.setText('');
    expect(await model.finish(prepareAnalysis: true), isFalse);
    expect(await model.finish(prepareAnalysis: false), isTrue);
    expect(repository.progress.completed, isTrue);
    expect(repository.progress.analysisPrepared, isFalse);
    expect(model.password, isEmpty);
  });

  test('선택한 사진이 저장되고 취소·실패가 기존 사진을 지우지 않는다', () async {
    model.updateConsent(photo: true);
    picker.nextPhoto = const SelectedPhoto(
      path: '/preview/front.jpg',
      byteLength: 42,
    );
    await model.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    expect(repository.progress.analysis.front!.path, '/preview/front.jpg');
    picker.nextPhoto = null;
    await model.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    expect(model.analysis.front, isNotNull);
    await model.removePhoto(PhotoSlot.front);
    expect(repository.progress.analysis.front, isNull);
    expect(picker.discarded, contains('/preview/front.jpg'));
  });

  test('로컬 저장값은 재실행에서 신체정보 단계와 분석 초안을 복원한다', () async {
    repository.progress = const OnboardingProgress(
      account: previewAccount,
      profile: previewProfile,
      analysis: AnalysisInput(method: AnalysisMethod.text, text: '어깨가 말려요'),
    );
    await model.initialize();
    expect(model.step, 2);
    expect(model.analysis.text, '어깨가 말려요');
    expect(model.password, isEmpty);
  });

  test('사진·글 준비 완료에서 실제 AI 결과 없이 준비 상태만 저장한다', () async {
    account();
    model.updateConsent(photo: true, ai: true);
    await model.submitAccount();
    profile();
    await model.submitProfile();
    picker.nextPhoto = const SelectedPhoto(
      path: '/preview/front.jpg',
      byteLength: 100,
    );
    await model.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    expect(await model.finish(prepareAnalysis: true), isTrue);
    expect(repository.progress.analysisPrepared, isTrue);
    expect(repository.progress.toJson().containsKey('balance_score'), isFalse);
  });
}
