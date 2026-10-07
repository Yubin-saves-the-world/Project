import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
