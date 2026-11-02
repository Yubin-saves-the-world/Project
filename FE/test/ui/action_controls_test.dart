import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/ui/core/widgets/action_controls.dart';

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('긴 확인 문구도 취소 버튼과 같은 크기이며 선택·바깥 터치 정책을 유지한다 $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAppConfirmation(
                    context,
                    '추천 루틴으로 교체할까요?',
                    '직접 만든 다른 날짜의 일정과 완료 기록은 유지돼요.',
                    action: '추천 루틴으로 교체',
                    cancelLabel: '내 운동 유지',
                    barrierDismissible: false,
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      final cancel = tester.getRect(
        find.widgetWithText(OutlinedButton, '내 운동 유지'),
      );
      final action = tester.getRect(
        find.widgetWithText(FilledButton, '추천 루틴으로 교체'),
      );
      expect(cancel.size, action.size);
      expect(cancel.top, action.top);
      expect(action.height, greaterThanOrEqualTo(48));
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('내 운동 유지'));
      await tester.pumpAndSettle();
      expect(result, false);
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('추천 루틴으로 교체'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(tester.takeException(), isNull);
    });
  }
}
