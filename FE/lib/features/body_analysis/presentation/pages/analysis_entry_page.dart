import 'package:flutter/material.dart';

import '../../../../ui/core/widgets/app_scaffold.dart';
import '../../../../ui/core/widgets/empty_view.dart';

class AnalysisEntryPage extends StatelessWidget {
  const AnalysisEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: '체형 분석',
      body: EmptyView(title: '체형 분석 준비 중', description: '곧 만나요.'),
    );
  }
}
