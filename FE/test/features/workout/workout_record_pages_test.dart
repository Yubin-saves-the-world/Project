import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/core/network/api_contract.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import 'package:fe/features/workout/presentation/pages/workout_history_page.dart';
import 'package:fe/features/workout/presentation/pages/workout_record_page.dart';
import 'package:fe/features/workout/presentation/workout_dependencies.dart';
import 'package:fe/features/home/presentation/home_server_dependencies.dart';
import 'package:fe/features/home/presentation/pages/home_page.dart';
import 'package:fe/features/home/presentation/pages/workout_calendar_page.dart';
import '../../fakes/fake_workout_history.dart';
import '../../fakes/fake_workout_repository.dart';
import '../../fakes/fake_home_server.dart';
import '../../fakes/fake_home_repository.dart';
import '../profile/my_page_test.dart' show capture;

HomeServerDependencies historyDependencies(
  FakeWorkoutHistory history,
  FakeWorkoutRecordRepository records,
) => HomeServerDependencies(
  repository: history,
  routines: history.routines,
  choices: FakeChoiceStore(),
  workouts: WorkoutDependencies(
    repository: records,
    drafts: MemoryWorkoutDraftStore(),
  ),
);
Widget shell(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  builder: (c, page) => MediaQuery(
    data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
    child: RepaintBoundary(key: const Key('capture'), child: page!),
  ),
  home: child,
);
void main() {
  setUpAll(() async {
    for (final f in {
      'CapstoneUI': 'CapstoneUI-Regular.ttf',
      'CapstoneUIMedium': 'CapstoneUI-Medium.ttf',
    }.entries) {
      await (FontLoader(
        f.key,
      )..addFont(rootBundle.load('assets/fonts/${f.value}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final scale in [1.0, 1.3]) {
    testWidgets('기록 달력·상태 필터·완료 세트 편집과 취소 $scale', (tester) async {
      tester.view.physicalSize = scale == 1
          ? const Size(393, 852)
          : const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final history = FakeWorkoutHistory(),
          records = FakeWorkoutRecordRepository();
      await tester.pumpWidget(
        shell(
          WorkoutHistoryPage(
            server: historyDependencies(history, records),
            initialDate: DateTime.utc(2026, 10, 26),
            today: DateTime.utc(2026, 10, 27),
          ),
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('record-day-2026-10-26')),
        findsOneWidget,
      );
      await capture(tester, 'workout-history-$scale');
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, '중단'),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '중단'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('자동 중단'), 100);
      await tester.pumpAndSettle();
      expect(find.text('완료 통계에서 제외'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '완료'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '완료'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('바벨 스쿼트'), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text('바벨 스쿼트'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutRecordPage), findsOneWidget);
      expect(find.textContaining('총 볼륨 760kg'), findsOneWidget);
      expect(find.text('운동 기록 삭제').hitTestable(), findsOneWidget);
      await capture(tester, 'workout-record-$scale');
      await tester.scrollUntilVisible(find.text('세트 수정').first, 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text('세트 수정').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('record-weight')), '65');
      await tester.enterText(find.byKey(const Key('record-reps')), '8');
      await tester.enterText(find.byKey(const Key('record-rest')), '120');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('수정 저장'));
      await tester.pumpAndSettle();
      await capture(tester, 'workout-record-edit-$scale');
      await tester.tap(find.text('수정 저장'));
      await tester.pumpAndSettle();
      expect(records.edits.single['version'], 1);
      expect(records.edits.single['rest_sec'], 120);
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.textContaining('총 볼륨 680kg'), findsOneWidget);
      await tester.tap(find.text('운동 기록 삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(records.cancels, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('로그 삭제 확인 후 월 합계·완료 표시·목록을 갱신한다', (tester) async {
    final history = FakeWorkoutHistory(),
        records = FakeWorkoutRecordRepository();
    records.onCancel = () => history.recordsData.removeWhere((e) => e.id == 87);
    await tester.pumpWidget(
      shell(
        WorkoutHistoryPage(
          server: historyDependencies(history, records),
          initialDate: DateTime.utc(2026, 10, 26),
          today: DateTime.utc(2026, 10, 27),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.widgetWithText(ChoiceChip, '완료'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '완료'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('바벨 스쿼트'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('바벨 스쿼트'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('운동 기록 삭제'));
    await tester.pumpAndSettle();
    expect(records.cancels, 0);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(records.cancels, 1);
    expect(find.byType(WorkoutRecordPage), findsNothing);
    await tester.scrollUntilVisible(find.text('선택한 조건의 운동 기록이 없어요.'), 150);
    await tester.pumpAndSettle();
    expect(find.text('선택한 조건의 운동 기록이 없어요.'), findsOneWidget);
    expect(
      history.requests.where((e) => e.$1.day == 1 && e.$2.day == 31).length,
      2,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('세트 수정 충돌 후 버튼을 유지하고 재조회하여 다시 편집한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final records = FakeWorkoutRecordRepository()
      ..updateError = ApiRequestError(
        const ApiFailure(
          code: 'VERSION_CONFLICT',
          message: '충돌',
          status: 409,
          fields: null,
        ),
      );
    await tester.pumpWidget(
      shell(
        WorkoutRecordPage(
          dependencies: WorkoutDependencies(
            repository: records,
            drafts: MemoryWorkoutDraftStore(),
          ),
          id: 87,
        ),
        scale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('세트 수정').first, 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('세트 수정').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('수정 저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정 저장'));
    await tester.pumpAndSettle();
    expect(find.textContaining('다른 곳에서 먼저 수정했어요.'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('운동 기록 삭제')).dy, lessThan(640));
    records.updateError = null;
    await tester.tap(find.text('기록 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('다른 곳에서 먼저 수정했어요.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('홈 보기에서 서버 기록으로 이동하고 기기 기록은 별도로 보존한다', (tester) async {
    final history = FakeWorkoutHistory(),
        records = FakeWorkoutRecordRepository(),
        local = FakeHomeRepository();
    await tester.pumpWidget(
      shell(
        HomePage(
          repository: local,
          server: historyDependencies(history, records),
          today: DateTime(2026, 10, 26),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('보기'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutHistoryPage), findsOneWidget);
    await tester.scrollUntilVisible(find.text('기기에 저장된 기록 보기'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('기기에 저장된 기록 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutCalendarPage), findsOneWidget);
    expect(local.writes, 0);
    expect(local.workouts, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
