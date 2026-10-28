import 'package:fe/app/shell/main_shell.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fe/app/onboarding/onboarding_flow.dart';
import 'package:fe/app/onboarding/onboarding_view_model.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/auth/data/server_onboarding_repository.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/body_analysis/data/models/analysis_input.dart';
import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/body_analysis/presentation/analysis_dependencies.dart';
import 'package:fe/features/body_analysis/presentation/analysis_input_view_model.dart';
import 'package:fe/features/goal_body/presentation/goal_dependencies.dart';
import 'package:fe/features/goal_body/presentation/goal_view_model.dart';
import 'package:fe/features/photos/presentation/photo_management_view_model.dart';
import 'package:fe/features/photos/data/models/body_photo.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import 'package:fe/features/settings/data/consent_request_guard.dart';
import '../../fakes/fake_account_settings.dart';
import '../../fakes/fake_analysis_repository.dart';
import '../../fakes/fake_goal_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';

class GoalPhotos extends FakePhotoRepository {
  BodyPhotoType? listed, cleared;
  @override
  Future<PhotoPage> list({BodyPhotoType type = BodyPhotoType.current}) {
    listed = type;
    return super.list(type: type);
  }

  @override
  Future<PhotoDeleteResult> deleteAll({
    BodyPhotoType type = BodyPhotoType.current,
  }) {
    cleared = type;
    return super.deleteAll(type: type);
  }
}

void main() {
  test('철회된 AI 동의는 분석·목표 사진 업로드 전 차단한다', () async {
    const account = OnboardingAccount(
      nickname: '유빈',
      email: 'user@example.com',
      bodyPhotoAgreed: true,
      aiProcessingAgreed: false,
    );
    final guard = ConsentRequestGuard(() => account);
    final photos = FakePhotoRepository(), analysis = FakeAnalysisRepository();
    final picker = FakePhotoPicker()
      ..nextPhoto = const SelectedPhoto(path: 'front.jpg', byteLength: 10);
    final m = AnalysisInputViewModel(
      AnalysisDependencies(
        repository: analysis,
        photos: photos,
        picker: picker,
        pending: MemoryAnalysisPendingStore(),
        preparer: FakePhotoPreparer(),
        ensureCanAnalyze: () => guard.check('POST', ApiContract.photoAnalysis),
      ),
    );
    await m.initialize();
    await m.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    expect(await m.finish(prepareAnalysis: true), false);
    expect(photos.uploads, 0);
    expect(analysis.starts, 0);
    expect(m.accessCode, 'CONSENT_REQUIRED');
    m.dispose();
    final goal = GoalViewModel(
      GoalDependencies(
        repository: FakeGoalRepository(),
        photos: photos,
        picker: FakePhotoPicker(),
        ensureCanWrite: () => guard.check('POST', ApiContract.goalBodies),
      ),
    );
    await goal.load();
    goal.description = '근육량 향상';
    expect(await goal.save(), false);
    expect(goal.accessCode, 'CONSENT_REQUIRED');
    expect(photos.uploads, 0);
    goal.dispose();
  });
  test('목표 원본 관리에서는 목표 유형만 조회·삭제하고 새 업로드는 제공하지 않는다', () async {
    final photos = GoalPhotos()..items = [testPhoto(1)];
    final m = PhotoManagementViewModel(
      repository: photos,
      picker: FakePhotoPicker(),
      preparer: FakePhotoPreparer(),
      type: BodyPhotoType.goal,
    );
    await m.load();
    expect(photos.listed, BodyPhotoType.goal);
    expect(m.canAdd, false);
    await m.add(PhotoSource.gallery, BodyPhotoSide.front);
    expect(photos.uploads, 0);
    await m.removeAll();
    expect(photos.cleared, BodyPhotoType.goal);
    m.dispose();
  });
  test('탈퇴 완료는 메모리의 가입·신체정보·사진 입력을 비우고 로그인으로 전환한다', () async {
    final repo = FakeOnboardingRepository()
      ..progress = const OnboardingProgress(
        account: previewAccount,
        profile: previewProfile,
        completed: true,
        analysis: AnalysisInput(
          front: SelectedPhoto(path: 'front.jpg', byteLength: 10),
        ),
      );
    final m = OnboardingViewModel(
      repository: repo,
      photoPicker: FakePhotoPicker(),
    );
    await m.initialize();
    m.password = 'password123';
    m.completeAccountDeletion();
    expect(m.progress.signedIn, false);
    expect(m.progress.account, isNull);
    expect(m.progress.profile, isNull);
    expect(m.analysis.front, isNull);
    expect(m.nickname, isEmpty);
    expect(m.password, isEmpty);
    expect(m.showLogin, true);
    m.dispose();
  });
  testWidgets('재실행 시 철회한 동의를 강제로 복구하지 않고 기존 홈·기록 접근을 유지한다', (tester) async {
    final token = MemoryTokenStore();
    await token.write('token');
    final calls = <String>[];
    final server = ServerOnboardingRepository(
      baseUrl: 'http://server.test',
      tokenStore: token,
      client: MockClient((q) async {
        calls.add(q.url.path);
        if (q.url.path == '/api/users/me') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(accountJson(photo: false, ai: false))),
            200,
          );
        }
        if (q.url.path == '/api/users/me/profile') {
          return http.Response.bytes(
            utf8.encode(jsonEncode(previewProfile.toJson())),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'code': 'INTERNAL_ERROR',
            'message': '조회 테스트',
            'status': 500,
            'fields': null,
          }),
          500,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          repository: server,
          photoPicker: FakePhotoPicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.text('필수 동의 확인'), findsNothing);
    expect(calls.contains('/api/users/me/profile'), true);
    expect(await token.read(), 'token');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
