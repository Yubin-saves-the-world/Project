import 'package:flutter/material.dart';

import '../../../../ui/core/widgets/app_scaffold.dart';
import '../../../../ui/core/widgets/empty_view.dart';

class WorkoutHistoryPage extends StatelessWidget {
  const WorkoutHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: '운동 기록',
      body: EmptyView(title: '운동 기록 준비 중', description: '곧 만나요.'),
    );
  }
}
