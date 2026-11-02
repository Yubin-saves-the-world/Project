import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/data/recommendation_demo.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/pages/weekly_routine_editor.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../../fakes/fake_home_repository.dart';

void main() {
  testWidgets('휴식일은 출처 탭을 숨기고 올라가며 운동일로 돌아오면 초안과 탭이 유지된다', (tester) async {
    final model = HomeViewModel(
      repository: FakeHomeRepository(emptySchedule: true),
      today: DateTime(2026, 10, 28),
    );
    await model.initialize();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WeeklyRoutineEditor(
          model: model,
          date: model.today,
          demoRecommendation: RecommendationDemo.forDate(model.today),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('routine-title')), '내 운동 초안');
    final before = tester
        .getTopLeft(find.byKey(const Key('routine-rest-day')))
        .dy;
    await tester.tap(find.byKey(const Key('routine-rest-day')));
    await tester.pumpAndSettle();
    expect(find.text('직접 만든 일정'), findsNothing);
    expect(find.text('추천 루틴'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('routine-rest-day'))).dy,
      lessThan(before),
    );
    await tester.tap(find.byKey(const Key('routine-workout-day')));
    await tester.pumpAndSettle();
    expect(find.text('직접 만든 일정'), findsOneWidget);
    expect(find.text('내 운동 초안'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
