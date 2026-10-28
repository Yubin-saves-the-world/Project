import '../../../../ui/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/app_scaffold.dart';
import '../../../../ui/core/widgets/empty_view.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../body_analysis/presentation/pages/analysis_run_page.dart'
    show AnalysisPanel;
import '../../../home/presentation/home_server_dependencies.dart';
import '../../../home/presentation/home_view_model.dart';
import '../../../home/presentation/pages/workout_calendar_page.dart';
import '../../../routines/data/models/routine.dart';
import '../workout_history_view_model.dart';
import 'workout_record_page.dart';

class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({
    super.key,
    this.server,
    this.local,
    this.initialDate,
    this.today,
    this.isActive = true,
    this.refreshToken = 0,
  });
  final HomeServerDependencies? server;
  final HomeViewModel? local;
  final DateTime? initialDate, today;
  final bool isActive;
  final int refreshToken;
  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage>
    with WidgetsBindingObserver {
  WorkoutHistoryViewModel? model;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _create();
  }

  void _create() {
    model = widget.server == null
        ? null
        : WorkoutHistoryViewModel(
            widget.server!.repository,
            date: widget.initialDate,
            today: widget.today,
          );
    if (widget.isActive) model?.refresh();
  }

  @override
  void didUpdateWidget(covariant WorkoutHistoryPage old) {
    super.didUpdateWidget(old);
    if (old.server != widget.server) {
      model?.dispose();
      _create();
    } else if (widget.isActive &&
        (!old.isActive || old.refreshToken != widget.refreshToken)) {
      model?.refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) model?.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model?.dispose();
    super.dispose();
  }

  Future<void> detail(int id) async {
    if (widget.server?.workouts == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            WorkoutRecordPage(dependencies: widget.server!.workouts!, id: id),
      ),
    );
    if (mounted) await model?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final m = model;
    if (m == null) {
      return const AppScaffold(
        title: '운동 기록',
        body: EmptyView(title: '운동 기록 준비 중', description: '곧 만나요.'),
      );
    }
    return ListenableBuilder(
      listenable: m,
      builder: (context, _) => ManagementPage(
        title: '운동 기록',
        body: RefreshIndicator(
          onRefresh: m.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '이전 달',
                    onPressed: m.month.year > 1 || m.month.month > 1
                        ? () => m.changeMonth(-1)
                        : null,
                    icon: const AppIcon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${m.month.year}년 ${m.month.month}월',
                      textAlign: TextAlign.center,
                      style: ReferenceStyle.text(
                        20,
                        28,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 달',
                    onPressed:
                        m.month.isBefore(
                          DateTime.utc(m.today.year, m.today.month),
                        )
                        ? () => m.changeMonth(1)
                        : null,
                    icon: const AppIcon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final label in ['월', '화', '수', '목', '금', '토', '일'])
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: ReferenceStyle.text(
                          12,
                          18,
                          color: ReferenceStyle.muted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ..._weeks(m),
              if (m.monthLoading)
                const LinearProgressIndicator()
              else if (m.monthError != null) ...[
                Text(m.monthError!, style: const TextStyle(color: Colors.red)),
                TextButton(
                  onPressed: m.loadMonth,
                  child: const Text('월 기록 다시 확인'),
                ),
              ] else if (m.summary case final summary?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: AnalysisPanel(
                    children: [
                      Text(
                        '월간 완료 기록',
                        style: ReferenceStyle.text(
                          14,
                          21,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${summary.dates.length}일 · ${summary.count}개 기록 · ${summary.sets}세트',
                      ),
                      Text(
                        '총 볼륨 ${summary.volume}kg · 운동 시간 ${summary.seconds == null ? '확인 필요' : '${summary.seconds! ~/ 60}분'}',
                        style: ReferenceStyle.text(
                          12,
                          18,
                          color: ReferenceStyle.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                '파란 점은 완료한 운동이 있는 날이에요.',
                style: TextStyle(fontSize: 12, color: ReferenceStyle.muted),
              ),
              const SizedBox(height: 24),
              Text(
                '${m.selected.month}월 ${m.selected.day}일 운동 기록',
                style: ReferenceStyle.text(18, 26, weight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in <String?, String>{
                    null: '전체',
                    'completed': '완료',
                    'in_progress': '진행 중',
                    'aborted': '중단',
                  }.entries)
                    ChoiceChip(
                      label: Text(f.value),
                      selected: m.status == f.key,
                      onSelected: (_) => m.filter(f.key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (m.dayLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (m.dayError == null && m.items.isEmpty)
                  const Text('선택한 조건의 운동 기록이 없어요.'),
                for (final record in m.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: ReferenceStyle.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: widget.server?.workouts == null
                            ? null
                            : () => detail(record.id),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                record.name,
                                style: ReferenceStyle.text(
                                  16,
                                  24,
                                  weight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                workoutStatusLabel(record.status),
                                style: TextStyle(
                                  color: record.status == 'aborted'
                                      ? ReferenceStyle.muted
                                      : ReferenceStyle.blue,
                                ),
                              ),
                              Text(
                                '${record.sets}세트 · 총 볼륨 ${record.volume}kg',
                              ),
                              if (record.seconds != null)
                                Text(
                                  '${record.seconds! ~/ 60}분 ${record.seconds! % 60}초',
                                  style: ReferenceStyle.text(
                                    12,
                                    18,
                                    color: ReferenceStyle.muted,
                                  ),
                                ),
                              if (record.status == 'aborted')
                                const Text(
                                  '완료 통계에서 제외',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ReferenceStyle.muted,
                                  ),
                                ),
                              if (widget.server?.workouts != null)
                                const Align(
                                  alignment: Alignment.centerRight,
                                  child: AppIcon(
                                    Icons.chevron_right_rounded,
                                    color: ReferenceStyle.muted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              if (m.dayError != null) ...[
                Text(m.dayError!, style: const TextStyle(color: Colors.red)),
                TextButton(
                  onPressed: m.day == null ? m.loadDay : m.more,
                  child: const Text('기록 다시 확인'),
                ),
              ],
              if (m.moreLoading)
                const Center(child: CircularProgressIndicator())
              else if (m.hasMore && m.dayError == null)
                TextButton(onPressed: m.more, child: const Text('기록 더 보기')),
              if (widget.local != null)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => WorkoutCalendarPage(model: widget.local!),
                    ),
                  ),
                  child: const Text('기기에 저장된 기록 보기'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _weeks(WorkoutHistoryViewModel m) {
    final count = DateTime.utc(m.month.year, m.month.month + 1, 0).day;
    final offset = m.month.weekday - 1;
    return [
      for (var row = 0; row < (offset + count + 6) ~/ 7; row++)
        Row(
          children: [
            for (var column = 0; column < 7; column++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final n = row * 7 + column - offset + 1;
                    if (n < 1 || n > count) return const SizedBox(height: 54);
                    final date = DateTime.utc(m.month.year, m.month.month, n),
                        selected = m.selected.day == n;
                    final enabled = !date.isAfter(m.today);
                    final marked =
                        m.summary?.dates.contains(routineDateKey(date)) == true;
                    return Semantics(
                      label: '${date.month}월 $n일${marked ? ' 운동 기록 있음' : ''}',
                      selected: selected,
                      child: InkWell(
                        key: ValueKey('record-day-${routineDateKey(date)}'),
                        borderRadius: BorderRadius.circular(24),
                        onTap: enabled ? () => m.select(date) : null,
                        child: SizedBox(
                          height: 54,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected ? ReferenceStyle.blue : null,
                                  border: date == m.today && !selected
                                      ? Border.all(color: ReferenceStyle.blue)
                                      : null,
                                ),
                                child: Text(
                                  '$n',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'CapstoneUI',
                                    fontSize: 14,
                                    height: 1,
                                    leadingDistribution:
                                        TextLeadingDistribution.even,
                                    color: selected
                                        ? Colors.white
                                        : enabled
                                        ? ReferenceStyle.ink
                                        : ReferenceStyle.muted.withValues(
                                            alpha: 0.5,
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: marked
                                      ? ReferenceStyle.blue
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
    ];
  }
}
