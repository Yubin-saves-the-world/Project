import 'package:flutter_test/flutter_test.dart';
import 'package:fe/app/onboarding/onboarding_view_model.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/features/auth/data/server_onboarding_repository.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/profile/data/models/body_profile.dart';
import 'package:fe/features/photos/data/server_photo_repository.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import 'package:fe/features/body_analysis/data/server_analysis_repository.dart';
import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/body_analysis/presentation/analysis_dependencies.dart';
import 'package:fe/features/body_analysis/presentation/analysis_input_view_model.dart';
import 'package:fe/features/body_analysis/presentation/analysis_run_view_model.dart';
import 'package:fe/features/goal_body/data/server_goal_repository.dart';
import 'package:fe/features/exercises/data/server_exercise_repository.dart';
import 'package:fe/features/routines/data/server_routine_repository.dart';
import 'package:fe/features/routines/data/models/routine.dart';
import 'package:fe/features/home/data/home_server_repository.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/home_server_dependencies.dart';
import 'package:fe/features/home/presentation/home_server_view_model.dart';
import 'package:fe/features/workout/data/workout_repository.dart';
import 'package:fe/features/workout/presentation/workout_dependencies.dart';
import 'package:fe/features/workout/presentation/workout_view_model.dart';
import 'package:fe/features/workout/presentation/workout_summary_view_model.dart';
import 'package:fe/features/workout/presentation/workout_record_view_model.dart';
import 'package:fe/features/workout/presentation/workout_history_view_model.dart';
import 'package:fe/features/settings/data/account_repository.dart';
import 'package:fe/features/settings/data/consent_request_guard.dart';
import 'package:fe/features/settings/presentation/account_settings_dependencies.dart';
import 'package:fe/features/settings/presentation/account_settings_view_model.dart';
import '../fakes/mvp_contract_server.dart';
import '../fakes/fake_onboarding_repository.dart';
import '../fakes/fake_profile_photo_repositories.dart';
import '../fakes/fake_home_repository.dart';
import '../fakes/fake_home_server.dart';
import '../fakes/fake_workout_repository.dart';

void main() {
  test('HTTP 계약 기반 가입→설문→분석→루틴→운동/복원→기록→설정→탈퇴 한 바퀴', () async {
    final server = MvpContractServer(), tokens = MemoryTokenStore();
    final api = ApiClient(
      baseUrl: 'http://contract.test',
      client: server.client,
      tokenStore: tokens,
    );
    final auth = ServerOnboardingRepository(
      baseUrl: 'http://contract.test',
      apiClient: api,
    );
    final signup = OnboardingViewModel(
      repository: auth,
      photoPicker: FakePhotoPicker(),
    );
    addTearDown(signup.dispose);
    addTearDown(api.dispose);
    await signup.initialize();
    signup.nickname = 'QA 회원';
    signup.email = 'qa@example.com';
    signup.password = 'password123';
    expect(await signup.sendVerification(), true);
    expect(await signup.verifyEmailCode(signup.email, '000000'), isNotNull);
    expect(await signup.verifyEmailCode(signup.email, '123456'), isNull);
    signup.updateConsent(terms: true, privacy: true, photo: true, ai: true);
    expect(await signup.submitAccount(), true);
    expect(await tokens.read(), 'qa-token');
    signup.height = '174';
    signup.weight = '68';
    signup.age = '20';
    signup.gender = Gender.male;
    signup.goalType = GoalType.muscle;
    signup.frequency = 3;
    signup.experienceLevel = ExperienceLevel.under3m;
    expect(await signup.submitProfile(), true);
    expect(await signup.finish(prepareAnalysis: false), true);
    final restored = await ServerOnboardingRepository(
      baseUrl: 'http://contract.test',
      apiClient: api,
    ).load();
    expect(restored.onboardingCompleted, true);
    expect(restored.account!.userId, 7);
    final policy = ConsentRequestGuard(() => signup.progress.account);
    api.beforeAuthorizedRequest = policy.check;
    final goals = ServerGoalRepository(api);
    expect(await goals.load(), isNull);
    final goal = await goals.create(description: '균형 있는 근육');
    expect(goal.id, 5);
    final photos = ServerPhotoRepository(api),
        analyses = ServerAnalysisRepository(api);
    final pending = MemoryAnalysisPendingStore();
    final input = AnalysisInputViewModel(
      AnalysisDependencies(
        repository: analyses,
        photos: photos,
        picker: FakePhotoPicker()
          ..nextPhoto = const SelectedPhoto(path: 'front.jpg', byteLength: 10),
        pending: pending,
        preparer: FakePhotoPreparer(),
        ensureCanAnalyze: () => policy.check('POST', ApiContract.photoAnalysis),
      ),
    );
    addTearDown(input.dispose);
    await input.initialize();
    await input.pickPhoto(PhotoSlot.front, PhotoSource.gallery);
    input.selectGoal(goal.comparison);
    expect(await input.finish(prepareAnalysis: true), true);
    expect(input.pendingId, 31);
    final run = AnalysisRunViewModel(analyses, pending, 31);
    addTearDown(run.dispose);
    await run.resume();
    expect(run.phase, AnalysisRunPhase.done);
    expect(run.result!.measures['neck_forward_deg'], isNull);
    await run.generate();
    expect(run.routines!.single.id, 44);
    final exercises = ServerExerciseRepository(api),
        routines = ServerRoutineRepository(api);
    expect((await exercises.list()).items.single.id, 7);
    expect((await exercises.detail(7)).name, '바벨 스쿼트');
    expect((await routines.weekly(routineMonday(server.today))).empty, false);
    final local = HomeViewModel(
      repository: FakeHomeRepository(emptySchedule: true),
      today: server.today,
    );
    await local.initialize();
    addTearDown(local.dispose);
    final homeRepo = ApiHomeServerRepository(api);
    final home = HomeServerViewModel(
      HomeServerDependencies(
        repository: homeRepo,
        routines: routines,
        choices: FakeChoiceStore(),
        exercises: exercises,
      ),
      local,
    );
    addTearDown(home.dispose);
    await home.refresh();
    expect(home.error, isNull);
    expect(home.usesRecommended, true);
    var clock = server.now;
    final deps = WorkoutDependencies(
      repository: ServerWorkoutRepository(api),
      drafts: MemoryWorkoutDraftStore(),
      routines: routines,
    );
    var workout = WorkoutViewModel(
      deps,
      exerciseId: 7,
      routineId: 44,
      now: () => clock,
    );
    await workout.load();
    server.loseNextSet = true;
    expect(await workout.add(60, 10), false);
    expect(workout.pending, isNotNull);
    workout.dispose();
    workout = WorkoutViewModel(
      deps,
      exerciseId: null,
      logId: 87,
      now: () => clock,
    );
    addTearDown(workout.dispose);
    await workout.load();
    expect(workout.pending, isNull);
    expect(workout.log!.sets.length, 1);
    expect(server.setPosts, 1);
    clock = clock.add(const Duration(seconds: 90));
    expect(await workout.add(65, 8), true);
    clock = server.now.add(const Duration(minutes: 10));
    expect(await workout.finish(memo: 'QA 완료'), true);
    expect(workout.result!.sets, 2);
    expect(workout.result!.volume, 1120);
    expect(workout.result!.seconds, 600);
    final summary = WorkoutSummaryViewModel(
      deps,
      workout.log!,
      workout.result!,
    );
    addTearDown(summary.dispose);
    await summary.load();
    expect(summary.routineDone, true);
    expect(summary.nextItem, isNull);
    expect(server.completePosts, 1);
    await home.refresh();
    expect(home.stats!.count, 1);
    expect(home.volume, 1120);
    expect(home.workoutDays, 1);
    final history = WorkoutHistoryViewModel(
      homeRepo,
      date: server.today,
      today: server.today,
    );
    addTearDown(history.dispose);
    await history.refresh();
    expect(history.summary!.dates, {routineDateKey(server.today)});
    expect(history.items.single.id, 87);
    final detail = WorkoutRecordViewModel(deps, 87);
    addTearDown(detail.dispose);
    await detail.load();
    expect(
      await detail.update(detail.log!.sets.first, {
        'weight_kg': 62.5,
        'reps': 8,
        'is_done': true,
        'rest_sec': 90,
      }),
      true,
    );
    expect(detail.log!.volume, 1020);
    await home.refresh();
    expect(home.volume, 1020);
    expect(await detail.delete(), true);
    await history.refresh();
    await home.refresh();
    expect(history.items, isEmpty);
    expect(home.stats!.count, 0);
    expect((await routines.detail(44)).status, RoutineStatus.planned);
    final settings = AccountSettingsViewModel(
      AccountSettingsDependencies(
        repository: ServerAccountRepository(api),
        cleanup: tokens.clear,
        onDeleted: () async {
          auth.clearSessionData();
          signup.completeAccountDeletion();
        },
        onChanged: (me) => signup.applySavedAccount(
          OnboardingAccount(
            userId: me.userId,
            nickname: me.nickname,
            email: me.email ?? '',
            bodyPhotoAgreed: me.bodyPhotoAgreed,
            aiProcessingAgreed: me.aiProcessingAgreed,
          ),
        ),
      ),
    );
    addTearDown(settings.dispose);
    await settings.load();
    expect(await settings.rename('QA 수정'), true);
    expect(signup.progress.account!.nickname, 'QA 수정');
    await settings.consent(ai: false);
    expect(await analyses.history(), isNotNull);
    await expectLater(
      analyses.generateRoutines(31),
      throwsA(isA<ApiRequestError>()),
    );
    await settings.consent(ai: true);
    expect(await signup.signOut(), true);
    expect(await tokens.read(), isNull);
    await auth.login(email: 'qa@example.com', password: 'password123');
    await signup.initialize();
    expect(signup.progress.signedIn, true);
    expect(await settings.removeAccount(), true);
    expect(server.removed, true);
    expect(await tokens.read(), isNull);
    expect(signup.showLogin, true);
    expect(signup.progress.account, isNull);
  });
}
