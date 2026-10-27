import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../body_analysis/presentation/pages/analysis_run_page.dart'
    show AnalysisPanel;
import '../workout_dependencies.dart';
import '../workout_summary_view_model.dart';
import '../../data/workout_completion.dart';
import '../../data/workout_repository.dart';
import 'workout_page.dart';

class WorkoutSummaryPage extends StatefulWidget {
  const WorkoutSummaryPage({
    super.key,
    required this.dependencies,
    required this.log,
    required this.result,
  });
  final WorkoutDependencies dependencies;
  final WorkoutLog log;
  final WorkoutCompletion result;
  @override
  State<WorkoutSummaryPage> createState() => _WorkoutSummaryPageState();
}

class _WorkoutSummaryPageState extends State<WorkoutSummaryPage> {
  late final model = WorkoutSummaryViewModel(
    widget.dependencies,
    widget.log,
    widget.result,
  )..load();
  bool _opening = false;
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  void home() {
    if (widget.dependencies.onHome case final callback?) {
      callback();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> next() async {
    if (_opening || model.loading) return;
    setState(() => _opening = true);
    final item = await model.next();
    if (!mounted) return;
    if (item == null) {
      setState(() => _opening = false);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WorkoutPage(
          dependencies: widget.dependencies,
          exerciseId: item.exercise.id,
          routineId: widget.log.routineId,
          targetSets: item.sets,
          targetReps: item.reps,
          targetWeight: item.weightKg,
          restSeconds: item.restSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => ManagementPage(
      title: model.routineDone
          ? (model.completedToday ? '오늘 루틴 완료' : '루틴 완료')
          : '운동 완료',
      onBack: _opening ? () {} : home,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  model.routineDone
                      ? Icons.emoji_events_outlined
                      : Icons.check_circle_outline_rounded,
                  size: 48,
                  color: ReferenceStyle.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  model.routineDone
                      ? (model.completedToday
                            ? '오늘의 루틴을 모두 마쳤어요'
                            : '루틴을 모두 마쳤어요')
                      : '${widget.log.name} 완료',
                  style: ReferenceStyle.text(24, 32, weight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  '수고했어요. 운동 기록이 저장되었어요.',
                  style: TextStyle(color: ReferenceStyle.muted),
                ),
                const SizedBox(height: 24),
                AnalysisPanel(
                  children: [
                    _metric(
                      '운동 시간',
                      '${widget.result.seconds ~/ 60}분 ${widget.result.seconds % 60}초',
                    ),
                    const SizedBox(height: 16),
                    _metric(
                      '총 볼륨',
                      '${widget.result.volume.toStringAsFixed(widget.result.volume % 1 == 0 ? 0 : 1)}kg',
                    ),
                    const SizedBox(height: 16),
                    _metric('완료 세트', '${widget.result.sets}세트'),
                    if (model.progress != null) ...[
                      const SizedBox(height: 16),
                      _metric('루틴 진행', model.progress!),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                if (widget.result.memo?.trim().isNotEmpty == true)
                  AnalysisPanel(
                    children: [
                      Text(
                        '운동 메모',
                        style: ReferenceStyle.text(
                          16,
                          24,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.result.memo!),
                    ],
                  ),
                if (model.loading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (model.nextItem case final item?)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: AnalysisPanel(
                      children: [
                        Text(
                          '다음 운동',
                          style: ReferenceStyle.text(
                            12,
                            18,
                            color: ReferenceStyle.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.exercise.name,
                          style: ReferenceStyle.text(
                            18,
                            26,
                            weight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${item.sets}세트 · ${item.reps}회 · 휴식 ${item.restSeconds}초',
                        ),
                      ],
                    ),
                  ),
                if (widget.log.routineId != null &&
                    !model.loading &&
                    model.nextItem == null &&
                    model.error == null &&
                    !model.routineDone)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('지금 이어서 시작할 추천 종목이 없어요. 홈에서 일정을 확인해 주세요.'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (model.error != null) ...[
                  Text(
                    model.error!,
                    style: ReferenceStyle.text(12, 18, color: Colors.red),
                  ),
                  TextButton(
                    onPressed: model.loading || _opening ? null : model.load,
                    child: const Text('루틴 다시 확인'),
                  ),
                ],
                if (model.nextItem != null && !model.loading) ...[
                  ReferenceButton(
                    '다음 종목',
                    onPressed: _opening ? null : next,
                    busy: _opening,
                  ),
                  const SizedBox(height: 10),
                ],
                ReferenceButton('홈으로', onPressed: _opening ? null : home),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _metric(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: ReferenceStyle.text(14, 21, color: ReferenceStyle.muted),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
        ),
      ),
    ],
  );
}
