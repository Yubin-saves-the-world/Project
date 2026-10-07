import 'package:flutter/material.dart';

import '../../../../ui/core/widgets/app_scaffold.dart';
import '../../../../ui/core/widgets/empty_view.dart';

class WorkoutHistoryPage extends StatelessWidget {
  const WorkoutHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: '운동 기록',
      body: EmptyView(
        title: '기록 화면 개발 준비',
        description: '날짜별 운동 기록과 상세 기록을 연결할 화면입니다.',
      ),
    );
  }
}
