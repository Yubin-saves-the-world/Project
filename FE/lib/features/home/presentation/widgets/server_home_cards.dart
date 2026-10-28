import '../../../workout/presentation/pages/workout_page.dart';
import '../../../exercises/presentation/pages/exercise_list_page.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../body_analysis/presentation/pages/analysis_run_page.dart'
    show AnalysisPanel;
import '../../../routines/data/models/routine.dart';
import '../../../routines/presentation/pages/routine_detail_page.dart';
import '../home_server_view_model.dart';

class ServerRecommendationCard extends StatelessWidget {
  const ServerRecommendationCard({
    super.key,
    required this.model,
    required this.onEdit,
    required this.onChoose,
    required this.onAnalysis,
  });
  final HomeServerViewModel model;
  final VoidCallback onEdit, onChoose;
  final VoidCallback? onAnalysis;
  @override
  Widget build(BuildContext context) {
    final routine = model.recommendation;
    if (model.loading || model.dayLoading) {
      return const AnalysisPanel(
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    if (model.error != null || model.dayError != null) {
      return AnalysisPanel(
        children: [
          Text(model.error ?? model.dayError!),
          TextButton(onPressed: model.refresh, child: const Text('다시 확인')),
        ],
      );
    }
    if (routine == null) {
      return AnalysisPanel(
        children: [
          Text(
            '추천 루틴',
            style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            model.analysisCount == 0
                ? '체형을 분석하고 나에게 맞는 루틴을 받아 보세요.'
                : '선택한 날에 추천 루틴이 없어요.',
          ),
          if (onAnalysis != null)
            TextButton(
              onPressed: onAnalysis,
              child: Text(
                model.analysisCount == 0 ? '체형 분석하고 루틴 받기' : '분석 결과에서 루틴 만들기',
              ),
            ),
          TextButton(
            onPressed: model.local.canWrite && !model.busy ? onEdit : null,
            child: const Text('직접 일정 만들기'),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: ReferenceStyle.blue),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '추천 루틴',
                  style: ReferenceStyle.text(
                    12,
                    18,
                    color: ReferenceStyle.blue,
                  ),
                ),
              ),
              TextButton(
                onPressed: model.busy ? null : onEdit,
                child: const Text('직접 일정 정하기'),
              ),
            ],
          ),
          Text(
            routine.title,
            style: ReferenceStyle.text(17, 26, weight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            '${routine.minutes}분 · ${routineStatusLabel(routine.status)}',
            style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
          ),
          const SizedBox(height: 16),
          for (final item in routine.items.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.exercise.name,
                      style: ReferenceStyle.text(13, 20),
                    ),
                  ),
                  Text(
                    '${item.sets}세트 · ${item.reps}회',
                    style: ReferenceStyle.text(
                      12,
                      18,
                      color: ReferenceStyle.muted,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            '${routine.items.where((e) => e.done).length}/${routine.items.length}종목 완료',
            style: ReferenceStyle.text(12, 18, color: ReferenceStyle.blue),
          ),
          const SizedBox(height: 12),
          ReferenceButton(
            '루틴 상세 보기',
            onPressed: () => _detail(context, routine.id),
          ),
        ],
      ),
    );
  }

  Future<void> _detail(BuildContext context, int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RoutineDetailPage(
          repository: model.dependencies.routines,
          id: id,
          workouts: model.dependencies.workouts,
          exercises: model.dependencies.exercises,
          onAccessRequired: model.dependencies.onAccessRequired,
        ),
      ),
    );
    if (context.mounted) await model.refresh();
  }
}

class ServerHomeRecordCard extends StatelessWidget {
  const ServerHomeRecordCard({
    super.key,
    required this.model,
    required this.onRecords,
  });
  final HomeServerViewModel model;
  final VoidCallback onRecords;
  @override
  Widget build(BuildContext context) => AnalysisPanel(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '운동 기록',
              style: ReferenceStyle.text(14, 21, weight: FontWeight.w500),
            ),
          ),
          TextButton(onPressed: onRecords, child: const Text('보기')),
        ],
      ),
      Text(
        '${model.selected.month}월 ${model.selected.day}일 · 서버 기록',
        style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
      ),
      const SizedBox(height: 8),
      if (model.loading || model.dayLoading)
        const Text('기록을 불러오는 중이에요.')
      else if (model.dayError != null || model.error != null) ...[
        Text(model.dayError ?? model.error!),
        TextButton(onPressed: model.refresh, child: const Text('다시 확인')),
      ] else if (model.stats == null)
        const Text('기록을 다시 확인해 주세요.')
      else
        Text(
          '${model.stats!.count}개 완료 기록 · ${model.sets}세트 · 총 볼륨 ${model.volume.toStringAsFixed(0)}kg',
          style: ReferenceStyle.text(14, 21),
        ),
      if (model.dependencies.workouts != null &&
          model.dependencies.exercises != null)
        TextButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ExerciseListPage(
                  repository: model.dependencies.exercises!,
                  workouts: model.dependencies.workouts,
                  onAccessRequired: model.dependencies.onAccessRequired,
                ),
              ),
            );
            if (context.mounted) await model.refresh();
          },
          child: const Text('자유 운동 시작'),
        ),
      if (model.activeLoaded &&
          model.error == null &&
          model.active.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final active in model.active)
          TextButton(
            onPressed: model.dependencies.workouts != null
                ? () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => WorkoutPage(
                          dependencies: model.dependencies.workouts!,
                          logId: active.id,
                        ),
                      ),
                    );
                    if (context.mounted) await model.refresh();
                  }
                : () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (context) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              active.name,
                              style: ReferenceStyle.text(
                                20,
                                28,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${active.sets}세트 완료 · 총 볼륨 ${active.volume.toStringAsFixed(0)}kg',
                            ),
                            const Text('진행 중인 운동이에요.'),
                          ],
                        ),
                      ),
                    ),
                  ),
            child: Text(
              '${model.dependencies.workouts == null ? '진행 중' : '이어하기'} · ${active.name}',
            ),
          ),
      ],
    ],
  );
}
