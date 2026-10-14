import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/pages/workout_calendar_page.dart';
import 'package:fe/features/auth/data/password_reset_repository.dart';
import 'package:fe/features/auth/presentation/pages/password_reset_page.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../fakes/fake_home_repository.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'CapstoneUI': 'CapstoneUI-Regular.ttf',
      'CapstoneUIMedium': 'CapstoneUI-Medium.ttf',
      'Inter': 'Inter.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  void screen(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('달력 선택일과 오늘 원 안의 숫자 정렬', (tester) async {
    screen(tester);
    final model = HomeViewModel(
      repository: FakeHomeRepository(),
      today: DateTime(2026, 10, 14),
    );
    await model.initialize();
    model.select(DateTime(2026, 10, 13));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: WorkoutCalendarPage(model: model),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../docs/frontend-architecture/previews/workout-calendar.png',
      ),
    );
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
  testWidgets('비밀번호 찾기 페이지 디자인', (tester) async {
    screen(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: PasswordResetPage(repository: PreviewPasswordResetRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('비밀번호 찾기')).dy, lessThan(130));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../docs/frontend-architecture/previews/password-reset.png',
      ),
    );
  });
}
