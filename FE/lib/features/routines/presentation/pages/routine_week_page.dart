import '../../../../ui/core/widgets/app_icon.dart';
import '../../../workout/presentation/workout_dependencies.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../exercises/data/exercise_repository.dart';
import '../../../exercises/data/models/exercise.dart';
import '../../../body_analysis/presentation/pages/analysis_run_page.dart'
    show AnalysisPanel;
import '../../data/models/routine.dart';
import '../../data/routine_repository.dart';
import '../routine_week_view_model.dart';
import 'routine_detail_page.dart';

class RoutineWeekPage extends StatefulWidget {
  const RoutineWeekPage({
    super.key,
    required this.repository,
    this.exercises,
    this.date,
    this.localPreview = false,
    this.onAccessRequired,
    this.workouts,
  });
  final RoutineRepository repository;
  final ExerciseRepository? exercises;
  final DateTime? date;
  final bool localPreview;
  final VoidCallback? onAccessRequired;
  final WorkoutDependencies? workouts;
  @override
  State<RoutineWeekPage> createState() => _RoutineWeekPageState();
}

class _RoutineWeekPageState extends State<RoutineWeekPage> {
  late final model = RoutineWeekViewModel(widget.repository, date: widget.date)
    ..load();
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> _open(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RoutineDetailPage(
          repository: widget.repository,
          id: id,
          workouts: widget.workouts,
          exercises: widget.exercises,
          localPreview: widget.localPreview,
          onAccessRequired: widget.onAccessRequired,
        ),
      ),
    );
    if (mounted) await model.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => ManagementPage(
      title: '추천 루틴',
      body: RefreshIndicator(
        onRefresh: model.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '이전 주',
                  onPressed: () => model.move(-1),
                  icon: const AppIcon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${routineDateKey(model.start)}\n~ ${routineDateKey(model.start.add(const Duration(days: 6)))}',
                    textAlign: TextAlign.center,
                    style: ReferenceStyle.text(15, 22, weight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  tooltip: '다음 주',
                  onPressed: () => model.move(1),
                  icon: const AppIcon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.localPreview)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  '로컬 미리보기에서는 추천 루틴을 생성하지 않아요.',
                  style: TextStyle(color: ReferenceStyle.muted),
                ),
              ),
            Text(
              '직접 만든 일정은 홈에서 확인할 수 있어요.',
              style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
            ),
            const SizedBox(height: 20),
            if (model.loading)
              const Center(child: CircularProgressIndicator())
            else if (model.error != null) ...[
              Text(model.error!),
              TextButton(onPressed: model.load, child: const Text('다시 시도')),
            ] else if (model.week case final week?) ...[
              if (week.empty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: AnalysisPanel(
                    children: [
                      Text('선택한 주에 추천된 루틴이 없어요.'),
                      Text('완료된 체형 분석 결과에서 맞춤 루틴을 만들어 주세요.'),
                    ],
                  ),
                ),
              for (final day in week.days)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: day.routine == null
                        ? null
                        : () => _open(day.routine!.id),
                    child: AnalysisPanel(
                      children: [
                        Text(
                          routineDayLabel(day.date),
                          style: ReferenceStyle.text(
                            14,
                            21,
                            color: ReferenceStyle.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (day.routine case final routine?) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  routine.title,
                                  style: ReferenceStyle.text(
                                    18,
                                    26,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const AppIcon(
                                Icons.chevron_right_rounded,
                                color: ReferenceStyle.muted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${exerciseParts[routine.part] ?? '기타 부위'} · ${routine.minutes}분 · ${routineStatusLabel(routine.status)}',
                            style: ReferenceStyle.text(
                              12,
                              18,
                              color: ReferenceStyle.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            routine.progressLabel,
                            style: ReferenceStyle.text(
                              12,
                              18,
                              color: ReferenceStyle.blue,
                            ),
                          ),
                          if (routine.validProgress &&
                              routine.itemCount > 0) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: routine.doneCount / routine.itemCount,
                            ),
                          ],
                        ] else
                          Text(
                            day.isRestDay ? '추천 루틴 없음' : '루틴 정보를 다시 확인해 주세요.',
                          ),
                      ],
                    ),
                  ),
                ),
            ],
            if (model.accessCode == 'ONBOARDING_REQUIRED' &&
                widget.onAccessRequired != null)
              TextButton(
                onPressed: widget.onAccessRequired,
                child: const Text('신체정보 확인'),
              ),
          ],
        ),
      ),
    ),
  );
}
