import '../../../ui/core/theme/app_colors.dart';
import '../../../ui/core/widgets/app_icon.dart';
import '../../../ui/core/widgets/edit_icon.dart';
import '../../profile/presentation/widgets/account_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../ui/core/widgets/design_reference_page.dart';
import '../data/community_models.dart';

const communityBackground = AppColors.background;
const communityCard = AppColors.soft;
const communityBorder = AppColors.border;

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
    'comment' => const CommunityCommentIcon(size: 9.76),
    _ => const EditIcon(color: Colors.white),
  };
}

/// 목록과 상세의 댓글 표시는 동일한 말풍선 원본을 사용한다.
class CommunityCommentIcon extends StatelessWidget {
  const CommunityCommentIcon({super.key, this.size = 16});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Center(
      child: SvgPicture.asset(
        'assets/icons/figma/community/comment.svg',
        width: size,
        height: size * 9.49 / 9.76,
        colorFilter: const ColorFilter.mode(
          ReferenceStyle.muted,
          BlendMode.srcIn,
        ),
      ),
    ),
  );
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
  const CommunityPhoto(
    this.image, {
    super.key,
    this.height = 180,
    this.fit = BoxFit.contain,
  });
  final CommunityImage image;
  final double? height;
  final BoxFit fit;
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
        child: ColoredBox(
          color: communityBorder,
          child: image.bytes != null
              ? Image.memory(
                  image.bytes!,
                  cacheWidth: 1040,
                  fit: fit,
                  errorBuilder: (_, _, _) => fallback,
                )
              : valid
              ? Image.network(
                  image.url,
                  cacheWidth: 1040,
                  fit: fit,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
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
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 360),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        surfaceTintColor: Colors.transparent,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: communityText(title, size: 18, medium: true),
        content: communityText(body, color: ReferenceStyle.muted),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('community-confirm-cancel'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    backgroundColor: communityCard,
                    foregroundColor: ReferenceStyle.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: ReferenceStyle.text(
                      14,
                      21,
                      weight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('community-confirm-action'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    backgroundColor: ['차단', '버리기'].contains(action)
                        ? AppColors.error
                        : ReferenceStyle.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: ReferenceStyle.text(
                      14,
                      21,
                      weight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(action),
                ),
              ),
            ],
          ),
        ],
      ),
    ) ??
    false;

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar(this.name, {super.key, this.size = 36, this.owner});
  final String name;
  final String? owner;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = _placeholder();
    return owner == null
        ? fallback
        : AccountAvatar(owner: owner!, size: size, fallback: fallback);
  }

  Widget _placeholder() => ExcludeSemantics(child: ProfilePortrait(size: size));
}

class CommunityReaction extends StatelessWidget {
  const CommunityReaction({
    super.key,
    required this.liked,
    required this.count,
    required this.onPressed,
    this.busy = false,
  });
  final bool liked, busy;
  final int count;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: liked,
    label: '좋아요 $count개',
    child: IconButton(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      tooltip: liked ? '좋아요 취소' : '좋아요',
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : AppIcon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 20,
              color: liked ? ReferenceStyle.blue : ReferenceStyle.muted,
            ),
    ),
  );
}

class CommunityMenuOption {
  const CommunityMenuOption(
    this.value,
    this.label,
    this.icon, {
    this.destructive = false,
  });
  final String value, label;
  const CommunityMenuOption.edit()
    : value = 'edit',
      label = '수정',
      icon = null,
      destructive = false;
  final IconData? icon;
  final bool destructive;
}

Future<String?> showCommunityMenu(
  BuildContext context,
  String title,
  List<CommunityMenuOption> options,
) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  builder: (context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              communityText(title, size: 16, medium: true),
              const SizedBox(height: 16),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton(
                    key: ValueKey('community-menu-${option.value}'),
                    style: TextButton.styleFrom(
                      foregroundColor: option.destructive
                          ? ReferenceStyle.blue
                          : ReferenceStyle.ink,
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: communityBorder),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, option.value),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 20,
                          child: Center(
                            child: option.icon == null
                                ? const EditIcon(
                                    size: 16,
                                    color: ReferenceStyle.muted,
                                  )
                                : AppIcon(
                                    option.icon,
                                    size: 20,
                                    color: option.destructive
                                        ? ReferenceStyle.blue
                                        : ReferenceStyle.muted,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: communityText(
                            option.label,
                            size: 14,
                            color: option.destructive
                                ? ReferenceStyle.blue
                                : ReferenceStyle.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
);
