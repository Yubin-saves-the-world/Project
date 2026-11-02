import 'package:flutter/material.dart';
import '../data/community_models.dart';
import 'community_widgets.dart';

class CommunityImageGallery extends StatelessWidget {
  const CommunityImageGallery({super.key, required this.images});
  final List<CommunityImage> images;
  Widget _tile(
    BuildContext context,
    int index, {
    double? height,
    BoxFit fit = BoxFit.cover,
  }) => Semantics(
    button: true,
    label: '사진 ${index + 1} 크게 보기',
    child: GestureDetector(
      key: ValueKey('community-image-$index'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              CommunityImageViewer(images: images, initialIndex: index),
        ),
      ),
      child: CommunityPhoto(images[index], height: height, fit: fit),
    ),
  );
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (images.length == 1) {
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 420),
              child: _tile(context, 0, fit: BoxFit.contain),
            );
          }
          final height = constraints.maxWidth * .85;
          if (images.length == 2) {
            return SizedBox(
              height: height,
              child: Row(
                children: [
                  Expanded(child: _tile(context, 0, height: height)),
                  const SizedBox(width: 4),
                  Expanded(child: _tile(context, 1, height: height)),
                ],
              ),
            );
          }
          if (images.length == 3) {
            return SizedBox(
              height: height,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _tile(context, 0, height: (height - 4) / 2),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: _tile(context, 1, height: (height - 4) / 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: _tile(context, 2, height: height)),
                ],
              ),
            );
          }
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < images.length; i++)
                SizedBox(
                  width: (constraints.maxWidth - 4) / 2,
                  child: _tile(
                    context,
                    i,
                    height: (constraints.maxWidth - 4) / 2,
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class CommunityImageViewer extends StatefulWidget {
  const CommunityImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });
  final List<CommunityImage> images;
  final int initialIndex;
  @override
  State<CommunityImageViewer> createState() => _CommunityImageViewerState();
}

class _CommunityImageViewerState extends State<CommunityImageViewer> {
  late final controller = PageController(initialPage: widget.initialIndex);
  late int index = widget.initialIndex;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _image(CommunityImage image) {
    const error = Center(
      child: Text('사진을 불러오지 못했어요.', style: TextStyle(color: Colors.white)),
    );
    if (image.bytes != null) {
      return Image.memory(
        image.bytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => error,
      );
    }
    final uri = Uri.tryParse(image.url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return error;
    }
    return Image.network(
      image.url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => error,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${index + 1} / ${widget.images.length}'),
      centerTitle: true,
    ),
    body: SafeArea(
      child: PageView.builder(
        controller: controller,
        itemCount: widget.images.length,
        onPageChanged: (value) => setState(() => index = value),
        itemBuilder: (context, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(child: _image(widget.images[i])),
        ),
      ),
    ),
  );
}
