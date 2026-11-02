import '../../../../ui/core/theme/app_spacing.dart';
import '../../../../ui/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/app_selection.dart';
import '../../../../ui/core/theme/app_colors.dart';
import '../home_view_model.dart';
import '../home_server_view_model.dart';
import '../../../routines/data/models/routine.dart';
import '../../../../ui/core/widgets/action_controls.dart';

class WeeklyRoutineEditor extends StatefulWidget {
  const WeeklyRoutineEditor({
    super.key,
    required this.model,
    required this.date,
    this.onOpenExercises,
    this.server,
    this.demoRecommendation,
  });
  final HomeViewModel model;
  final HomeServerViewModel? server;
  final RecommendedRoutine? demoRecommendation;
  final DateTime date;
  final VoidCallback? onOpenExercises;
  @override
  State<WeeklyRoutineEditor> createState() => _WeeklyRoutineEditorState();
}

class _WeeklyRoutineEditorState extends State<WeeklyRoutineEditor> {
  static const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  int? minutes;
  bool editing = false;
  bool recommended = false;
  bool demoApplied = false;
  RecommendedRoutine? get recommendation =>
      widget.server?.recommendation ?? widget.demoRecommendation;
  bool get isDemo =>
      widget.server?.recommendation == null &&
      widget.demoRecommendation != null;
  bool get busy => widget.model.busy || widget.server?.busy == true;
  static const categories = ['가슴', '등', '하체', '어깨', '팔', '코어'];
  final selected = <int>[];
  final expandedCategories = <String>{};
  final fields = <int, (TextEditingController, TextEditingController)>{};
  bool rest = false, repeat = true, submitted = false;
  @override
  void initState() {
    super.initState();
    recommended = widget.server?.usesRecommended ?? false;
    for (var i = 0; i < HomeViewModel.exercises.length; i++) {
      final exercise = HomeViewModel.exercises[i];
      fields[i] = (
        TextEditingController(text: '${exercise.sets}'),
        TextEditingController(text: '${exercise.reps}'),
      );
    }
    var nextOccurrence = widget.date;
    while (nextOccurrence.isBefore(widget.model.today)) {
      nextOccurrence = nextOccurrence.add(const Duration(days: 7));
    }
    repeat = !widget.model.schedule.dates.containsKey(
      HomeViewModel.dateKey(widget.date),
    );
    final existing = repeat
        ? widget.model.schedule.templateFor(nextOccurrence) ??
              widget.model.routineFor(widget.date)
        : widget.model.routineFor(widget.date);
    if (existing != null) {
      editing = true;
      _copy(existing);
    } else {
      title.text = '${weekdays[widget.date.weekday - 1]}요일 운동';
    }
  }

  void _copy(DayRoutine routine) {
    title.text = routine.title;
    minutes = routine.minutes;
    rest = routine.rest;
    selected.clear();
    for (final item in routine.items) {
      selected.add(item.exercise);
      fields[item.exercise]!.$1.text = '${item.sets}';
      fields[item.exercise]!.$2.text = '${item.reps}';
    }
  }

  @override
  void dispose() {
    title.dispose();
    for (final pair in fields.values) {
      pair.$1.dispose();
      pair.$2.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      submitted = true;
      for (final i in selected) {
        if (HomeViewModel.parseCount(fields[i]!.$1.text, 20) == null ||
            HomeViewModel.parseCount(fields[i]!.$2.text, 100) == null) {
          final part = HomeViewModel.exercises[i].category;
          expandedCategories.add(categories.contains(part) ? part : '기존 종목');
        }
      }
    });
    if (!form.currentState!.validate() || (!rest && selected.isEmpty)) return;
    final routine = rest
        ? DayRoutine.rest()
        : DayRoutine(
            title: title.text.trim(),
            minutes: minutes,
            items: selected
                .map(
                  (i) => RoutineItem(
                    exercise: i,
                    sets: int.parse(fields[i]!.$1.text),
                    reps: int.parse(fields[i]!.$2.text),
                  ),
                )
                .toList(),
          );
    if (await widget.model.saveRoutine(widget.date, routine, repeat: repeat) &&
        mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _applyRecommendation() async {
    final server = widget.server;
    if (isDemo) {
      final confirmed = await showAppConfirmation(
        context,
        '이 루틴을 선택할까요?',
        '선택한 날짜의 추천 루틴을 확인해 주세요.',
        action: '선택',
      );
      if (confirmed == true && mounted) setState(() => demoApplied = true);
      return;
    }
    if (server == null || !server.canChoose) return;
    final confirmed = await showAppConfirmation(
      context,
      '추천 루틴으로 교체할까요?',
      '선택한 날짜에만 적용해요. 직접 만든 반복 일정과 완료한 운동 기록은 유지돼요.',
      action: '적용',
      cancelLabel: '내 운동 유지',
    );
    if (confirmed != true || !mounted) return;
    if (await server.chooseRecommended() && mounted) {
      // Only manual saves return true; recommendation choices must not be
      // cleared by HomePage.manualSaved().
      Navigator.pop(context);
    }
  }

  Widget _sourceSelector() => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.medium),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final useRecommended in [false, true]) ...[
            if (useRecommended) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                selected: recommended == useRecommended,
                button: true,
                child: Material(
                  color: recommended == useRecommended
                      ? Colors.white
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: recommended == useRecommended
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: busy
                        ? null
                        : () => setState(() => recommended = useRecommended),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        useRecommended ? '추천 루틴' : '직접 만든 일정',
                        textAlign: TextAlign.center,
                        style: ReferenceStyle.text(
                          14,
                          21,
                          weight: FontWeight.w500,
                          color: recommended == useRecommended
                              ? AppColors.primary
                              : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _recommendedPreview() {
    final server = widget.server;
    final routine = recommendation!;
    final notice = isDemo
        ? (demoApplied ? '선택한 추천 루틴이에요.' : '이 날짜에 사용할 루틴을 선택해 주세요.')
        : server!.usesRecommended
        ? '이 날짜에 적용된 루틴이에요.'
        : server.canChoose
        ? '선택한 날짜에만 적용해요. 반복 일정은 유지돼요.'
        : '지금은 변경할 수 없어요. 날짜와 운동 진행 상태를 확인해 주세요.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '추천 운동',
                    style: ReferenceStyle.text(12, 18, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                routine.title,
                style: ReferenceStyle.text(18, 27, weight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                '${routine.items.length}종목 · 약 ${routine.minutes}분',
                style: ReferenceStyle.text(13, 20, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              for (final entry in routine.items.indexed) ...[
                Padding(
                  padding: EdgeInsets.only(
                    top: 16,
                    bottom: entry.$1 == routine.items.length - 1 ? 0 : 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          '${entry.$1 + 1}'.padLeft(2, '0'),
                          style: ReferenceStyle.text(
                            12,
                            21,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.$2.exercise.name,
                              style: ReferenceStyle.text(
                                14,
                                21,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${entry.$2.sets}세트 · ${entry.$2.reps}회 · 휴식 ${entry.$2.restSeconds}초',
                              style: ReferenceStyle.text(
                                12,
                                18,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.$1 < routine.items.length - 1)
                  const Divider(height: 1, color: AppColors.border),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            notice,
            style: ReferenceStyle.text(12, 18, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _dayType() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.soft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (final isRest in [false, true])
          Expanded(
            child: Semantics(
              button: true,
              selected: rest == isRest,
              child: Material(
                color: rest == isRest ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: ValueKey(
                    isRest ? 'routine-rest-day' : 'routine-workout-day',
                  ),
                  borderRadius: BorderRadius.circular(12),
                  onTap: busy ? null : () => setState(() => rest = isRest),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: rest == isRest
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(
                          isRest
                              ? Icons.nights_stay_outlined
                              : Icons.fitness_center_rounded,
                          size: 18,
                          color: rest == isRest
                              ? AppColors.primary
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isRest ? '휴식일' : '운동일',
                            style: ReferenceStyle.text(
                              14,
                              21,
                              weight: FontWeight.w500,
                              color: rest == isRest
                                  ? AppColors.primary
                                  : AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _copyField() {
    final copies = <int, DayRoutine>{};
    for (var weekday = 1; weekday <= 7; weekday++) {
      if (weekday == widget.date.weekday) continue;
      final day = widget.date.add(
        Duration(days: (weekday - widget.date.weekday + 7) % 7),
      );
      final routine = widget.model.routineFor(day);
      if (routine != null && !routine.rest) copies[weekday] = routine;
    }
    if (copies.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: AppSelectionField<int>(
        key: const Key('routine-copy'),
        label: '다른 요일 루틴 복사',
        placeholder: '요일 선택',
        enabled: !busy,
        options: copies.entries
            .map(
              (entry) => AppSelectionOption(
                entry.key,
                '${weekdays[entry.key - 1]}요일 · ${entry.value.title}',
                icon: Icons.copy_rounded,
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _copy(copies[value]!)),
      ),
    );
  }

  Widget _exercise(int i) {
    final exercise = HomeViewModel.exercises[i];
    return Column(
      children: [
        CheckboxListTile(
          key: ValueKey('routine-exercise-$i'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          value: selected.contains(i),
          title: Text(exercise.name),
          onChanged: busy
              ? null
              : (checked) => setState(() {
                  if (checked!) {
                    selected.add(i);
                  } else {
                    selected.remove(i);
                  }
                }),
        ),
        if (selected.contains(i))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('routine-sets-$i'),
                    controller: fields[i]!.$1,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '세트'),
                    validator: (value) =>
                        HomeViewModel.parseCount(value ?? '', 20) == null
                        ? '1~20세트'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('routine-reps-$i'),
                    controller: fields[i]!.$2,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '횟수'),
                    validator: (value) =>
                        HomeViewModel.parseCount(value ?? '', 100) == null
                        ? '1~100회'
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _category(String name, List<int> indices) => Padding(
    key: ValueKey('routine-category-$name'),
    padding: const EdgeInsets.only(top: AppSpacing.medium),
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            key: ValueKey('routine-category-toggle-$name'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              name,
              style: ReferenceStyle.text(14, 21, weight: FontWeight.w500),
            ),
            subtitle: Text(
              '${indices.length}종목 · ${indices.where(selected.contains).length}개 선택',
              style: ReferenceStyle.text(12, 18, color: AppColors.muted),
            ),
            trailing: AppIcon(
              expandedCategories.contains(name)
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 20,
            ),
            onTap: busy
                ? null
                : () => setState(() {
                    if (!expandedCategories.add(name)) {
                      expandedCategories.remove(name);
                    }
                  }),
          ),
          // Keep collapsed fields mounted so validation and unsaved inputs survive.
          Offstage(
            offstage: !expandedCategories.contains(name),
            child: Column(
              children: [
                for (final i in indices) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  _exercise(i),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.model,
      if (widget.server != null) widget.server!,
    ]),
    builder: (context, _) => PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            key: const Key('routine-back'),
            tooltip: '뒤로가기',
            onPressed: busy ? null : () => Navigator.maybePop(context),
            icon: const AppIcon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: Text(editing ? '일정 수정' : '일정 만들기'),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.page,
                        vertical: AppSpacing.medium,
                      ),
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${widget.date.month}월 ${widget.date.day}일 ${weekdays[widget.date.weekday - 1]}요일',
                              style: ReferenceStyle.text(
                                14,
                                21,
                                color: AppColors.primary,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.medium),
                            if (recommendation != null &&
                                (!rest || recommended))
                              _sourceSelector(),
                            if (recommended && recommendation != null)
                              _recommendedPreview()
                            else ...[
                              _dayType(),
                              const SizedBox(height: AppSpacing.medium),
                              if (!rest) ...[
                                TextFormField(
                                  key: const Key('routine-title'),
                                  controller: title,
                                  enabled: !busy,
                                  decoration: const InputDecoration(
                                    labelText: '루틴 이름',
                                    hintText: '예: 상체 운동',
                                  ),
                                  validator: (value) =>
                                      value == null ||
                                          value.trim().isEmpty ||
                                          value.trim().length > 40
                                      ? '루틴 이름을 1~40자로 입력해 주세요.'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                              ],
                              AppSelectionField<bool>(
                                key: const Key('routine-repeat'),
                                label: '적용 범위',
                                value: repeat,
                                enabled: !busy,
                                options: const [
                                  AppSelectionOption(
                                    true,
                                    '앞으로 매주',
                                    icon: Icons.event_repeat_rounded,
                                  ),
                                  AppSelectionOption(
                                    false,
                                    '이번 날짜만',
                                    icon: Icons.today_rounded,
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => repeat = value),
                              ),
                              if (!rest) ...[
                                const SizedBox(height: 16),
                                AppPickerField(
                                  key: const Key('routine-minutes'),
                                  label: '예상 소요 시간',
                                  value: minutes == null
                                      ? '시간 선택'
                                      : formatWorkoutDuration(minutes!),
                                  icon: Icons.timer_outlined,
                                  onTap: busy
                                      ? null
                                      : () async {
                                          final next =
                                              await showWorkoutDurationPicker(
                                                context,
                                                minutes: minutes,
                                              );
                                          if (next != null && mounted) {
                                            setState(
                                              () => minutes = next == 0
                                                  ? null
                                                  : next,
                                            );
                                          }
                                        },
                                ),
                                const SizedBox(height: AppSpacing.medium),
                                _copyField(),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '운동 종목',
                                        style: ReferenceStyle.text(
                                          17,
                                          26,
                                          weight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (widget.onOpenExercises != null)
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : widget.onOpenExercises,
                                        child: const Text('종목 정보'),
                                      ),
                                    Text(
                                      '${selected.length}개 선택',
                                      style: ReferenceStyle.text(
                                        12,
                                        18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                for (final category in categories)
                                  _category(category, [
                                    for (
                                      var i = 0;
                                      i < HomeViewModel.exercises.length;
                                      i++
                                    )
                                      if (HomeViewModel.exercises[i].category ==
                                              category &&
                                          HomeViewModel.exercises[i].selectable)
                                        i,
                                  ]),
                                if (selected.any(
                                  (i) => !HomeViewModel.exercises[i].selectable,
                                ))
                                  _category('기존 종목', [
                                    for (final i in selected)
                                      if (!HomeViewModel
                                          .exercises[i]
                                          .selectable)
                                        i,
                                  ]),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SafeArea(
                      top: false,
                      minimum: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (recommended && widget.server?.warning != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                widget.server!.warning!,
                                style: ReferenceStyle.text(
                                  12,
                                  18,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          if (!recommended &&
                              (widget.model.error != null ||
                                  (submitted && !rest && selected.isEmpty)))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                widget.model.error ?? '운동 종목을 하나 이상 선택해 주세요.',
                                style: ReferenceStyle.text(
                                  12,
                                  18,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ReferenceButton(
                            recommended ? '이 날짜에 적용' : '일정 저장',
                            key: const Key('routine-save'),
                            onPressed: recommended
                                ? ((isDemo && !demoApplied) ||
                                          (widget.server?.canChoose == true &&
                                              widget.server?.usesRecommended ==
                                                  false)
                                      ? _applyRecommendation
                                      : null)
                                : _save,
                            busy: busy,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
