import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../ui/core/widgets/design_reference_page.dart';
import '../data/community_models.dart';

const communityBackground = Color(0xFFFAFAF8);
const communityCard = Color(0xFFF1EFE8);

Widget communityText(
  String value, {
  double size = 14,
  Color? color,
  bool medium = false,
  int? lines,
}) => Text(
  value,
  maxLines: lines,
  overflow: lines == null ? null : TextOverflow.ellipsis,
  style: ReferenceStyle.text(
    size,
    size * 1.55,
    color: color ?? ReferenceStyle.ink,
    weight: medium ? FontWeight.w500 : FontWeight.w400,
  ),
);

class CommunityAsset extends StatelessWidget {
  const CommunityAsset(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => switch (name) {
    'search' => SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        children: [
          Positioned(
            left: 1.3,
            top: 1.3,
            child: SvgPicture.asset(
              'assets/icons/figma/community/search-ring.svg',
              width: 11.25,
              height: 11.25,
            ),
          ),
          Positioned(
            left: 11,
            top: 11,
            child: SvgPicture.asset(
              'assets/icons/figma/community/search-handle.svg',
              width: 5.42,
              height: 5.42,
            ),
          ),
        ],
      ),
    ),
    'heart' => SvgPicture.asset(
      'assets/icons/figma/community/heart.svg',
      width: 10.62,
      height: 8.84,
    ),
    'comment' => SvgPicture.asset(
      'assets/icons/figma/community/comment.svg',
      width: 9.76,
      height: 9.49,
    ),
    _ => SvgPicture.asset(
      'assets/icons/figma/community/write.svg',
      width: 17.5,
      height: 17.5,
    ),
  };
}

class CommunityNotice extends StatelessWidget {
  const CommunityNotice(this.message, {super.key, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        communityText(message, color: ReferenceStyle.muted, size: 13),
        if (retry != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: retry, child: const Text('다시 확인')),
          ),
      ],
    ),
  );
}

class CommunityPhoto extends StatelessWidget {
  const CommunityPhoto(this.image, {super.key, this.height = 180});
  final CommunityImage image;
  final double height;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(image.url);
    final valid =
        uri != null &&
        ['https', 'http'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
    final fallback = ColoredBox(
      color: communityCard,
      child: Center(
        child: communityText(
          '사진을 표시할 수 없어요.',
          size: 12,
          color: ReferenceStyle.muted,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: image.bytes != null
            ? Image.memory(
                image.bytes!,
                cacheWidth: 1040,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : valid
            ? Image.network(
                image.url,
                cacheWidth: 1040,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}

String communityDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

Future<bool> communityConfirm(
  BuildContext context,
  String title,
  String body, {
  String action = '확인',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: communityText(title, size: 19, medium: true),
        content: communityText(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
