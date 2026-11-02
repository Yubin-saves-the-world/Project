import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fe/ui/core/widgets/design_reference_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/body_analysis/presentation/pages/analysis_entry_page.dart';
import 'package:fe/features/body_analysis/presentation/analysis_dependencies.dart';
import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/photos/presentation/widgets/photo_input_field.dart';
import 'package:fe/ui/core/widgets/edit_icon.dart';
import 'package:fe/ui/core/theme/app_theme.dart';
import '../../fakes/fake_analysis_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';

void main() {
  testWidgets('분석 사진은 별도 페이지에서 빈 사진은 정사각형이며 글 선택 시 펜은 흰색이다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AnalysisEntryPage(
          dependencies: AnalysisDependencies(
            repository: FakeAnalysisRepository(),
            photos: FakePhotoRepository(),
            picker: FakePhotoPicker(),
            pending: MemoryAnalysisPendingStore(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('analysis-photo-method')));
    await tester.pumpAndSettle();
    expect(find.text('분석할 사진'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    final field = tester.widget<PhotoInputField>(
      find.byKey(const Key('front-photo')),
    );
    expect(field.height, closeTo(393 - 48, 1));
    expect(field.fit, BoxFit.contain);
    expect(field.adaptToPhoto, isTrue);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('analysis-text-method')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('analysis-text')),
      '어깨와 등 자세가 신경 쓰여요.',
    );
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(tester.widget<EditIcon>(find.byType(EditIcon)).color, Colors.white);
    final camera = find.descendant(
      of: find.byKey(const Key('analysis-photo-method')),
      matching: find.byType(SvgPicture),
    );
    expect(
      tester.widget<SvgPicture>(camera).colorFilter,
      const ColorFilter.mode(ReferenceStyle.muted, BlendMode.srcIn),
    );
    expect(find.text('몸 상태 입력됨 · 눌러서 수정하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
