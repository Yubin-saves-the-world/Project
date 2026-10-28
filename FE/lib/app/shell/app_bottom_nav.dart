import '../../ui/core/theme/app_colors.dart';
import '../../ui/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../ui/core/widgets/design_reference_page.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  static const items = [
    (Icons.home_outlined, '홈'),
    (Icons.center_focus_strong_outlined, '분석'),
    (Icons.fitness_center_outlined, '기록'),
    (Icons.chat_bubble_outline_rounded, '인공지능 코치'),
    (Icons.people_outline_rounded, '커뮤니티'),
  ];
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 84,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  selected: selectedIndex == i,
                  button: true,
                  child: InkWell(
                    key: ValueKey('nav-${items[i].$2}'),
                    onTap: () => onDestinationSelected(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (i == 0)
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/home.svg',
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  selectedIndex == i
                                      ? ReferenceStyle.blue
                                      : ReferenceStyle.muted,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          )
                        else
                          AppIcon(
                            items[i].$1,
                            size: 22,
                            color: selectedIndex == i
                                ? ReferenceStyle.blue
                                : ReferenceStyle.muted,
                          ),
                        const SizedBox(height: 5),
                        Text(
                          items[i].$2,
                          textAlign: TextAlign.center,
                          style: ReferenceStyle.text(
                            10,
                            16,
                            color: selectedIndex == i
                                ? ReferenceStyle.blue
                                : ReferenceStyle.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
