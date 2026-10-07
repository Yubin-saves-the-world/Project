import 'package:flutter/material.dart';

import '../../../ui/core/theme/app_colors.dart';
import '../../../ui/core/theme/app_typography.dart';
import '../../../ui/core/widgets/primary_button.dart';

class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    required this.onNext,
    required this.onBack,
    this.nextLabel = '다음',
    this.busy = false,
    this.error,
    this.footer,
    this.secondaryAction,
  });
  final int step;
  final String title, nextLabel;
  final Widget child;
  final VoidCallback? onNext, onBack;
  final bool busy;
  final String? error;
  final Widget? footer, secondaryAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        tooltip: '이전 단계',
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: busy ? null : onBack,
                        icon: const Icon(
                          Icons.chevron_left,
                          size: 20,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'STEP 0${step + 1} / 03',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.muted,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Semantics(
                  label: '가입 ${step + 1}단계, 전체 3단계',
                  child: Row(
                    children: List.generate(
                      3,
                      (index) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: index < 2 ? 6 : 0),
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: index <= step
                                  ? AppColors.primary
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.title),
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  children: [
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    PrimaryButton(
                      label: nextLabel,
                      onPressed: onNext,
                      loading: busy,
                    ),
                    ?secondaryAction,
                    if (footer != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: footer!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
