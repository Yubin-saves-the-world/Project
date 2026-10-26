import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/app_selection.dart';
import '../../../../ui/core/theme/app_colors.dart';
import '../home_view_model.dart';

class WeeklyRoutineEditor extends StatefulWidget {
  const WeeklyRoutineEditor({
    super.key,
    required this.model,
    required this.date,
    this.onOpenExercises,
  });
  final HomeViewModel model;
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
  static const categories = ['가슴', '등', '하체', '어깨', '팔', '코어'];
  final selected = <int>[];
  final fields = <int, (TextEditingController, TextEditingController)>{};
  bool rest = false, repeat = true, submitted = false;
  @override
  void initState() {
    super.initState();
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
    setState(() => submitted = true);
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
                  onTap: widget.model.busy
                      ? null
                      : () => setState(() => rest = isRest),
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
                        Icon(
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
      padding: const EdgeInsets.only(bottom: 24),
      child: AppSelectionField<int>(
        key: const Key('routine-copy'),
        label: '다른 요일 루틴 복사',
        placeholder: '요일 선택',
        enabled: !widget.model.busy,
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
          onChanged: widget.model.busy
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
                    enabled: !widget.model.busy,
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
                    enabled: !widget.model.busy,
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
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(name, style: ReferenceStyle.text(14, 21, weight: FontWeight.w500)),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var j = 0; j < indices.length; j++) ...[
                if (j > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                _exercise(indices[j]),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) => PopScope(
      canPop: !widget.model.busy,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            key: const Key('routine-back'),
            tooltip: '뒤로가기',
            onPressed: widget.model.busy
                ? null
                : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
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
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                            const SizedBox(height: 20),
                            _dayType(),
                            const SizedBox(height: 24),
                            if (!rest) ...[
                              TextFormField(
                                key: const Key('routine-title'),
                                controller: title,
                                enabled: !widget.model.busy,
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
                              enabled: !widget.model.busy,
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
                                onTap: widget.model.busy
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
                              const SizedBox(height: 24),
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
                                      onPressed: widget.model.busy
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
                                    if (!HomeViewModel.exercises[i].selectable)
                                      i,
                                ]),
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
                          if (widget.model.error != null ||
                              (submitted && !rest && selected.isEmpty))
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
                            '일정 저장',
                            key: const Key('routine-save'),
                            onPressed: _save,
                            busy: widget.model.busy,
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
