import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/home/presentation/home_view_model.dart';
import 'package:fe/features/home/presentation/pages/weekly_routine_editor.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/ui/core/widgets/app_selection.dart';
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

  test('새 선택 목록은 백엔드 시드의 24개와 일치하고 기존 종목 번호는 유지한다', () {
    final sql = File(
      '../BE/src/main/resources/db/migration/V1_1__seed_exercises.sql',
    ).readAsStringSync();
    final expected = RegExp(
      r"\('([^']+)', '(chest|back|leg|shoulder|arm|core)',",
    ).allMatches(sql).map((m) => m[1]).toSet();
    final offered = HomeViewModel.exercises
        .where((e) => e.selectable)
        .map((e) => e.name)
        .toSet();
    expect(offered.length, 24);
    expect(offered, expected);
    expect(HomeViewModel.exercises[1].name, '루마니안 데드리프트');
    expect(HomeViewModel.exercises[4].name, '벤치 프레스');
    expect(HomeViewModel.exercises[1].selectable, isFalse);
  });

  testWidgets('적용 범위는 선택칸 아래에서 열리고 바깥을 누르면 값을 유지한다', (tester) async {
    final model = HomeViewModel(
      repository: FakeHomeRepository(emptySchedule: true),
      today: DateTime(2026, 10, 20),
    );
    await model.initialize();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: WeeklyRoutineEditor(model: model, date: model.today),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('routine-repeat')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester.getTopLeft(find.byType(MenuItemButton).first).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.byKey(const Key('routine-repeat'))).dy,
      ),
    );
    await tester.tap(find.text('이번 날짜만'));
    await tester.pumpAndSettle();
    expect(find.text('이번 날짜만'), findsOneWidget);
    await tester.tap(find.byKey(const Key('routine-repeat')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 70));
    await tester.pumpAndSettle();
    expect(find.text('이번 날짜만'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('시간 프리셋은 저장되고 닫으면 기존 시간을 유지한다', (tester) async {
    final repo = FakeHomeRepository(emptySchedule: true);
    final model = HomeViewModel(
      repository: repo,
      today: DateTime(2026, 10, 20),
    );
    await model.initialize();
    addTearDown(model.dispose);
    await model.saveRoutine(
      model.today,
      DayRoutine(
        title: '운동',
        items: [const RoutineItem(exercise: 0, sets: 3, reps: 10)],
      ),
      repeat: true,
    );
    Future<void> openEditor() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        WeeklyRoutineEditor(model: model, date: model.today),
                  ),
                ),
                child: const Text('편집'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
    }

    await openEditor();
    await tester.tap(find.byKey(const Key('routine-minutes')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
    await tester.tap(find.widgetWithText(ChoiceChip, '1시간 30분'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('duration-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('1시간 30분'), findsOneWidget);
    await tester.tap(find.byKey(const Key('routine-minutes')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '30분'));
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('1시간 30분'), findsOneWidget);
    await tester.tap(find.byKey(const Key('routine-save')));
    await tester.pumpAndSettle();
    expect(model.selectedRoutine!.minutes, 90);
    await tester.tap(find.text('편집'));
    await tester.pumpAndSettle();
    expect(find.text('1시간 30분'), findsOneWidget);
    await tester.tap(find.byKey(const Key('routine-minutes')));
    await tester.pumpAndSettle();
    expect(find.text('설정 안 함'), findsNothing);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('1시간 30분'), findsOneWidget);
    await tester.tap(find.byKey(const Key('routine-save')));
    await tester.pumpAndSettle();
    expect(model.selectedRoutine!.minutes, 90);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('시간 휠은 0분을 저장하지 않고 10시간을 넘지 않는다', (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showWorkoutDurationPicker(context, minutes: 0);
              },
              child: const Text('시간'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('시간'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '선택 완료'))
          .onPressed,
      isNull,
    );
    tester
        .widget<CupertinoPicker>(find.byType(CupertinoPicker).first)
        .scrollController!
        .jumpToItem(10);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoPicker>(find.byType(CupertinoPicker).last)
          .childDelegate
          .estimatedChildCount,
      1,
    );
    await tester.tap(find.byKey(const Key('duration-confirm')));
    await tester.pumpAndSettle();
    expect(selected, 600);
  });

  for (final screen in ['selection', 'duration']) {
    testWidgets('$screen 선택 시트는 작은 화면·큰 글꼴에서 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  if (screen == 'duration') {
                    showWorkoutDurationPicker(context);
                  } else {
                    showAppSelection(
                      context,
                      title: '다른 요일 루틴 복사',
                      options: [
                        AppSelectionOption(1, '월요일 · ${'긴 이름의 루틴 ' * 5}'),
                      ],
                    );
                  }
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('닫기').hitTestable(), findsOneWidget);
    });
  }

  for (final screen in ['selection', 'duration']) {
    testWidgets('$screen 선택 화면 디자인', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    if (screen == 'duration') {
                      showWorkoutDurationPicker(context, minutes: 90);
                    } else {
                      showAppSelection(
                        context,
                        title: '적용 범위',
                        selected: true,
                        options: const [
                          AppSelectionOption(
                            true,
                            '앞으로 매주',
                            icon: Icons.event_repeat_rounded,
                          ),
                          AppSelectionOption(
                            false,
                            '이번 날짜만',
                            icon: Icons.today_rounded,
                          ),
                        ],
                      );
                    }
                  },
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../docs/frontend-architecture/previews/$screen-picker.png',
        ),
      );
    });
  }
}
