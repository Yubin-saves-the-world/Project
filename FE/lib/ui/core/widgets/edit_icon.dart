import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 기존 글쓰기 SVG의 형태·크기를 유지한다. 작은 슬롯에서도 홈 아이콘과
/// 같은 실제 2px 선이 되도록 SVG 좌표계의 굵기만 보정한다.
class EditIcon extends StatelessWidget {
  const EditIcon({super.key, this.size = 17.5, this.color}) : assert(size > 0);
  final double size;
  final Color? color;
  static const _path =
      'M10.75 2.75L0.75 12.75V16.75H4.75L14.75 6.75M10.75 2.75L12.75 0.75L16.75 4.75L14.75 6.75M10.75 2.75L14.75 6.75';

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-0.25 -0.25 18 18" fill="none">'
    '<path d="$_path" stroke="black" stroke-width="${2 * 18 / size}" '
    'stroke-linecap="round" stroke-linejoin="round"/></svg>',
    width: size,
    height: size,
    clipBehavior: Clip.none,
    colorFilter: ColorFilter.mode(
      color ?? IconTheme.of(context).color ?? Colors.white,
      BlendMode.srcIn,
    ),
  );
}
