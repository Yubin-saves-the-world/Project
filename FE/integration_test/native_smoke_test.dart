import 'package:fe/features/auth/data/server_onboarding_repository.dart';
import 'package:fe/features/auth/data/token_store.dart';
import '../test/fakes/mvp_contract_server.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:fe/app/vitality_app.dart';
import 'package:fe/core/media/image_picker_service.dart';
import 'package:fe/features/settings/data/account_data_cleaner.dart';
import 'package:fe/features/photos/data/photo_preparer.dart';
import 'package:fe/features/photos/data/models/selected_photo.dart';
import '../test/fakes/fake_onboarding_repository.dart';

Future<void> settle(WidgetTester t) => t.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 20),
);
Future<void> tap(WidgetTester t, Finder f) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(t);
  await t.ensureVisible(f);
  await settle(t);
  await t.tap(f);
  await settle(t);
}

Future<void> enter(WidgetTester t, String key, String value) async {
  final f = find.byKey(Key(key));
  final input = t.widget(f) is TextFormField || t.widget(f) is TextField
      ? f
      : find.descendant(of: f, matching: find.byType(TextFormField));
  await t.ensureVisible(input);
  await t.enterText(input, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(t);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('iOS 네이티브 화면: 개발용 가입·설문·홈·기록·로그아웃', (t) async {
    final run = DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        owner = 'qa-native-$run@example.com';
    final repository = FakeOnboardingRepository();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await AccountDataCleaner(owner).clear();
    });
    await t.pumpWidget(
      VitalityApp(
        onboardingRepository: repository,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await settle(t);
    await tap(t, find.text('회원가입'));
    await enter(t, 'signup-nickname', 'QA 회원');
    await enter(t, 'signup-email', owner);
    await tap(t, find.text('인증번호 받기'));
    await tap(t, find.text('확인'));
    await enter(t, 'signup-code', '123456');
    await enter(t, 'signup-password', 'password123');
    await tap(t, find.text('다음'));
    await tap(t, find.text('전체 동의'));
    await tap(t, find.text('동의하고 계속'));
    await enter(t, 'profile-height', '174');
    await enter(t, 'profile-weight', '68');
    await enter(t, 'profile-age', '20');
    await tap(t, find.text('남'));
    await tap(t, find.text('다음'));
    await tap(t, find.text('근육 키우기'));
    await tap(t, find.text('4 ~ 5회'));
    await tap(t, find.text('다음'));
    await tap(t, find.text('3개월 미만'));
    await tap(t, find.text('다음'));
    expect(repository.progress.profile!.weeklyFrequency, 5);
    expect(find.text('분석 기록'), findsNothing);
    expect(find.text('준비 중'), findsNothing);
    await tap(t, find.text('글로 설명하기'));
    expect(find.text('글 분석 준비 중'), findsOneWidget);
    await tap(t, find.text('확인'));
    await tap(t, find.text('다음에 하기'));
    expect(find.textContaining('QA 회원님,'), findsOneWidget);
    await t.scrollUntilVisible(find.text('보기'), 200);
    await tap(t, find.text('보기'));
    expect(find.text('운동 기록'), findsOneWidget);
    await tap(t, find.byType(BackButton));
    await t.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 1600),
    );
    await settle(t);
    await tap(t, find.byTooltip('마이페이지'));
    await t.scrollUntilVisible(find.text('로그아웃'), 200);
    await tap(t, find.text('로그아웃'));
    await tap(t, find.widgetWithText(FilledButton, '로그아웃'));
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });
  testWidgets('iOS 네이티브 저장소·사진 처리·계정 사본 정리의 다른 계정 보존', (t) async {
    final run = DateTime.now().microsecondsSinceEpoch,
        owner = 'qa-files-$run@example.com',
        other = 'qa-other-$run@example.com';
    final prefs = SharedPreferencesAsync();
    String key(String s) =>
        'movid.workout.v1.${base64Url.encode(utf8.encode(s))}.87';
    final support = (await getApplicationSupportDirectory()).path;
    Directory folder(String s) => Directory(
      '$support/onboarding_photos/${base64Url.encode(utf8.encode('analysis:$s'))}',
    );
    final mine = folder(owner), theirs = folder(other);
    await mine.create(recursive: true);
    await theirs.create(recursive: true);
    await File(
      '${mine.path}/test.jpg',
    ).writeAsBytes(img.encodeJpg(img.Image(width: 32, height: 32)));
    await File('${theirs.path}/keep.txt').writeAsString('other account');
    await prefs.setString(key(owner), 'private');
    await prefs.setString(key(other), 'other');
    try {
      final bytes = await FilePhotoPreparer().prepare(
        SelectedPhoto(path: '${mine.path}/test.jpg', byteLength: 10),
      );
      expect(bytes.take(2), [255, 216]);
      await AccountDataCleaner(owner).clear();
      await ImagePickerService.clearAccountCopies(owner);
      expect(await prefs.getString(key(owner)), isNull);
      expect(await prefs.getString(key(other)), 'other');
      expect(await mine.exists(), false);
      expect(await File('${theirs.path}/keep.txt').exists(), true);
    } finally {
      await prefs.remove(key(owner));
      await prefs.remove(key(other));
      if (await mine.exists()) await mine.delete(recursive: true);
      if (await theirs.exists()) await theirs.delete(recursive: true);
    }
  });
  testWidgets('iOS 계약 HTTP: 분석→루틴→운동→기록 수정→계정 탈퇴 화면 연결', (t) async {
    final owner =
        'qa-flow-${DateTime.now().microsecondsSinceEpoch}@example.com';
    final server = MvpContractServer(email: owner)
      ..registered = true
      ..profileSaved = true;
    final tokens = MemoryTokenStore();
    await tokens.write('qa-token');
    final repository = ServerOnboardingRepository(
      baseUrl: 'http://contract.test',
      client: server.client,
      tokenStore: tokens,
    );
    final directory = await Directory.systemTemp.createTemp('movid-qa-flow-');
    final file = File('${directory.path}/front.jpg');
    await file.writeAsBytes(img.encodeJpg(img.Image(width: 32, height: 32)));
    final picker = FakePhotoPicker()
      ..nextPhoto = SelectedPhoto(
        path: file.path,
        byteLength: await file.length(),
      );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox.shrink());
      await AccountDataCleaner(owner).clear();
      await directory.delete(recursive: true);
      server.client.close();
    });
    await t.pumpWidget(
      VitalityApp(onboardingRepository: repository, photoPicker: picker),
    );
    await settle(t);
    await tap(t, find.byKey(const ValueKey('nav-분석')));
    await tap(t, find.text('사진으로 분석'));
    await tap(t, find.byKey(const Key('front-photo')));
    await tap(t, find.text('앨범에서 선택'));
    await tap(t, find.text('확인'));
    await tap(t, find.text('분석 시작'));
    await t.scrollUntilVisible(find.text('맞춤 루틴 만들기'), 200);
    await tap(t, find.text('맞춤 루틴 만들기'));
    await tap(t, find.text('만들기'));
    await t.scrollUntilVisible(find.text('루틴 상세 보기'), 200);
    await tap(t, find.text('루틴 상세 보기'));
    await t.scrollUntilVisible(find.text('이 종목 시작 · 이어하기'), 200);
    await tap(t, find.text('이 종목 시작 · 이어하기'));
    await enter(t, 'set-weight', '60');
    await t.ensureVisible(find.text('세트 완료'));
    await tap(t, find.text('세트 완료'));
    await tap(t, find.text('종목 종료'));
    await enter(t, 'workout-memo', '시뮬레이터 QA');
    await tap(t, find.text('기록 저장하고 종료'));
    expect(find.text('오늘 루틴 완료'), findsOneWidget);
    expect(find.text('600kg'), findsOneWidget);
    await tap(t, find.text('홈으로'));
    await t.scrollUntilVisible(find.text('보기'), 200);
    await tap(t, find.text('보기'));
    await t.scrollUntilVisible(find.text('바벨 스쿼트'), 200);
    await tap(t, find.text('바벨 스쿼트'));
    await t.scrollUntilVisible(find.text('세트 수정'), 200);
    await tap(t, find.text('세트 수정'));
    await enter(t, 'record-weight', '63');
    await tap(t, find.text('수정 저장'));
    await t.drag(find.byType(ListView), const Offset(0, 1000));
    await settle(t);
    expect(find.textContaining('총 볼륨 630kg'), findsOneWidget);
    await tap(t, find.byTooltip('뒤로가기'));
    await tap(t, find.byTooltip('뒤로가기'));
    await t.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 2000),
    );
    await settle(t);
    await tap(t, find.byTooltip('마이페이지'));
    await t.scrollUntilVisible(find.text('내 계정 정보'), 200);
    await tap(t, find.text('내 계정 정보'));
    await enter(t, 'account-nickname', 'QA 사용자');
    await tap(t, find.text('닉네임 저장'));
    await tap(t, find.byTooltip('뒤로가기'));
    await t.scrollUntilVisible(find.text('회원 탈퇴'), 200);
    await tap(t, find.text('회원 탈퇴'));
    await tap(t, find.byType(CheckboxListTile));
    await tap(t, find.byKey(const Key('account-delete-submit')));
    await tap(t, find.text('탈퇴하기'));
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(server.removed, true);
    expect(await tokens.read(), isNull);
  });
}
