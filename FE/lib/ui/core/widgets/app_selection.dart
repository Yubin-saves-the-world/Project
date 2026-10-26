import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'design_reference_page.dart';

class AppSelectionOption<T> {
  const AppSelectionOption(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

Future<T?> showAppSelection<T>(
  BuildContext context, {
  required String title,
  required List<AppSelectionOption<T>> options,
  T? selected,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SheetHeader(title: title),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final option in options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Semantics(
                            selected: selected == option.value,
                            child: Material(
                              color: selected == option.value
                                  ? AppColors.primarySoft
                                  : AppColors.soft,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () =>
                                    Navigator.pop(context, option.value),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      if (option.icon != null) ...[
                                        Icon(
                                          option.icon,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      Expanded(
                                        child: Text(
                                          option.label,
                                          style: ReferenceStyle.text(
                                            15,
                                            23,
                                            color: selected == option.value
                                                ? AppColors.primary
                                                : AppColors.text,
                                            weight: selected == option.value
                                                ? FontWeight.w500
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        selected == option.value
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        color: selected == option.value
                                            ? AppColors.primary
                                            : AppColors.border,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
  );
}

class AppSelectionField<T> extends StatelessWidget {
  const AppSelectionField({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.placeholder = '선택',
    this.enabled = true,
  });
  final String label, placeholder;
  final List<AppSelectionOption<T>> options;
  final T? value;
  final bool enabled;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final matches = options.where((option) => option.value == value);
      final width = constraints.maxWidth;
      return MenuAnchor(
        consumeOutsideTap: true,
        alignmentOffset: const Offset(0, 8),
        style: MenuStyle(
          alignment: AlignmentDirectional.bottomStart,
          backgroundColor: const WidgetStatePropertyAll(Colors.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(3),
          shadowColor: const WidgetStatePropertyAll(Color(0x14000000)),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          minimumSize: WidgetStatePropertyAll(Size(width, 0)),
          maximumSize: WidgetStatePropertyAll(
            Size(width, MediaQuery.sizeOf(context).height * .4),
          ),
        ),
        menuChildren: [
          for (final option in options)
            MenuItemButton(
              key: ValueKey('selection-option-${option.value}'),
              onPressed: enabled ? () => onChanged(option.value) : null,
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(
                  option.value == value ? AppColors.primarySoft : Colors.white,
                ),
                foregroundColor: WidgetStatePropertyAll(
                  option.value == value ? AppColors.primary : AppColors.text,
                ),
                minimumSize: WidgetStatePropertyAll(Size(width - 12, 52)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              leadingIcon: option.icon == null
                  ? null
                  : Icon(
                      option.icon,
                      size: 19,
                      color: option.value == value
                          ? AppColors.primary
                          : AppColors.muted,
                    ),
              trailingIcon: option.value == value
                  ? const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: AppColors.primary,
                    )
                  : null,
              child: SizedBox(
                width: (width - 112).clamp(40.0, double.infinity),
                child: Text(
                  option.label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: ReferenceStyle.text(
                    14,
                    21,
                    color: option.value == value
                        ? AppColors.primary
                        : AppColors.text,
                  ),
                ),
              ),
            ),
        ],
        builder: (context, controller, _) => AppPickerField(
          label: label,
          value: matches.isEmpty ? placeholder : matches.first.label,
          icon: controller.isOpen
              ? Icons.expand_less_rounded
              : Icons.expand_more_rounded,
          onTap: !enabled
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
        ),
      );
    },
  );
}

class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.icon = Icons.expand_more_rounded,
  });
  final String label, value;
  final VoidCallback? onTap;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Material(
      color: AppColors.soft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: ReferenceStyle.text(
                        11,
                        17,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: ReferenceStyle.text(
                        15,
                        23,
                        color: onTap == null ? AppColors.muted : AppColors.text,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, size: 22, color: AppColors.muted),
            ],
          ),
        ),
      ),
    ),
  );
}

String formatWorkoutDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return hours == 0
      ? '$remaining분'
      : remaining == 0
      ? '$hours시간'
      : '$hours시간 $remaining분';
}

/// Null means dismissed.
Future<int?> showWorkoutDurationPicker(BuildContext context, {int? minutes}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DurationSheet(initialMinutes: minutes ?? 45),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: ReferenceStyle.text(20, 30, weight: FontWeight.w500),
        ),
      ),
      IconButton(
        tooltip: '닫기',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded, size: 22),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.soft,
          foregroundColor: AppColors.muted,
        ),
      ),
    ],
  );
}

class _DurationSheet extends StatefulWidget {
  const _DurationSheet({required this.initialMinutes});
  final int initialMinutes;
  @override
  State<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<_DurationSheet> {
  late int hours = widget.initialMinutes ~/ 60;
  late int minutes = widget.initialMinutes % 60;
  int revision = 0;
  int get total => hours * 60 + minutes;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader(title: '예상 소요 시간'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final unit in ['시간', '분'])
                        Expanded(
                          child: Text(
                            unit,
                            textAlign: TextAlign.center,
                            style: ReferenceStyle.text(
                              12,
                              18,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 168,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: .18),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _DurationWheel(
                                key: ValueKey('duration-hours-$revision'),
                                count: 11,
                                initial: hours,
                                unit: '시간',
                                onChanged: (value) => setState(() {
                                  hours = value;
                                  if (hours == 10) minutes = 0;
                                }),
                              ),
                            ),
                            Expanded(
                              child: _DurationWheel(
                                key: ValueKey(
                                  'duration-minutes-$revision-${hours == 10}',
                                ),
                                count: hours == 10 ? 1 : 60,
                                initial: minutes,
                                unit: '분',
                                onChanged: (value) =>
                                    setState(() => minutes = value),
                              ),
                            ),
                          ],
                        ),
                        IgnorePointer(
                          child: Text(
                            ':',
                            style: ReferenceStyle.text(
                              24,
                              36,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    MediaQuery.textScalerOf(context).scale(13) > 16 ||
                        constraints.maxWidth < 300
                    ? 2
                    : 4;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in [30, 45, 60, 90])
                      SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 8) /
                            columns,
                        child: ChoiceChip(
                          key: ValueKey('duration-preset-$preset'),
                          label: Center(
                            child: Text(formatWorkoutDuration(preset)),
                          ),
                          selected: total == preset,
                          onSelected: (_) => setState(() {
                            hours = preset ~/ 60;
                            minutes = preset % 60;
                            revision++;
                          }),
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          selectedColor: AppColors.primarySoft,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelStyle: ReferenceStyle.text(
                            12,
                            18,
                            weight: FontWeight.w500,
                            color: total == preset
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                          side: BorderSide(
                            color: total == preset
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            ReferenceButton(
              '선택 완료',
              key: const Key('duration-confirm'),
              onPressed: total > 0 ? () => Navigator.pop(context, total) : null,
            ),
          ],
        ),
      ),
    ),
  );
}

class _DurationWheel extends StatefulWidget {
  const _DurationWheel({
    super.key,
    required this.count,
    required this.initial,
    required this.unit,
    required this.onChanged,
  });
  final int count, initial;
  final String unit;
  final ValueChanged<int> onChanged;
  @override
  State<_DurationWheel> createState() => _DurationWheelState();
}

class _DurationWheelState extends State<_DurationWheel> {
  late int selected = widget.initial;
  late final controller = FixedExtentScrollController(
    initialItem: widget.initial,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.unit,
    child: CupertinoPicker.builder(
      scrollController: controller,
      itemExtent: 48,
      diameterRatio: 1.8,
      squeeze: 1.05,
      selectionOverlay: null,
      onSelectedItemChanged: (index) {
        setState(() => selected = index);
        widget.onChanged(index);
      },
      childCount: widget.count,
      itemBuilder: (_, index) => Center(
        child: Text(
          index.toString().padLeft(2, '0'),
          style: ReferenceStyle.text(
            index == selected ? 30 : 24,
            40,
            color: index == selected ? AppColors.primary : AppColors.muted,
            weight: index == selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}
