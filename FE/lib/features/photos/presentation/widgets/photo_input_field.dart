import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../ui/core/theme/app_colors.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../data/models/selected_photo.dart';

class PhotoInputField extends StatelessWidget {
  const PhotoInputField({
    super.key,
    required this.label,
    required this.photo,
    required this.onSelect,
    required this.onRemove,
    this.requiredPhoto = false,
    this.enabled = true,
  });
  final String label;
  final SelectedPhoto? photo;
  final VoidCallback onSelect, onRemove;
  final bool requiredPhoto, enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label ${requiredPhoto ? '(필수)' : '(선택)'}',
        style: ReferenceStyle.text(12, 18, color: AppColors.muted),
      ),
      const SizedBox(height: 8),
      Container(
        height: 116,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: photo == null ? AppColors.border : AppColors.primary,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: enabled ? onSelect : null,
                  child: photo == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 24,
                              color: enabled
                                  ? AppColors.primary
                                  : AppColors.muted,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '사진 추가',
                              style: ReferenceStyle.text(
                                14,
                                21,
                                color: enabled
                                    ? AppColors.text
                                    : AppColors.muted,
                              ),
                            ),
                          ],
                        )
                      : Image.file(
                          File(photo!.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) => const Center(
                            child: Text(
                              '사진을 다시 선택해 주세요.',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (photo != null)
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  tooltip: '$label 삭제',
                  onPressed: enabled ? onRemove : null,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surface,
                  ),
                  icon: const Icon(Icons.close, size: 16),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
