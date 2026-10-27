import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'material_icon_paths.dart';

/// 홈 SVG의 20px 대비 약 2px 선에 맞춘 아이콘.
/// 기존 Material 윤곽(24px에서 약 2px)에 0.4px을 더해 10% 비율로 맞춘다.
class AppIcon extends Icon {
  const AppIcon(
    super.icon, {
    super.key,
    super.size,
    super.color,
    super.semanticLabel,
    super.textDirection,
    super.applyTextScaling,
  });

  @override
  Widget build(BuildContext context) {
    final path = materialIconPaths[icon?.codePoint];
    if (path == null || icon?.fontFamily != 'MaterialIcons') {
      return super.build(context);
    }
    final theme = IconTheme.of(context);
    var dimension = size ?? theme.size ?? 24;
    if (applyTextScaling ?? theme.applyTextScaling ?? false) {
      dimension = MediaQuery.textScalerOf(context).scale(dimension);
    }
    final ink = color ?? theme.color ?? Colors.black;
    final effectiveColor = ink.withValues(alpha: ink.a * (theme.opacity ?? 1));
    return Semantics(
      label: semanticLabel,
      child: Directionality(
        textDirection: textDirection ?? Directionality.of(context),
        child: SizedBox(
          width: dimension,
          height: dimension,
          child: Center(
            child: SvgPicture.string(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
              '<path d="$path" fill="black" stroke="black" stroke-width="0.4" '
              'stroke-linecap="round" stroke-linejoin="round"/></svg>',
              width: dimension,
              height: dimension,
              matchTextDirection: icon!.matchTextDirection,
              colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
