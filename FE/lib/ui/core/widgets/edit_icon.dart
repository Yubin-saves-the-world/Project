import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 커뮤니티 글쓰기와 앱 전체 수정 동작이 공유하는 아이콘.
class EditIcon extends StatelessWidget {
  const EditIcon({super.key, this.size = 17.5, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/figma/community/write.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ?? IconTheme.of(context).color ?? Colors.white,
      BlendMode.srcIn,
    ),
  );
}
