import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fe/features/community/data/community_models.dart';
import 'package:fe/features/community/presentation/community_image_gallery.dart';
import 'package:fe/features/community/presentation/community_widgets.dart';
import 'package:fe/ui/core/theme/app_theme.dart';

void main() {
  for (final count in [1, 2, 3, 4, 5]) {
    testWidgets('$count장 사진은 왼쪽 묶음에서 눌러 원본 확대와 좌우 이동이 가능하다', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 48, height: 64)),
      );
      final images = List.generate(
        count,
        (i) => CommunityImage(i + 1, '', bytes: bytes),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CommunityImageGallery(images: images),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(CommunityPhoto).first).dx, 16);
      expect(
        tester.getSize(find.byType(CommunityImageGallery)).width,
        lessThanOrEqualTo(361),
      );
      await tester.tap(find.byKey(ValueKey('community-image-${count - 1}')));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityImageViewer), findsOneWidget);
      expect(find.text('$count / $count'), findsOneWidget);
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
            .maxScale,
        5,
      );
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        expect(image.fit, BoxFit.contain);
      }
      if (count > 1) {
        await tester.drag(find.byType(PageView), const Offset(350, 0));
        await tester.pumpAndSettle();
        expect(find.text('${count - 1} / $count'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
