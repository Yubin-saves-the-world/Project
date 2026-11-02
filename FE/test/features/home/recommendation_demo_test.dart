import 'package:fe/features/home/data/recommendation_demo.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/pages/weekly_routine_editor.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../fakes/fake_home_repository.dart';

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('더미 추천 확인과 적용은 실제 일정·기록을 변경하지 않는다 $scale', (tester) async {
      tester.view.physicalSize = Size(scale == 1 ? 393 : 320, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeHomeRepository(emptySchedule: true);
      final before = repository.weeklySchedule?.toJson();
      final model = HomeViewModel(
        repository: repository,
        today: DateTime(2026, 10, 31),
      );
      await model.initialize();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: WeeklyRoutineEditor(
            model: model,
            date: model.today,
            demoRecommendation: RecommendationDemo.forDate(model.today),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('추천 루틴'));
      await tester.pumpAndSettle();
      expect(find.text('등·어깨 균형 루틴'), findsOneWidget);
      expect(find.text('랫 풀다운'), findsOneWidget);
      expect(find.text('덤벨 숄더 프레스'), findsOneWidget);
      await tester.tap(find.byKey(const Key('routine-save')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, '선택'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('선택한 추천 루틴이에요.'));
      expect(repository.weeklySchedule?.toJson(), before);
      expect(repository.workouts, isEmpty);
      expect(repository.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
