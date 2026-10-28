import '../theme/app_colors.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class ReferenceStyle {
  static const blue = AppColors.primary;
  static const ink = AppColors.text;
  static const muted = AppColors.muted;
  static const border = AppColors.border;
  static const signupBorder = AppColors.border;
  static TextStyle text(
    double size,
    double line, {
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double spacing = 0,
  }) => TextStyle(
    inherit: false,
    textBaseline: TextBaseline.alphabetic,
    fontFamily: weight == FontWeight.w500 ? 'CapstoneUIMedium' : 'CapstoneUI',
    fontSize: size,
    height: line / size,
    fontWeight: FontWeight.w400,
    color: color,
    letterSpacing: spacing,
  );
}

class ReferencePage extends StatelessWidget {
  const ReferencePage({
    super.key,
    required this.builder,
    this.backAsset,
    this.onBack,
    this.footer,
    this.alignment = Alignment.center,
    this.scrollFooter = false,
  });
  final Widget Function(BuildContext, double, double) builder;
  final String? backAsset;
  final VoidCallback? onBack;
  final Widget? footer;
  final AlignmentGeometry alignment;
  final bool scrollFooter;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: LayoutBuilder(
      builder: (context, c) {
        final width = math.min(c.maxWidth, 520.0);
        if (scrollFooter) {
          final safe = MediaQuery.paddingOf(context);
          // 충분한 높이에서는 아래에 배치하고, 짧은 화면에서는 버튼까지 함께 스크롤한다.
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: CustomScrollView(
                key: const Key('reference-content-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: safe.top,
                      bottom: safe.bottom,
                    ),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              builder(
                                context,
                                width,
                                c.maxHeight - safe.vertical,
                              ),
                              if (backAsset != null)
                                Positioned(
                                  left: 12,
                                  top: 8,
                                  child: Semantics(
                                    button: true,
                                    label: '이전 단계',
                                    child: InkWell(
                                      key: const Key('reference-back'),
                                      onTap: onBack,
                                      child: SizedBox(
                                        width: 46,
                                        height: 46,
                                        child: Center(
                                          child: SvgPicture.asset(
                                            'assets/icons/figma/$backAsset',
                                            width: 30,
                                            height: 30,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          if (footer != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: footer!,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final top = math.max(0.0, MediaQuery.paddingOf(context).top - 44);
        final scroll = SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: EdgeInsets.only(
              top: top,
              bottom: footer == null
                  ? math.max(0.0, MediaQuery.paddingOf(context).bottom - 24)
                  : 0,
            ),
            child: Stack(
              children: [
                builder(context, width, math.max(852.0, c.maxHeight - top)),
                if (backAsset != null)
                  Positioned(
                    left: 12,
                    top: 40,
                    child: Semantics(
                      button: true,
                      label: '이전 단계',
                      child: InkWell(
                        key: const Key('reference-back'),
                        onTap: onBack,
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/figma/$backAsset',
                              width: 30,
                              height: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        return Align(
          alignment: alignment,
          child: SizedBox(
            width: width,
            child: footer == null
                ? scroll
                : Column(
                    children: [
                      Expanded(child: scroll),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          math.max(40.0, MediaQuery.paddingOf(context).bottom),
                        ),
                        child: footer!,
                      ),
                    ],
                  ),
          ),
        );
      },
    ),
  );
}

class ReferenceTitle extends StatelessWidget {
  const ReferenceTitle(
    this.text, {
    super.key,
    required this.sourceX,
    required this.sourceWidth,
  });
  final String text;
  final double sourceX, sourceWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Padding(
      padding: EdgeInsets.only(left: sourceX + (c.maxWidth - 393) / 2),
      child: Text(
        text,
        style: ReferenceStyle.text(
          30,
          39,
          weight: FontWeight.w500,
          spacing: -.7,
        ),
      ),
    ),
  );
}

class ReferenceButton extends StatelessWidget {
  const ReferenceButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: ReferenceStyle.blue,
        disabledBackgroundColor: ReferenceStyle.blue.withValues(alpha: .4),
        foregroundColor: Colors.white,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              label,
              style: ReferenceStyle.text(
                15,
                23,
                weight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
    ),
  );
}

class ReferenceField extends StatelessWidget {
  const ReferenceField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.obscure = false,
    this.enabled = true,
    this.suffix,
    this.labelTrailing,
    this.action = TextInputAction.next,
    this.onSubmitted,
    this.signup = false,
    this.autofillHints,
    this.errorText,
    this.inputFormatters,
  });
  final String label, hint;
  final String? errorText;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged, onSubmitted;
  final TextInputType? keyboardType;
  final bool obscure, enabled, signup;
  final Widget? suffix, labelTrailing;
  final TextInputAction action;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              label,
              style: ReferenceStyle.text(
                15,
                17,
                weight: FontWeight.w500,
                color: AppColors.text,
                spacing: 1,
              ),
            ),
          ),
          if (labelTrailing != null)
            Positioned(right: 13, top: -2, child: labelTrailing!),
        ],
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        validator: validator,
        forceErrorText: errorText,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        keyboardType: keyboardType,
        obscureText: obscure,
        enabled: enabled,
        textInputAction: action,
        autofillHints: autofillHints,
        inputFormatters: inputFormatters,
        autocorrect: !obscure && keyboardType != TextInputType.emailAddress,
        enableSuggestions: !obscure,
        style: ReferenceStyle.text(14, 21),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: ReferenceStyle.text(14, 21, color: ReferenceStyle.muted),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16.5,
          ),
          isDense: true,
          errorMaxLines: 2,
          errorStyle: ReferenceStyle.text(11, 17, color: Colors.red),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: signup
                  ? ReferenceStyle.signupBorder
                  : ReferenceStyle.border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: signup
                  ? ReferenceStyle.signupBorder
                  : ReferenceStyle.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: ReferenceStyle.blue),
          ),
        ),
      ),
    ],
  );
}

class ReferenceDivider extends StatelessWidget {
  const ReferenceDivider({super.key, this.signup = false});
  final bool signup;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 15,
    child: Row(
      children: [
        SizedBox(width: signup ? 0 : 3),
        Expanded(
          child: Container(
            height: 1,
            color: signup ? ReferenceStyle.signupBorder : ReferenceStyle.border,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: ReferenceStyle.text(10, 15, color: ReferenceStyle.muted),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: signup ? ReferenceStyle.signupBorder : ReferenceStyle.border,
          ),
        ),
        SizedBox(width: signup ? 7 : 3),
      ],
    ),
  );
}
