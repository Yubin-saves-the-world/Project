import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../body_analysis/presentation/pages/analysis_run_page.dart'
    show AnalysisPanel;
import '../../data/workout_repository.dart';
import '../workout_dependencies.dart';
import '../workout_record_view_model.dart';
import 'workout_page.dart';

String workoutStatusLabel(String status) => switch (status) {
  'completed' => '완료',
  'in_progress' => '진행 중',
  'aborted' => '자동 중단',
  _ => '상태 확인 필요',
};

class WorkoutRecordPage extends StatefulWidget {
  const WorkoutRecordPage({
    super.key,
    required this.dependencies,
    required this.id,
  });
  final WorkoutDependencies dependencies;
  final int id;
  @override
  State<WorkoutRecordPage> createState() => _WorkoutRecordPageState();
}

class _WorkoutRecordPageState extends State<WorkoutRecordPage>
    with WidgetsBindingObserver {
  late final model = WorkoutRecordViewModel(widget.dependencies, widget.id)
    ..load();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) model.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.dispose();
    super.dispose();
  }

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
              child: const Text('삭제'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> edit(WorkoutSet set) async {
    final body = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RecordSetEditor(set: set),
    );
    if (body != null && mounted) await model.update(set, body);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => PopScope(
      canPop: !model.busy,
      child: ManagementPage(
        title: '운동 기록 상세',
        onBack: model.busy ? () {} : () => Navigator.maybePop(context),
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
                    else if (model.missing)
                      const Text('삭제되었거나 찾을 수 없는 기록이에요. 목록을 다시 확인해 주세요.')
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
                      Text(
                        workoutStatusLabel(log.status),
                        style: TextStyle(
                          color: log.status == 'aborted'
                              ? ReferenceStyle.muted
                              : ReferenceStyle.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '시작 ${log.startedAt.toUtc().add(const Duration(hours: 9)).toString().substring(0, 16)} (한국 시간)',
                        style: ReferenceStyle.text(
                          12,
                          18,
                          color: ReferenceStyle.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnalysisPanel(
                        children: [
                          Text(
                            '${log.setCount ?? '—'}세트 · 총 볼륨 ${log.volume ?? '—'}kg',
                          ),
                          if (log.duration != null)
                            Text(
                              '운동 시간 ${log.duration! ~/ 60}분 ${log.duration! % 60}초',
                            ),
                        ],
                      ),
                      if (log.status == 'aborted')
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text(
                            '6시간을 넘겨 자동 중단된 기록이에요. 완료 통계에 포함되지 않아요.',
                            style: TextStyle(color: ReferenceStyle.muted),
                          ),
                        ),
                      if (log.status == 'in_progress')
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            log.activeAt(DateTime.now())
                                ? '진행 중인 운동의 세트는 운동 진행 화면에서 수정해 주세요.'
                                : '진행 상태를 다시 확인해 주세요. 6시간이 지난 운동은 이어갈 수 없어요.',
                          ),
                        ),
                      if (log.memo?.trim().isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: AnalysisPanel(
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
                              Text(log.memo!),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        '세트 기록',
                        style: ReferenceStyle.text(
                          18,
                          26,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (log.sets.isEmpty) const Text('등록된 세트가 없어요.'),
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
                              Text(
                                '휴식 ${set.rest == null ? '미기록' : '${set.rest}초'}',
                                style: ReferenceStyle.text(
                                  12,
                                  18,
                                  color: ReferenceStyle.muted,
                                ),
                              ),
                              if (log.status == 'completed')
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: model.canEdit
                                          ? () => edit(set)
                                          : null,
                                      child: const Text('세트 수정'),
                                    ),
                                    TextButton(
                                      onPressed: model.canEdit
                                          ? () async {
                                              if (await confirm(
                                                    '세트를 삭제할까요?',
                                                    '세트 번호는 다시 매기지 않아요. 기록의 통계는 서버에서 다시 계산돼요.',
                                                  ) &&
                                                  mounted) {
                                                await model.deleteSet(set);
                                              }
                                            }
                                          : null,
                                      child: const Text('세트 삭제'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: ReferenceStyle.text(12, 18, color: Colors.red),
                    ),
                    if (!model.missing)
                      TextButton(
                        onPressed: model.busy || model.loading
                            ? null
                            : model.load,
                        child: const Text('기록 다시 확인'),
                      ),
                  ],
                  if (model.accessCode == 'ONBOARDING_REQUIRED')
                    TextButton(
                      onPressed: widget.dependencies.onAccessRequired,
                      child: const Text('신체정보 확인'),
                    ),
                  if (model.log?.activeAt(DateTime.now()) == true &&
                      !model.loading &&
                      !model.needsReload) ...[
                    ReferenceButton(
                      '이어서 운동하기',
                      onPressed: model.busy
                          ? null
                          : () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => WorkoutPage(
                                  dependencies: widget.dependencies,
                                  logId: widget.id,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (model.missing)
                    ReferenceButton(
                      '목록으로',
                      onPressed: () => Navigator.pop(context),
                    )
                  else if (model.log != null)
                    OutlinedButton(
                      onPressed: model.canDelete
                          ? () async {
                              if (await confirm(
                                    '운동 기록을 삭제할까요?',
                                    '이 운동의 세트도 모두 삭제돼요. 연결된 루틴의 완료 상태와 진행률은 서버에서 다시 계산돼요.',
                                  ) &&
                                  mounted &&
                                  await model.delete() &&
                                  context.mounted) {
                                Navigator.pop(context, true);
                              }
                            }
                          : null,
                      child: const Text('운동 기록 삭제'),
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

class _RecordSetEditor extends StatefulWidget {
  const _RecordSetEditor({required this.set});
  final WorkoutSet set;
  @override
  State<_RecordSetEditor> createState() => _RecordSetEditorState();
}

class _RecordSetEditorState extends State<_RecordSetEditor> {
  late final weight = TextEditingController(text: widget.set.weight.toString()),
      reps = TextEditingController(text: widget.set.reps.toString()),
      rest = TextEditingController(text: widget.set.rest?.toString() ?? '');
  late bool done = widget.set.done;
  String? error;
  @override
  void dispose() {
    weight.dispose();
    reps.dispose();
    rest.dispose();
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
            key: const Key('record-weight'),
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '무게 (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('record-reps'),
            controller: reps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '횟수'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('record-rest'),
            controller: rest,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '실제 휴식 (초)',
              helperText: '비워두면 기존 휴식 시간을 유지해요.',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('완료 세트'),
            value: done,
            onChanged: (v) => setState(() => done = v ?? done),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          ReferenceButton(
            '수정 저장',
            onPressed: () {
              final w = num.tryParse(weight.text),
                  n = int.tryParse(reps.text),
                  s = int.tryParse(rest.text);
              if (w == null ||
                  !w.isFinite ||
                  w < 0 ||
                  w > 500 ||
                  n == null ||
                  n < 1 ||
                  n > 100 ||
                  (rest.text.trim().isNotEmpty &&
                      (s == null || s < 0 || s > 3600))) {
                setState(
                  () => error = '무게 0~500kg, 횟수 1~100회, 휴식 0~3600초로 입력해 주세요.',
                );
                return;
              }
              Navigator.pop(context, <String, dynamic>{
                'weight_kg': w,
                'reps': n,
                'rest_sec': ?s,
                'is_done': done,
              });
            },
          ),
        ],
      ),
    ),
  );
}
