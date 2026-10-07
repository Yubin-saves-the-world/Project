import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.validator,
    this.onChanged,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.autofillHints,
    this.onSubmitted,
    this.focusColor = AppColors.primary,
  });
  final String label, hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool obscureText, enabled;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final int? maxLength;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Color focusColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.label),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        validator: validator,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        obscureText: obscureText,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLength: maxLength,
        maxLines: maxLines,
        autofillHints: autofillHints,
        autocorrect: !obscureText && keyboardType != TextInputType.emailAddress,
        enableSuggestions: !obscureText,
        style: AppTypography.input,
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppColors.surface,
          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: focusColor, width: 1.5),
          ),
          errorMaxLines: 2,
        ),
      ),
    ],
  );
}
