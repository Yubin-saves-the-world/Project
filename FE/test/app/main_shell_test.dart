import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/app/vitality_app.dart';
import 'package:fe/app/router/route_paths.dart';

void main() {
  testWidgets('MVP 탭에서 각 기능 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(const VitalityApp(initialRoute: RoutePaths.home));

    await tester.pumpAndSettle();
    expect(find.text('오늘의 루틴'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.center_focus_strong_outlined));
    await tester.pumpAndSettle();
    expect(find.text('로그인 후 체형 분석을 이용해 주세요.'), findsOneWidget);
    expect(find.text('오늘의 루틴'), findsNothing);

    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();
    expect(find.text('운동 기록 준비 중'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('인공지능 코치 준비 중'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.people_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('로그인 후 커뮤니티를 이용해 주세요.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-홈')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.text('오늘의 루틴'), findsOneWidget);
  });
}
