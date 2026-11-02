import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fe/features/photos/data/models/selected_photo.dart';
import 'package:fe/features/photos/presentation/widgets/photo_input_field.dart';

void main() {
  for (final size in [(40, 80), (80, 40)]) {
    testWidgets(
      '빈 사진은 정사각형이고 등록한 ${size.$1}x${size.$2} 사진은 원본 비율이며 삭제하면 복원된다',
      (tester) async {
        final folder = Directory.systemTemp.createTempSync(
          'movid-adaptive-photo-',
        );
        addTearDown(() => folder.deleteSync(recursive: true));
        final file = File('${folder.path}/sample.png');
        file.writeAsBytesSync(
          img.encodePng(img.Image(width: size.$1, height: size.$2)),
        );
        SelectedPhoto? photo;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Center(
                    child: SizedBox(
                      width: 200,
                      child: PhotoInputField(
                        label: '정면',
                        photo: photo,
                        height: 200,
                        adaptToPhoto: true,
                        fit: BoxFit.contain,
                        onSelect: () {},
                        onRemove: () => update(() => photo = null),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        expect(
          tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(PhotoInputField),
                      matching: find.byType(Stack),
                    )
                    .first,
              )
              .height,
          198,
        );
        await tester.runAsync(
          () => precacheImage(
            FileImage(file),
            tester.element(find.byType(PhotoInputField)),
          ),
        );
        update(
          () => photo = SelectedPhoto(
            path: file.path,
            byteLength: file.lengthSync(),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        final frame = tester.getSize(
          find
              .descendant(
                of: find.byType(PhotoInputField),
                matching: find.byType(Stack),
              )
              .first,
        );
        expect(frame.width, 198);
        expect(frame.height, closeTo(frame.width * size.$2 / size.$1, .1));
        expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
        await tester.tap(find.byTooltip('정면 삭제'));
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(PhotoInputField),
                      matching: find.byType(Stack),
                    )
                    .first,
              )
              .height,
          198,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
