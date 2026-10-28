import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/widgets/app_icon.dart';
import 'package:fe/ui/core/widgets/material_icon_paths.dart';
import '../features/profile/my_page_test.dart' show capture;

void main() {
  setUpAll(() async {
    final font = FontLoader('IconQA')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  testWidgets('all current icons render with shared weight and no overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(420, 820);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          fontFamily: 'IconQA',
          scaffoldBackgroundColor: Colors.white,
        ),
        home: RepaintBoundary(
          key: const Key('capture'),
          child: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/home.svg',
                      width: 20,
                      height: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text('Home: 2px / 20px'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 6,
                    childAspectRatio: .95,
                    children: [
                      for (final code in materialIconPaths.keys)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppIcon(
                              IconData(code, fontFamily: 'MaterialIcons'),
                              size: 20,
                              color: const Color(0xFF808791),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              code.toRadixString(16),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byType(AppIcon), findsNWidgets(materialIconPaths.length));
    await capture(t, 'icon-weight-gallery');
  });

  testWidgets('input prefix keeps its visual size inside the larger slot', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextField(
            decoration: InputDecoration(
              prefixIcon: AppIcon(Icons.search_rounded, size: 23),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final icon = find.byType(AppIcon);
    final svg = find.descendant(of: icon, matching: find.byType(SvgPicture));
    expect(t.getSize(icon), const Size(48, 48));
    expect(t.getSize(svg), const Size(23, 23));
    expect(t.getCenter(svg), t.getCenter(icon));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'keeps inherited disabled opacity, semantics and directional behavior',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: IconTheme(
              data: const IconThemeData(
                size: 30,
                opacity: .4,
                color: Colors.blue,
              ),
              child: const AppIcon(
                Icons.arrow_back_rounded,
                semanticLabel: 'Back',
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      final svg = t.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, 30);
      expect(svg.matchTextDirection, isTrue);
      expect(
        svg.colorFilter,
        ColorFilter.mode(Colors.blue.withValues(alpha: .4), BlendMode.srcIn),
      );
      expect(t.takeException(), isNull);
    },
  );
}
