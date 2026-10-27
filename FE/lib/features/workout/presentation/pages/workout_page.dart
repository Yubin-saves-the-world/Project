import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../body_analysis/presentation/pages/analysis_run_page.dart'
    show AnalysisPanel;
import '../../data/workout_repository.dart';
import '../workout_dependencies.dart';
import '../workout_view_model.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({
    super.key,
    required this.dependencies,
    this.exerciseId,
    this.logId,
    this.routineId,
    this.targetSets,
    this.targetReps,
    this.targetWeight,
    this.restSeconds = 90,
  }) : assert(exerciseId != null || logId != null);
  final WorkoutDependencies dependencies;
  final int? exerciseId, logId, routineId, targetSets, targetReps;
  final num? targetWeight;
  final int restSeconds;
  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with WidgetsBindingObserver {
  late final model = WorkoutViewModel(
    widget.dependencies,
    exerciseId: widget.exerciseId,
    logId: widget.logId,
    routineId: widget.routineId,
    restTarget: widget.restSeconds,
    targetSets: widget.targetSets,
    targetReps: widget.targetReps,
  )..load();
  late final Timer timer;
  final weight = TextEditingController(), reps = TextEditingController();
  bool _expiryChecked = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    weight.text = widget.targetWeight?.toString() ?? '';
    reps.text = widget.targetReps?.toString() ?? '';
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (model.log?.status == 'in_progress' &&
          model.elapsed >= 21600 &&
          !_expiryChecked) {
        _expiryChecked = true;
        model.load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) model.load();
  }

  @override
  void dispose() {
    timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    model.dispose();
    weight.dispose();
    reps.dispose();
    super.dispose();
  }

  String clock(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('확인'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> finish() async {
    final empty = model.log?.sets.any((s) => s.done) != true;
    if (!await confirm(
      empty ? '기록 없이 종료할까요?' : '이 종목을 종료할까요?',
      empty ? '완료한 세트가 없어 이 진행 기록을 삭제해요.' : '완료한 세트를 저장하고 이 종목을 종료해요.',
    )) {
      return;
    }
    if (!mounted) return;
    if (await model.finish() && mounted) {
      final result = model.result;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result['set_count']}세트 · 총 볼륨 ${result['total_volume_kg']}kg 저장했어요.',
            ),
          ),
        );
      }
      Navigator.pop(context);
    }
  }

  Future<void> edit(WorkoutSet set) async {
    final values = await showModalBottomSheet<(num, int)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => _SetEditor(set: set),
    );
    if (values != null && mounted) {
      await model.update(set, values.$1, values.$2);
    }
  }

  Future<void> add() async {
    final w = num.tryParse(weight.text.trim()),
        r = int.tryParse(reps.text.trim());
    if (w == null || r == null) {
      setState(() => model.error = '무게와 횟수를 숫자로 입력해 주세요.');
      return;
    }
    FocusScope.of(context).unfocus();
    await model.add(w, r);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => PopScope(
      canPop: !model.busy && !model.loading,
      child: ManagementPage(
        title: '운동 진행',
        onBack: () =>
            model.busy || model.loading ? null : Navigator.maybePop(context),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: model.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (model.loading)
                      const Center(child: CircularProgressIndicator())
                    else if (model.log case final log?) ...[
                      Text(
                        log.name,
                        style: ReferenceStyle.text(
                          24,
                          32,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.routineId != null &&
                          widget.routineId != log.routineId)
                        const Text('이미 진행 중인 기록을 이어해요. 기존 루틴 연결을 유지해요.'),
                      Text(
                        '경과 시간 ${clock(model.elapsed)}',
                        style: ReferenceStyle.text(
                          14,
                          21,
                          color: ReferenceStyle.muted,
                        ),
                      ),
                      if (model.draft['target_sets'] != null)
                        Text(
                          '목표 ${model.draft['target_sets']}세트 · ${model.draft['target_reps']}회 · 휴식 ${model.draft['rest_target']}초',
                        ),
                      const SizedBox(height: 12),
                      Text(
                        model.closed
                            ? '종료된 운동이에요.'
                            : log.activeAt(model.now())
                            ? '나가도 운동은 유지돼요. 홈에서 이어갈 수 있어요.'
                            : '종료되었거나 6시간이 지난 운동이에요. 홈에서 새로 시작해 주세요.',
                        style: ReferenceStyle.text(
                          12,
                          18,
                          color: ReferenceStyle.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (model.restStarted != null &&
                          log.activeAt(model.now())) ...[
                        AnalysisPanel(
                          children: [
                            Text(
                              model.draft['rest_stopped'] != null
                                  ? '휴식 마침'
                                  : model.remaining == 0
                                  ? '휴식 시간이 지났어요'
                                  : '휴식 중',
                              style: ReferenceStyle.text(16, 24),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              clock(model.remaining),
                              style: ReferenceStyle.text(
                                28,
                                36,
                                color: ReferenceStyle.blue,
                              ),
                            ),
                            Text('실제 휴식 ${model.rested}초'),
                            if (model.draft['rest_stopped'] == null)
                              TextButton(
                                onPressed: model.canWrite
                                    ? model.stopRest
                                    : null,
                                child: const Text('휴식 마치기'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (log.sets.isEmpty) const Text('아직 기록한 세트가 없어요.'),
                      for (final set in log.sets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AnalysisPanel(
                            children: [
                              Text(
                                '${set.number}세트 · ${set.done ? '완료' : '미완료'}',
                                style: ReferenceStyle.text(
                                  16,
                                  24,
                                  weight: FontWeight.w500,
                                ),
                              ),
                              Text('${set.weight}kg × ${set.reps}회'),
                              if (set.rest != null)
                                Text(
                                  '이전 세트 후 휴식 ${set.rest}초',
                                  style: ReferenceStyle.text(
                                    12,
                                    18,
                                    color: ReferenceStyle.muted,
                                  ),
                                ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed:
                                        model.canWrite && model.pending == null
                                        ? () => edit(set)
                                        : null,
                                    child: const Text('수정'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        model.canWrite && model.pending == null
                                        ? () => model.update(
                                            set,
                                            set.weight,
                                            set.reps,
                                            done: !set.done,
                                          )
                                        : null,
                                    child: Text(set.done ? '완료 해제' : '완료'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        model.canWrite && model.pending == null
                                        ? () async {
                                            if (await confirm(
                                                  '세트를 삭제할까요?',
                                                  '다른 세트의 번호는 바뀌지 않아요.',
                                                ) &&
                                                mounted) {
                                              await model.deleteSet(set);
                                            }
                                          }
                                        : null,
                                    child: const Text('삭제'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (model.pending != null)
                        AnalysisPanel(
                          children: [
                            const Text(
                              '저장 확인이 필요한 세트가 있어요. 새 세트를 추가하기 전에 확인해 주세요.',
                            ),
                            Text(
                              '${model.pending!['set_no']}세트 · ${model.pending!['weight_kg']}kg × ${model.pending!['reps']}회',
                            ),
                            TextButton(
                              onPressed:
                                  model.canWrite && !model.conflictingPending
                                  ? model.retry
                                  : null,
                              child: const Text('같은 세트 다시 저장'),
                            ),
                            if (model.conflictingPending)
                              TextButton(
                                onPressed: model.canWrite
                                    ? () async {
                                        if (await confirm(
                                              '미전송 세트를 취소할까요?',
                                              '같은 번호의 다른 세트가 서버에 있어요. 서버 기록은 그대로 두고 이 미전송 입력만 취소해요.',
                                            ) &&
                                            mounted) {
                                          await model
                                              .discardConflictingPending();
                                        }
                                      }
                                    : null,
                                child: const Text('충돌한 미전송 입력 취소'),
                              ),
                          ],
                        )
                      else if (log.activeAt(model.now()) && !model.closed) ...[
                        const SizedBox(height: 12),
                        if (model.nextNumber <= 20) ...[
                          Text(
                            '${model.nextNumber}세트 기록',
                            style: ReferenceStyle.text(
                              16,
                              24,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('set-weight'),
                                  controller: weight,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  enabled: model.canWrite,
                                  decoration: const InputDecoration(
                                    labelText: '무게 (kg)',
                                    hintText: '0~500',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  key: const Key('set-reps'),
                                  controller: reps,
                                  keyboardType: TextInputType.number,
                                  enabled: model.canWrite,
                                  decoration: const InputDecoration(
                                    labelText: '횟수',
                                    hintText: '1~100',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ReferenceButton(
                            '세트 완료',
                            onPressed: model.canWrite ? add : null,
                          ),
                        ] else
                          const Text('기록할 수 있는 세트 번호는 1~20이에요.'),
                        TextButton(
                          onPressed: model.canWrite
                              ? () async {
                                  if (await confirm(
                                        '운동을 취소할까요?',
                                        '이 운동의 세트 기록도 함께 삭제돼요.',
                                      ) &&
                                      mounted &&
                                      await model.cancel() &&
                                      context.mounted) {
                                    Navigator.pop(context);
                                  }
                                }
                              : null,
                          child: const Text('운동 취소 및 기록 삭제'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            // Errors and the main action share a fixed safe-area footer.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (model.error != null) ...[
                    Text(
                      model.error!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: ReferenceStyle.text(12, 18, color: Colors.red),
                    ),
                    TextButton(
                      onPressed: model.loading || model.busy
                          ? null
                          : model.load,
                      child: const Text('서버 기록 다시 확인'),
                    ),
                  ],
                  if (model.accessCode == 'ONBOARDING_REQUIRED' &&
                      widget.dependencies.onAccessRequired != null)
                    TextButton(
                      onPressed: widget.dependencies.onAccessRequired,
                      child: const Text('신체정보 확인'),
                    ),
                  if (model.closed ||
                      model.log != null && !model.log!.activeAt(model.now()))
                    ReferenceButton(
                      '돌아가기',
                      onPressed: () => Navigator.pop(context),
                    )
                  else if (model.log != null)
                    ReferenceButton(
                      '종목 종료',
                      onPressed: model.canWrite && model.pending == null
                          ? finish
                          : null,
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

class _SetEditor extends StatefulWidget {
  const _SetEditor({required this.set});
  final WorkoutSet set;
  @override
  State<_SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends State<_SetEditor> {
  late final weight = TextEditingController(text: widget.set.weight.toString());
  late final reps = TextEditingController(text: widget.set.reps.toString());
  String? error;
  @override
  void dispose() {
    weight.dispose();
    reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.set.number}세트 수정',
            style: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '무게 (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '횟수'),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ReferenceButton(
            '변경',
            onPressed: () {
              final w = num.tryParse(weight.text), r = int.tryParse(reps.text);
              if (w == null ||
                  !w.isFinite ||
                  w < 0 ||
                  w > 500 ||
                  r == null ||
                  r < 1 ||
                  r > 100) {
                setState(() => error = '무게 0~500kg, 횟수 1~100회로 입력해 주세요.');
                return;
              }
              Navigator.pop(context, (w, r));
            },
          ),
        ],
      ),
    ),
  );
}
