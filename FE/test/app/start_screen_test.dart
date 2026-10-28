import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/app/start_screen.dart';
import 'package:fe/app/vitality_app.dart';
import 'package:fe/features/auth/data/models/onboarding_progress.dart';
import 'package:fe/features/auth/presentation/pages/login_page.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../fakes/fake_onboarding_repository.dart';

class PendingStartupRepository extends FakeOnboardingRepository {
  final ready = Completer<OnboardingProgress>();
  @override
  Future<OnboardingProgress> load() => ready.future;
}

Future<void> capture(WidgetTester t, String path, {double scale = 1}) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: scale);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    for (final entry in {
      'CapstoneUIMedium': 'CapstoneUI-Medium.ttf',
      'CapstoneUI': 'CapstoneUI-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
  });
  testWidgets(
    'start screen matches Figma geometry and scales without overflow',
    (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const RepaintBoundary(
            key: Key('capture'),
            child: AppStartScreen(),
          ),
        ),
      );
      await t.runAsync(
        () => precacheImage(
          const AssetImage(AppStartScreen.logo),
          t.element(find.byType(AppStartScreen)),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.getRect(find.byKey(const Key('start-logo'))),
        const Rect.fromLTWH(81, 238, 230, 230),
      );
      expect(
        t.getRect(find.byKey(const Key('start-wordmark'))),
        const Rect.fromLTWH(153, 705, 93, 39),
      );
      await expectLater(
        find.byKey(const Key('capture')),
        matchesGoldenFile(
          '../../docs/project-context/previews/start-screen.png',
        ),
      );
      for (final size in [
        const Size(320, 640),
        const Size(834, 1194),
        const Size(852, 393),
      ]) {
        t.view.physicalSize = size;
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final canvas = t.getRect(find.byKey(const Key('start-canvas')));
        expect(canvas.left, greaterThanOrEqualTo(-.01));
        expect(canvas.top, greaterThanOrEqualTo(-.01));
        expect(canvas.right, lessThanOrEqualTo(size.width + .01));
        expect(canvas.bottom, lessThanOrEqualTo(size.height + .01));
      }
    },
  );
  for (final signedIn in [false, true]) {
    testWidgets(
      'startup restores ${signedIn ? 'existing home' : 'login'} without changing account',
      (t) async {
        t.view.physicalSize = const Size(393, 852);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final repo = PendingStartupRepository();
        final saved = OnboardingProgress(
          account: previewAccount,
          profile: previewProfile,
          completed: true,
          signedIn: signedIn,
        );
        await t.pumpWidget(
          VitalityApp(
            onboardingRepository: repo,
            photoPicker: FakePhotoPicker(),
          ),
        );
        expect(find.byType(AppStartScreen), findsOneWidget);
        repo.progress = saved;
        repo.ready.complete(saved);
        await t.pumpAndSettle();
        expect(find.byType(AppStartScreen), findsNothing);
        expect(find.byType(signedIn ? HomePage : LoginPage), findsOneWidget);
        expect(repo.progress.account, same(saved.account));
        expect(repo.accountWrites, 0);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('native wordmark uses the same font and color as Flutter', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Material(
          type: MaterialType.transparency,
          child: Center(
            child: RepaintBoundary(
              key: const Key('capture'),
              child: const MovidWordmark(),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    if (const bool.fromEnvironment('GENERATE_NATIVE_BRANDING')) {
      await capture(t, 'assets/branding/movid-wordmark.png', scale: 3);
    }
    expect(
      t.getSize(find.byKey(const Key('start-wordmark'))),
      const Size(93, 39),
    );
    expect(t.takeException(), isNull);
  });
}
