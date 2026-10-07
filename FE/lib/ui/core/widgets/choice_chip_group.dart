import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ChoiceChipGroup<T> extends StatelessWidget {
  const ChoiceChipGroup({
    super.key,
    required this.options,
    required this.value,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });
  final List<T> options;
  final T? value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = options.length > 4 ? 4 : options.length;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) {
          final selected = option == value;
          return SizedBox(
            width: width,
            child: Semantics(
              selected: selected,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  foregroundColor: selected ? Colors.white : AppColors.text,
                  backgroundColor: selected
                      ? AppColors.primary
                      : AppColors.surface,
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: enabled ? () => onChanged(option) : null,
                child: Text(
                  label(option),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}
