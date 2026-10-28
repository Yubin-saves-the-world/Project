import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/features/home/presentation/pages/weekly_routine_editor.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../fakes/fake_home_repository.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'CapstoneUI': 'CapstoneUI-Regular.ttf',
      'CapstoneUIMedium': 'CapstoneUI-Medium.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('일정 페이지의 항목 순서·부위 그룹과 뒤로가기를 확인한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: HomePage(
          repository: FakeHomeRepository(emptySchedule: true),
          today: DateTime(2026, 10, 14),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../docs/frontend-architecture/previews/home-first-run.png',
      ),
    );
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byKey(ValueKey('home-weekday-$i')));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyRoutineEditor), findsNothing);
    }
    await tester.tap(find.byKey(const ValueKey('home-weekday-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일정 만들기'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../docs/frontend-architecture/previews/weekly-routine-editor.png',
      ),
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byTooltip('뒤로가기').hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('routine-title'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('routine-repeat'))).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('routine-repeat'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('routine-minutes'))).dy),
    );
    for (final category in ['가슴', '등', '하체', '어깨', '팔', '코어']) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('routine-category-$category')),
          matching: find.byType(CheckboxListTile),
        ),
        findsNWidgets(4),
      );
    }
    await tester.tap(find.byKey(const Key('routine-repeat')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../docs/frontend-architecture/previews/routine-scope-menu.png',
      ),
    );
    await tester.tap(find.text('이번 날짜만'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('routine-save')).hitTestable(), findsOneWidget);
    final savePosition = tester.getTopLeft(
      find.byKey(const Key('routine-save')),
    );
    await tester.tap(find.byKey(const Key('routine-save')));
    await tester.pumpAndSettle();
    expect(find.text('운동 종목을 하나 이상 선택해 주세요.').hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('routine-save'))),
      savePosition,
    );
    await tester.enterText(
      find.byKey(const Key('routine-title')),
      '저장하지 않은 루틴',
    );
    await tester.tap(find.byKey(const Key('routine-back')));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyRoutineEditor), findsNothing);
    expect(find.text('일주일 운동 일정을 만들어 주세요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
