import 'package:flutter/material.dart';

import '../../../../ui/core/widgets/app_scaffold.dart';
import '../../../../ui/core/widgets/empty_view.dart';

class AnalysisEntryPage extends StatelessWidget {
  const AnalysisEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: '체형 분석',
      body: EmptyView(
        title: '분석 화면 개발 준비',
        description: '사진 입력과 분석 진행·결과를 연결할 화면입니다.',
      ),
    );
  }
}
