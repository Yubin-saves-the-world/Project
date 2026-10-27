import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fe/features/auth/data/local_nickname_registry.dart';
import 'package:fe/features/auth/data/local_onboarding_repository.dart';
import 'package:fe/features/auth/data/models/signup_request.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import 'package:fe/features/profile/data/profile_avatar_store.dart';
import 'package:fe/features/profile/presentation/pages/my_page.dart';
import 'package:fe/features/profile/presentation/pages/profile_identity_page.dart';
import 'package:fe/features/settings/data/account_data_cleaner.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../settings/account_settings_test.dart' show MemoryPreferences;
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';
import 'my_page_test.dart' show capture;

class IdentityPreferences extends MemoryPreferences {
  final _failures = <String>{};
  bool get failProgress => _failures.contains('progress');
  set failProgress(bool value) {
    if (value) {
      _failures.add('progress');
    } else {
      _failures.remove('progress');
    }
  }

  bool get failAvatar => _failures.contains('avatar');
  set failAvatar(bool value) {
    if (value) {
      _failures.add('avatar');
    } else {
      _failures.remove('avatar');
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failProgress && key == LocalOnboardingRepository.storageKey ||
        failAvatar && key.startsWith('movid.profile.avatar.')) {
      throw StateError('저장 실패');
    }
    data[key] = value;
  }
}

Uint8List avatarFixture() => prepareProfileAvatar(
  Uint8List.fromList(
    img.encodePng(
      img.Image(width: 60, height: 90)..clear(img.ColorRgb8(90, 125, 180)),
    ),
  ),
)!;

class FakeAvatarPicker implements ProfileAvatarPicker {
  int calls = 0;
  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    calls++;
    return avatarFixture();
  }
}

SignupRequest request(String email, String name) => SignupRequest(
  nickname: name,
  email: email,
  password: 'password123',
  termsAgreed: true,
  privacyAgreed: true,
  bodyPhotoAgreed: true,
  aiProcessingAgreed: true,
);

void main() {
  setUpAll(() async {
    for (final f in {
      'CapstoneUI': 'CapstoneUI-Regular.ttf',
      'CapstoneUIMedium': 'CapstoneUI-Medium.ttf',
    }.entries) {
      await (FontLoader(
        f.key,
      )..addFont(rootBundle.load('assets/fonts/${f.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test('다른 기기 계정의 이름과 동시 중복 저장을 막고 자신의 이름은 허용한다', () async {
    final prefs = IdentityPreferences();
    final a = LocalNicknameRegistry(prefs), b = LocalNicknameRegistry(prefs);
    final results = await Future.wait([
      a
          .save('a@test.com', 'Nickname', () async => true)
          .catchError((_) => false),
      b
          .save('b@test.com', 'nickname', () async => true)
          .catchError((_) => false),
    ]);
    expect(results, [true, false]);
    await a.save('a@test.com', 'Nickname', () async {});
    await a.save('a@test.com', '새이름', () async {});
    await b.save('b@test.com', 'nickname', () async {});
    expect(jsonDecode(prefs.data[LocalNicknameRegistry.key] as String), {
      'a@test.com': '새이름',
      'b@test.com': 'nickname',
    });
  });
  test('가입·닉네임 변경은 같은 중복 목록을 사용하고 저장 실패를 되돌린다', () async {
    final prefs = IdentityPreferences(),
        repo = LocalOnboardingRepository(preferences: IdentityPreferences());
    // 같은 저장소로 생성한 실제 로컬 가입·로그인 경로를 검증한다.
    final onboarding = LocalOnboardingRepository(preferences: prefs);
    await onboarding.register(request('a@test.com', '회원가'));
    await onboarding.login(email: 'a@test.com', password: 'test');
    await onboarding.saveProfile(editableProfile);
    await onboarding.complete(prepareAnalysis: false);
    await LocalNicknameRegistry(prefs).save('b@test.com', '회원나', () async {});
    await expectLater(onboarding.renameNickname('회원나'), throwsStateError);
    expect((await onboarding.load()).account!.nickname, '회원가');
    prefs.failProgress = true;
    await expectLater(onboarding.renameNickname('실패이름'), throwsStateError);
    prefs.failProgress = false;
    expect(
      jsonDecode(prefs.data[LocalNicknameRegistry.key] as String)['a@test.com'],
      '회원가',
    );
    await onboarding.renameNickname('변경회원');
    expect(
      (await onboarding.load()).profile!.heightCm,
      editableProfile.heightCm,
    );
    expect((await onboarding.load()).completed, true);
    await expectLater(
      onboarding.register(request('c@test.com', '변경회원')),
      throwsStateError,
    );
    expect((await onboarding.load()).account!.email, 'a@test.com');
    expect((await repo.load()).account, isNull);
  });
  test('사진은 계정별로 복원·삭제하고 탈퇴는 본인 닉네임 예약만 정리한다', () async {
    final prefs = IdentityPreferences(), bytes = avatarFixture();
    final a = ProfileAvatarStore('a@test.com', preferences: prefs),
        b = ProfileAvatarStore('b@test.com', preferences: prefs);
    await a.save(bytes);
    await b.save(bytes);
    expect(
      await ProfileAvatarStore('a@test.com', preferences: prefs).load(),
      bytes,
    );
    await LocalNicknameRegistry(prefs).save('a@test.com', '회원가', () async {});
    await LocalNicknameRegistry(prefs).save('b@test.com', '회원나', () async {});
    await AccountDataCleaner('a@test.com', preferences: prefs).clear();
    expect(await a.load(), isNull);
    expect(await b.load(), bytes);
    expect(jsonDecode(prefs.data[LocalNicknameRegistry.key] as String), {
      'b@test.com': '회원나',
    });
    final image = img.decodeJpg(bytes)!;
    expect(image.width, 256);
    expect(image.height, 256);
  });
  for (final scale in [1.0, 1.3]) {
    testWidgets('프로필 클릭·중복 오류·사진/이름 저장·사진 삭제 $scale', (t) async {
      t.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final prefs = IdentityPreferences(), picker = FakeAvatarPicker();
      final store = ProfileAvatarStore(
        previewAccount.storageOwner,
        preferences: prefs,
      );
      final names = LocalNicknameRegistry(prefs);
      await t.runAsync(
        () => names.save('another@test.com', '중복닉네임', () async {}),
      );
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (c, child) => RepaintBoundary(
            key: const Key('capture'),
            child: MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
          home: MyPage(
            onboarding: const OnboardingProgress(
              account: previewAccount,
              profile: editableProfile,
              completed: true,
            ),
            profileRepository: FakeProfileRepository(),
            photoRepository: FakePhotoRepository(),
            photoPicker: FakePhotoPicker(),
            avatarStore: store,
            avatarPicker: picker,
            onNicknameSave: (name) =>
                names.save(previewAccount.storageOwner, name, () async => name),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.widget<CircleAvatar>(find.byType(CircleAvatar).first).radius,
        26,
      );
      await t.tap(find.byKey(const Key('profile-identity')));
      await t.pumpAndSettle();
      expect(find.byType(ProfileIdentityPage), findsOneWidget);
      await t.tap(find.byKey(const Key('profile-avatar-change')));
      await t.pumpAndSettle();
      await t.tap(find.text('앨범에서 선택'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('profile-nickname')), '중복닉네임');
      t.testTextInput.hide();
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('저장'));
      await t.pumpAndSettle();
      await t.tap(find.text('저장'));
      await t.pumpAndSettle();
      expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
      expect(await store.load(), isNull);
      await t.enterText(find.byKey(const Key('profile-nickname')), '새닉네임');
      t.testTextInput.hide();
      await t.pumpAndSettle();
      final avatar = t.widget<CircleAvatar>(find.byType(CircleAvatar).first);
      await t.runAsync(
        () => precacheImage(
          avatar.backgroundImage!,
          t.element(find.byType(ProfileIdentityPage)),
        ),
      );
      await t.pumpAndSettle();
      await capture(t, 'profile-identity-$scale');
      await t.ensureVisible(find.text('저장'));
      await t.pumpAndSettle();
      await t.tap(find.text('저장'));
      await t.pumpAndSettle();
      expect(find.text('새닉네임'), findsOneWidget);
      expect(await store.load(), isNotNull);
      await t.tap(find.byKey(const Key('profile-identity')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('profile-avatar-change')));
      await t.pumpAndSettle();
      await t.tap(find.text('사진 삭제'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('저장'));
      await t.pumpAndSettle();
      await t.tap(find.text('저장'));
      await t.pumpAndSettle();
      expect(await store.load(), isNull);
      expect(picker.calls, 1);
      expect(t.takeException(), isNull);
    });
  }
}
