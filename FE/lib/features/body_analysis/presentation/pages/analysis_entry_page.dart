import '../../../goal_body/presentation/pages/goal_body_page.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../analysis_dependencies.dart';
import '../analysis_input_view_model.dart';
import '../../data/models/body_analysis.dart';
import 'onboarding_analysis_page.dart';
import 'analysis_run_page.dart';
import 'analysis_history_page.dart';

class AnalysisEntryPage extends StatefulWidget {
  const AnalysisEntryPage({
    super.key,
    this.dependencies,
    this.onBack,
    this.onCompleted,
  });
  final AnalysisDependencies? dependencies;
  final VoidCallback? onBack, onCompleted;
  @override
  State<AnalysisEntryPage> createState() => _AnalysisEntryPageState();
}

class _AnalysisEntryPageState extends State<AnalysisEntryPage> {
  AnalysisInputViewModel? model;
  @override
  void initState() {
    super.initState();
    if (widget.dependencies != null) {
      model = AnalysisInputViewModel(widget.dependencies!)..initialize();
    }
  }

  @override
  void dispose() {
    model?.dispose();
    super.dispose();
  }

  bool _opening = false;
  Future<void> _open(int id) async {
    if (_opening) return;
    _opening = true;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            AnalysisRunPage(id: id, dependencies: widget.dependencies!),
      ),
    );
    _opening = false;
    if (!mounted) return;
    model!.pendingId = await widget.dependencies!.pending.read().catchError(
      (Object _) => model!.pendingId,
    );
    await model!.refreshPending();
    await model!.refreshUsage();
  }

  Future<void> _goal() async {
    final dependencies = widget.dependencies!.goals;
    if (dependencies != null) {
      final selection = await Navigator.push<GoalSelection>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GoalBodyPage(dependencies: dependencies, chooseForAnalysis: true),
        ),
      );
      if (!mounted) return;
      if (selection != null) {
        model!.selectGoal(selection.goal?.comparison);
      } else {
        await model!.refreshSelectedGoal();
      }
      return;
    }
    final goal = await model!.loadGoal();
    if (!mounted || model!.error != null) return;
    final selected = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('목표 체형 사진'),
        content: Text(
          goal == null
              ? '등록한 목표 체형이 없어요. 목표 없이도 분석할 수 있어요.'
              : goal.status != AnalysisStatus.done
              ? '목표 체형 분석이 끝난 후 비교할 수 있어요.'
              : goal.summary ?? '등록한 목표 체형과 비교할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('목표 없이 분석'),
          ),
          if (goal?.status == AnalysisStatus.done)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('이 목표 선택'),
            ),
        ],
      ),
    );
    if (mounted && selected != null) model!.selectGoal(selected ? goal : null);
  }

  @override
  Widget build(BuildContext context) {
    final model = this.model;
    if (model == null) {
      return const Scaffold(body: Center(child: Text('로그인 후 체형 분석을 이용해 주세요.')));
    }
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => OnboardingAnalysisPage(
        model: model,
        supportsText: false,
        showBack: widget.onBack != null,
        onBack: widget.onBack,
        onCompleted: () {
          final id = model.pendingId;
          if (id != null) _open(id);
        },
        onSelectGoal: _goal,
        goalTitle: widget.dependencies!.goals == null ? '목표 체형 사진' : '목표 체형',
        goalCaption: model.selectedGoal == null
            ? '사진 또는 설명으로 목표를 정해요 (선택)'
            : '목표 체형 선택됨 · 눌러서 변경하기',
        topAction: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onCompleted == null)
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AnalysisHistoryPage(
                        dependencies: widget.dependencies!,
                      ),
                    ),
                  );
                  if (mounted) await model.initialize();
                },
                child: const Text('분석 기록'),
              ),
            if (widget.onCompleted != null)
              TextButton(
                key: const Key('analysis-skip'),
                onPressed: model.busy ? null : widget.onCompleted,
                child: const Text('다음에 하기'),
              ),
          ],
        ),
        notice: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.dependencies!.localPreview)
              Text(
                '로컬 미리보기에서는 실제 체형 분석을 제공하지 않아요. 서버 연결 후 이용해 주세요.',
                style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
              ),
            if (model.usage case final usage?)
              Text(
                '오늘 남은 분석 ${usage.remaining}/${usage.limit}회',
                style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
              ),
            if (model.usage?.remaining == 0)
              Text(
                '다음 이용: ${model.usage!.resetAt.toLocal()}',
                style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
              ),
            if (model.usageError != null)
              TextButton(
                onPressed: model.refreshUsage,
                child: Text('${model.usageError} 다시 확인'),
              ),
            if (model.pendingId != null)
              TextButton(
                onPressed: () => _open(model.pendingId!),
                child: const Text('진행 중인 분석 이어서 확인'),
              ),
            if ((model.accessCode == 'CONSENT_REQUIRED' ||
                    model.accessCode == 'ONBOARDING_REQUIRED') &&
                widget.dependencies!.onAccessRequired != null)
              TextButton(
                onPressed: widget.dependencies!.onAccessRequired,
                child: const Text('동의·신체정보 확인'),
              ),
          ],
        ),
      ),
    );
  }
}
