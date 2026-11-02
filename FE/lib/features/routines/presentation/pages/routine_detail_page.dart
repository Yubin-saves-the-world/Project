import '../../../../ui/core/theme/app_spacing.dart';
import '../../../../ui/core/widgets/action_controls.dart';
import '../../../workout/presentation/pages/workout_page.dart';
import '../../../workout/presentation/workout_dependencies.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../body_analysis/presentation/pages/analysis_run_page.dart'
    show AnalysisPanel;
import '../../../exercises/data/exercise_repository.dart';
import '../../../exercises/data/models/exercise.dart';
import '../../../exercises/presentation/pages/exercise_detail_page.dart';
import '../../data/models/routine.dart';
import '../../data/routine_repository.dart';
import '../routine_detail_view_model.dart';

class RoutineDetailPage extends StatefulWidget {
  const RoutineDetailPage({
    super.key,
    required this.repository,
    required this.id,
    this.exercises,
    this.localPreview = false,
    this.onAccessRequired,
    this.workouts,
  });
  final RoutineRepository repository;
  final int id;
  final ExerciseRepository? exercises;
  final bool localPreview;
  final VoidCallback? onAccessRequired;
  final WorkoutDependencies? workouts;
  @override
  State<RoutineDetailPage> createState() => _RoutineDetailPageState();
}

class _RoutineDetailPageState extends State<RoutineDetailPage> {
  late final model = RoutineDetailViewModel(widget.repository, widget.id)
    ..load();
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final skip = model.canSkip;
    final confirmed = await showAppConfirmation(
      context,
      skip ? '추천 루틴을 건너뛸까요?' : '추천 루틴을 되돌릴까요?',
      skip
          ? '이 날짜의 추천 루틴을 건너뛰어요. 직접 만든 일정은 유지돼요.'
          : '이 날짜의 추천 루틴을 다시 예정 상태로 바꿔요. 직접 만든 일정은 유지돼요.',
      action: skip ? '건너뛰기' : '되돌리기',
    );
    if (confirmed == true && mounted) await model.toggle();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => PopScope(
      canPop: !model.busy,
      child: ManagementPage(
        title: '루틴 상세',
        onBack: model.busy ? () {} : () => Navigator.maybePop(context),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: model.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                    vertical: AppSpacing.medium,
                  ),
                  children: [
                    if (model.loading)
                      const Center(child: CircularProgressIndicator())
                    else if (model.routine case final routine?) ...[
                      AnalysisPanel(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            routineDayLabel(routine.date),
                            style: ReferenceStyle.text(
                              12,
                              18,
                              color: ReferenceStyle.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            routine.title,
                            style: ReferenceStyle.text(
                              20,
                              28,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${exerciseParts[routine.part] ?? '기타 부위'} · ${routine.minutes}분 · ${routineStatusLabel(routine.status)}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${routine.items.where((e) => e.done).length}/${routine.items.length}종목 완료',
                            style: ReferenceStyle.text(
                              12,
                              18,
                              color: ReferenceStyle.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      if (routine.items.isEmpty) const Text('등록된 운동 종목이 없어요.'),
                      for (final item in routine.items)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: item == routine.items.last
                                ? 0
                                : AppSpacing.medium,
                          ),
                          child: AnalysisPanel(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Text(
                                '${item.order}. ${item.exercise.name}',
                                style: ReferenceStyle.text(
                                  18,
                                  26,
                                  weight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${item.sets}세트 · ${item.reps}회 · 무게 ${item.weightLabel}',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '세트 간 휴식 ${item.restSeconds}초 · ${item.done ? '완료' : '미완료'}',
                                style: ReferenceStyle.text(
                                  12,
                                  18,
                                  color: ReferenceStyle.muted,
                                ),
                              ),
                              if (item.reason != null &&
                                  item.reason!.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  item.reason!,
                                  style: ReferenceStyle.text(
                                    13,
                                    20,
                                    color: ReferenceStyle.muted,
                                  ),
                                ),
                              ],
                              if (widget.workouts != null &&
                                      !item.done &&
                                      routine.status == RoutineStatus.planned &&
                                      routineDate(routine.date) ==
                                          routineToday() ||
                                  widget.exercises != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (widget.workouts != null &&
                                        !item.done &&
                                        routine.status ==
                                            RoutineStatus.planned &&
                                        routineDate(routine.date) ==
                                            routineToday())
                                      Expanded(
                                        child: AppActionButton(
                                          '운동 시작',
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) => WorkoutPage(
                                                  dependencies:
                                                      widget.workouts!,
                                                  exerciseId: item.exercise.id,
                                                  routineId: routine.id,
                                                  targetSets: item.sets,
                                                  targetReps: item.reps,
                                                  targetWeight: item.weightKg,
                                                  restSeconds: item.restSeconds,
                                                ),
                                              ),
                                            );
                                            if (mounted) await model.load();
                                          },
                                        ),
                                      ),
                                    if (widget.workouts != null &&
                                        !item.done &&
                                        routine.status ==
                                            RoutineStatus.planned &&
                                        routineDate(routine.date) ==
                                            routineToday() &&
                                        widget.exercises != null)
                                      const SizedBox(width: 8),
                                    if (widget.exercises != null)
                                      Expanded(
                                        child: AppActionButton(
                                          '운동 정보',
                                          secondary: true,
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  ExerciseDetailPage(
                                                    repository:
                                                        widget.exercises!,
                                                    id: item.exercise.id,
                                                    localPreview:
                                                        widget.localPreview,
                                                    onAccessRequired:
                                                        widget.onAccessRequired,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (routine.status == RoutineStatus.skipped &&
                          routineDate(routine.date).isBefore(routineToday()))
                        const Text(
                          '지난 날짜의 추천 루틴은 되돌릴 수 없어요.',
                          style: TextStyle(color: ReferenceStyle.muted),
                        ),
                      if (routine.status == RoutineStatus.unknown)
                        const Text('현재 상태를 인식하지 못했어요. 다시 불러와 주세요.'),
                    ],
                  ],
                ),
              ),
            ),
            if (model.error != null ||
                model.canSkip ||
                model.canRestore ||
                model.busy)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.medium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (model.error != null) ...[
                      Text(
                        model.error!,
                        style: ReferenceStyle.text(12, 18, color: Colors.red),
                      ),
                      TextButton(
                        onPressed: model.busy ? null : model.load,
                        child: const Text('다시 확인'),
                      ),
                    ],
                    if (model.accessCode == 'ONBOARDING_REQUIRED' &&
                        widget.onAccessRequired != null)
                      TextButton(
                        onPressed: widget.onAccessRequired,
                        child: const Text('신체정보 확인'),
                      ),
                    if (model.canSkip || model.canRestore || model.busy)
                      AppActionButton(
                        model.routine?.status == RoutineStatus.planned
                            ? '이 루틴 건너뛰기'
                            : '이 루틴 되돌리기',
                        onPressed: _toggle,
                        secondary: true,
                        busy: model.busy,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
