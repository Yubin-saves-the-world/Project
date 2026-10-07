import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static const title = TextStyle(
    fontSize: 26,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const brand = TextStyle(
    fontSize: 28,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -.8,
    color: AppColors.text,
  );
  static const label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: .8,
    color: AppColors.muted,
  );
  static const input = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.text,
  );
  static const button = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
  static const caption = TextStyle(
    fontSize: 11,
    height: 1.6,
    color: AppColors.muted,
  );
  static const section = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );
}
