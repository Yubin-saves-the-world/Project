import 'package:fe/core/media/image_picker_service.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/auth/data/models/signup_request.dart';
import 'package:fe/features/auth/data/onboarding_repository.dart';
import 'package:fe/features/body_analysis/data/models/analysis_input.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import 'package:fe/features/profile/data/models/body_profile.dart';

class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository([this.progress = const OnboardingProgress()]);
  OnboardingProgress progress;
  bool failNext = false;
  int accountWrites = 0;
  void _checkFailure() {
    if (failNext) {
      failNext = false;
      throw StateError('저장을 다시 시도해 주세요.');
    }
  }

  @override
  Future<void> signOut() async {
    _checkFailure();
    progress = progress.copyWith(signedIn: false);
  }

  int loginCalls = 0;
  bool failLoginOnce = false;
  @override
  Future<OnboardingProgress> login({
    required String email,
    required String password,
  }) async {
    _checkFailure();
    loginCalls++;
    if (failLoginOnce) {
      failLoginOnce = false;
      throw StateError('로그인을 다시 시도해 주세요.');
    }
    return progress = progress.copyWith(signedIn: true);
  }

  @override
  Future<OnboardingProgress> load() async => progress;
  @override
  Future<OnboardingProgress> acceptRequiredConsents() async {
    final current = await load();
    final account = current.account;
    if (account == null) throw StateError('로그인 정보를 확인해 주세요.');
    final next = current.copyWith(
      account: OnboardingAccount(
        nickname: account.nickname,
        email: account.email,
        bodyPhotoAgreed: true,
        aiProcessingAgreed: true,
      ),
    );
    _checkFailure();
    return progress = next;
  }

  @override
  Future<OnboardingProgress> register(SignupRequest request) async {
    _checkFailure();
    accountWrites++;
    return progress = const OnboardingProgress(signedIn: false).copyWith(
      account: OnboardingAccount(
        nickname: request.nickname,
        email: request.email,
        bodyPhotoAgreed: request.bodyPhotoAgreed,
        aiProcessingAgreed: request.aiProcessingAgreed,
      ),
    );
  }

  @override
  Future<OnboardingProgress> saveProfile(BodyProfile profile) async {
    _checkFailure();
    return progress = progress.copyWith(profile: profile);
  }

  @override
  Future<OnboardingProgress> saveAnalysis(AnalysisInput input) async {
    _checkFailure();
    return progress = progress.copyWith(analysis: input);
  }

  @override
  Future<OnboardingProgress> complete({required bool prepareAnalysis}) async {
    _checkFailure();
    return progress = progress.copyWith(
      completed: true,
      analysisPrepared: prepareAnalysis,
    );
  }
}

class FakePhotoPicker implements PhotoPicker {
  SelectedPhoto? nextPhoto;
  PhotoPickerException? failure;
  int calls = 0;
  final discarded = <String>[];
  @override
  Future<SelectedPhoto?> pick(PhotoSlot slot, PhotoSource source) async {
    calls++;
    if (failure != null) throw failure!;
    return nextPhoto;
  }

  @override
  Future<(PhotoSlot, SelectedPhoto)?> recover() async => null;
  @override
  Future<bool> exists(SelectedPhoto photo) async => true;
  @override
  Future<void> discard(SelectedPhoto photo) async {
    discarded.add(photo.path);
  }
}

const previewAccount = OnboardingAccount(
  nickname: '유빈',
  email: 'yubin@example.com',
  bodyPhotoAgreed: true,
  aiProcessingAgreed: true,
);
const previewProfile = BodyProfile(
  heightCm: 174,
  weightKg: 68,
  age: 20,
  gender: Gender.none,
  goalType: GoalType.muscle,
  weeklyFrequency: 3,
  experienceLevel: ExperienceLevel.under3m,
);
