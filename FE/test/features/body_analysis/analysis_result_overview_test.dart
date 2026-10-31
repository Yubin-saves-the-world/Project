import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';
import 'package:fe/features/body_analysis/presentation/widgets/analysis_result_overview.dart';
import '../profile/my_page_test.dart' show capture;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in {
      'CapstoneUI': 'CapstoneUI-Regular.ttf',
      'CapstoneUIMedium': 'CapstoneUI-Medium.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
  });
  for (final mobile in [false, true]) {
    testWidgets('측정값을 중복 없이 표시하고 작은 화면에서도 읽을 수 있다 $mobile', (tester) async {
      tester.view.physicalSize = mobile
          ? const Size(360, 800)
          : const Size(960, 1150);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final result = BodyAnalysis(
        id: 5,
        status: AnalysisStatus.done,
        createdAt: DateTime(2026, 10, 28),
        measures: const {
          'shoulder_tilt_deg': .4,
          'pelvis_tilt_deg': 1.18,
          'shoulder_hip_ratio': 1.72,
          'torso_leg_ratio': .7,
        },
        dinoParts: const [
          DinoPartResult('left_upper_arm', 'extracted'),
          DinoPartResult('right_upper_arm', 'extracted'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(mobile ? 1.3 : 1)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const Key('capture'),
            child: Scaffold(
              appBar: AppBar(title: const Text('체형 분석')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnalysisResultOverview(result: result),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0.40°'), findsOneWidget);
      expect(find.text('1.18°'), findsOneWidget);
      expect(find.text('1.72배'), findsOneWidget);
      expect(find.text('0.70배'), findsOneWidget);
      expect(find.text('체형 측정'), findsNothing);
      expect(find.text('균형 점수·근육 발달 등급·개인별 운동 처방은 제공하지 않아요.'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(
        tester,
        mobile ? 'analysis-readable-mobile' : 'analysis-readable-desktop',
      );
      await tester.scrollUntilVisible(find.text('분석 범위와 기준'), 300);
      await tester.tap(find.text('분석 범위와 기준'));
      await tester.pumpAndSettle();
      expect(find.text('균형 점수·근육 발달 등급·개인별 운동 처방은 제공하지 않아요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, mobile ? 'analysis-readable-mobile-details' : 'analysis-readable-desktop-details');
    });
  }
}
