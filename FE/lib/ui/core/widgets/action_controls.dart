import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';
import 'design_reference_page.dart';

/// Auxiliary-screen actions share the approved community dialog button shape.
class AppActionButton extends StatelessWidget {
  const AppActionButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.secondary = false,
    this.neutral = false,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, neutral, busy;
  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      textStyle: WidgetStatePropertyAll(
        ReferenceStyle.text(14, 21, weight: FontWeight.w500),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.muted
            : neutral
            ? AppColors.text
            : secondary
            ? AppColors.primary
            : Colors.white,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.soft
            : neutral
            ? AppColors.soft
            : secondary
            ? Colors.white
            : AppColors.primary,
      ),
      side: WidgetStatePropertyAll(
        secondary && !neutral
            ? const BorderSide(color: AppColors.border)
            : BorderSide.none,
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: secondary
          ? OutlinedButton(
              style: style,
              onPressed: busy ? null : onPressed,
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(label, textAlign: TextAlign.center),
            )
          : FilledButton(
              style: style,
              onPressed: busy ? null : onPressed,
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(label, textAlign: TextAlign.center),
            ),
    );
  }
}

/// Dialog actions keep equal widths and grow together for large text.
class AppDialogActions extends StatelessWidget {
  const AppDialogActions({
    super.key,
    required this.actionLabel,
    required this.onAction,
    this.cancelLabel = '취소',
    required this.onCancel,
    this.cancelKey,
    this.actionKey,
  });
  final String actionLabel, cancelLabel;
  final VoidCallback onAction, onCancel;
  final Key? cancelKey, actionKey;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AppActionButton(
            cancelLabel,
            key: cancelKey,
            secondary: true,
            neutral: true,
            onPressed: onCancel,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppActionButton(
            actionLabel,
            key: actionKey,
            onPressed: onAction,
          ),
        ),
      ],
    ),
  );
}

class AppActionRow extends StatelessWidget {
  const AppActionRow(
    this.label, {
    super.key,
    required this.onPressed,
    this.subtitle,
    this.icon,
  });
  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                AppIcon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: ReferenceStyle.text(
                        14,
                        21,
                        weight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: ReferenceStyle.text(
                          12,
                          18,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const AppIcon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool> showAppConfirmation(
  BuildContext context,
  String title,
  String body, {
  String action = '확인',
  String cancelLabel = '취소',
  bool barrierDismissible = true,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) =>
          _ActionDialog(title, body, action: action, cancelLabel: cancelLabel),
    ) ??
    false;

Future<void> showAppNotice(BuildContext context, String title, String body) =>
    showDialog<void>(
      context: context,
      builder: (context) =>
          _ActionDialog(title, body, action: '확인', notice: true),
    );

class _ActionDialog extends StatelessWidget {
  const _ActionDialog(
    this.title,
    this.body, {
    required this.action,
    this.notice = false,
    this.cancelLabel = '취소',
  });
  final String title, body, action, cancelLabel;
  final bool notice;
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    scrollable: true,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    constraints: const BoxConstraints(maxWidth: 360),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
    contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    title: Text(
      title,
      style: ReferenceStyle.text(18, 27, weight: FontWeight.w500),
    ),
    content: Text(
      body,
      style: ReferenceStyle.text(14, 22, color: AppColors.muted),
    ),
    actions: [
      if (notice)
        AppActionButton(action, onPressed: () => Navigator.pop(context))
      else
        AppDialogActions(
          cancelLabel: cancelLabel,
          actionLabel: action,
          onCancel: () => Navigator.pop(context, false),
          onAction: () => Navigator.pop(context, true),
        ),
    ],
  );
}
