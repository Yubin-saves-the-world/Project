import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/app/vitality_app.dart';
import 'package:fe/app/router/route_paths.dart';

void main() {
  testWidgets('MVP 탭에서 각 기능 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(const VitalityApp(initialRoute: RoutePaths.home));

    expect(find.text('홈 화면 개발 준비'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('분석 화면 개발 준비'), findsOneWidget);
    expect(find.text('홈 화면 개발 준비'), findsNothing);

    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();
    expect(find.text('기록 화면 개발 준비'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('홈 화면 개발 준비'), findsOneWidget);
  });
}
