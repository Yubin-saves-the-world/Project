import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../fakes/fake_home_repository.dart';

void main() {
  testWidgets('기존 앱 로케일을 유지하면서 홈 달력만 한국어로 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          repository: FakeHomeRepository(),
          today: DateTime(2026, 10, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pageContext = tester.element(find.byType(HomePage));
    expect(Localizations.localeOf(pageContext).languageCode, 'en');
    await tester.ensureVisible(find.text('달력 보기'));
    await tester.tap(find.text('달력 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    final calendarContext = tester.element(find.byType(CalendarDatePicker));
    expect(Localizations.localeOf(calendarContext).languageCode, 'ko');
    expect(
      MaterialLocalizations.of(
        calendarContext,
      ).formatMonthYear(DateTime(2026, 10)),
      contains('10월'),
    );
    Navigator.of(calendarContext).pop();
    await tester.pumpAndSettle();
    expect(Localizations.localeOf(pageContext).languageCode, 'en');
    expect(tester.takeException(), isNull);
  });
}
