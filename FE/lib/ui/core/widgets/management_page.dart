import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'design_reference_page.dart';

class ManagementPage extends StatelessWidget {
  const ManagementPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.onBack,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      centerTitle: true,
      title: Text(
        title,
        style: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
      ),
      leading: IconButton(
        tooltip: '뒤로가기',
        onPressed: onBack ?? () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      actions: actions,
    ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: body,
        ),
      ),
    ),
  );
}
