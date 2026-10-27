import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fe/app/vitality_app.dart';
import 'package:fe/features/auth/data/local_onboarding_repository.dart';
import 'package:fe/features/auth/data/local_nickname_registry.dart';
import 'package:fe/features/auth/data/models/signup_request.dart';
import 'package:fe/features/profile/data/profile_avatar_store.dart';
import 'package:fe/features/settings/data/account_data_cleaner.dart';
import '../test/fakes/fake_onboarding_repository.dart';
import '../test/fakes/fake_profile_photo_repositories.dart';
import 'native_smoke_test.dart' show tap, enter, settle;

/// 실제 preferences 플러그인을 사용하되 QA의 가입 데이터는 별도 키에 격리한다.
class ScopedIdentityPreferences implements SharedPreferencesAsync {
  ScopedIdentityPreferences(this.prefix);
  final String prefix;
  final _prefs = SharedPreferencesAsync();
  @override
  Future<String?> getString(String key) => _prefs.getString('$prefix$key');
  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString('$prefix$key', value);
  Future<void> cleanup() async {
    for (final key in (await _prefs.getKeys()).where(
      (k) => k.startsWith(prefix),
    )) {
      await _prefs.remove(key);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iOS 프로필 닉네임 중복·변경·사진 복원과 홈 반영', (t) async {
    final run = DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        owner = 'profile-qa-$run@example.com';
    final prefs = ScopedIdentityPreferences('movid.qa.identity.$run.');
    final repo = LocalOnboardingRepository(preferences: prefs);
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await AccountDataCleaner(owner).clear();
      await prefs.cleanup();
    });
    await repo.register(
      SignupRequest(
        nickname: '프로필회원',
        email: owner,
        password: 'testpassword',
        termsAgreed: true,
        privacyAgreed: true,
        bodyPhotoAgreed: true,
        aiProcessingAgreed: true,
      ),
    );
    await repo.login(email: owner, password: 'testpassword');
    await repo.saveProfile(editableProfile);
    await repo.complete(prepareAnalysis: false);
    await LocalNicknameRegistry(
      prefs,
    ).save('other-qa-$run@example.com', '사용중닉네임', () async {});
    final avatar = prepareProfileAvatar(
      Uint8List.fromList(
        img.encodePng(
          img.Image(width: 80, height: 120)..clear(img.ColorRgb8(70, 110, 170)),
        ),
      ),
    )!;
    await ProfileAvatarStore(owner).save(avatar);
    await t.pumpWidget(
      VitalityApp(onboardingRepository: repo, photoPicker: FakePhotoPicker()),
    );
    await settle(t);
    expect(
      find.descendant(
        of: find.byTooltip('마이페이지'),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
    await tap(t, find.byTooltip('마이페이지'));
    await tap(t, find.byKey(const Key('profile-identity')));
    expect(find.text('프로필 수정'), findsOneWidget);
    expect(
      t.widget<CircleAvatar>(find.byType(CircleAvatar).first).backgroundImage,
      isNotNull,
    );
    await enter(t, 'profile-nickname', '사용중닉네임');
    await tap(t, find.text('저장'));
    expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
    final input = find.byKey(const Key('profile-nickname'));
    // Native IME may restore its previous composing value after enterText.
    // Typing is covered by widget tests; this smoke test verifies persistence.
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    t.widget<TextField>(input).controller!.value = const TextEditingValue(
      text: 'ChangedQA',
      selection: TextSelection.collapsed(offset: 9),
    );
    await t.pump();
    await tap(t, find.text('저장'));
    expect(find.text('ChangedQA'), findsOneWidget);
    expect((await repo.load()).account!.nickname, 'ChangedQA');
    expect(await ProfileAvatarStore(owner).load(), avatar);
    await tap(t, find.byTooltip('뒤로가기'));
    expect(find.textContaining('ChangedQA님,'), findsOneWidget);
    final names = jsonDecode(
      (await prefs.getString(LocalNicknameRegistry.key))!,
    );
    expect(names[owner], 'ChangedQA');
    expect(t.takeException(), isNull);
  });
}
