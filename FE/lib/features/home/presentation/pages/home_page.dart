import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../auth/data/models/onboarding_progress.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../data/home_preview_repository.dart';
import '../home_view_model.dart';
import 'workout_calendar_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.onboarding,
    this.onLogout,
    this.loggingOut = false,
    this.logoutError,
    this.repository,
    this.today,
  });
  final OnboardingProgress? onboarding;
  final VoidCallback? onLogout;
  final bool loggingOut;
  final String? logoutError;
  final HomePreviewRepository? repository;
  final DateTime? today;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Timer? _clockTimer;
  late final HomeViewModel model;
  static const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  @override
  void initState() {
    super.initState();
    model = HomeViewModel(
      repository:
          widget.repository ??
          LocalHomePreviewRepository(
            widget.onboarding?.account?.email ?? 'demo',
          ),
      today: widget.today,
      frequency: widget.onboarding?.profile?.weeklyFrequency ?? 3,
    );
    WidgetsBinding.instance.addObserver(this);
    model.initialize();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) model.refreshClock();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    model.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) model.refreshClock();
  }

  TextStyle _text(
    double size, {
    Color color = ReferenceStyle.ink,
    bool bold = false,
  }) => ReferenceStyle.text(
    size,
    size * 1.5,
    color: color,
    weight: bold ? FontWeight.w500 : FontWeight.w400,
  );
  Widget _card(
    Widget child, {
    bool blue = false,
    double radius = 16,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(
        color: blue ? ReferenceStyle.blue : const Color(0xFFE4E1D8),
      ),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
  void _info(String title, String body) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
  Widget _restButton() => TextButton.icon(
    key: const Key('home-rest-toggle'),
    onPressed: !model.canWrite
        ? null
        : () => model.setRestDay(
            model.selectedDate,
            rest: model.planned(model.selectedDate),
          ),
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(44, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: _text(12),
    ),
    icon: const Icon(Icons.hotel_outlined, size: 16),
    label: Text(model.planned(model.selectedDate) ? '휴식일 지정' : '휴식일 해제'),
  );

  Future<void> _routine() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('하체 집중 · 예시 루틴', style: _text(20, bold: true)),
                const SizedBox(height: 8),
                Text(
                  '분석 결과가 아닌 화면 테스트용 루틴입니다.',
                  style: _text(12, color: ReferenceStyle.muted),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < HomeViewModel.exercises.length; i++)
                  ListTile(
                    title: Text(HomeViewModel.exercises[i].name),
                    subtitle: Text(
                      '${HomeViewModel.exercises[i].sets}세트 · ${HomeViewModel.exercises[i].reps}회',
                    ),
                    trailing: model.exerciseDone(i)
                        ? const Text('완료')
                        : !model.isToday
                        ? const Text('조회')
                        : const Icon(Icons.play_circle_outline_rounded),
                    onTap:
                        !model.isToday ||
                            !model.canWrite ||
                            model.exerciseDone(i)
                        ? null
                        : () {
                            Navigator.pop(context);
                            _exercise(i);
                          },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exercise(int index, {bool resume = false}) async {
    if (!model.canWrite) return;
    await model.refreshClock();
    if (!mounted) return;
    final current = model.active;
    if (resume) {
      if (current == null) return;
      index = current.exercise;
    } else {
      if (!model.isToday) return;
      if (current != null && current.exercise != index) {
        final choice = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('진행 중인 운동이 있어요'),
            content: Text(
              '${HomeViewModel.exercises[current.exercise].name}을 진행 중이에요. 이어하거나 취소한 뒤 새 종목을 시작해 주세요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'resume'),
                child: const Text('기존 운동 이어하기'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'replace'),
                child: const Text('취소하고 새 운동'),
              ),
            ],
          ),
        );
        if (choice == null || !mounted) return;
        if (choice == 'resume') {
          index = current.exercise;
          resume = true;
        } else if (!await model.cancelActive() || !mounted) {
          return;
        }
      }
      if (!resume && !await model.start(index)) return;
    }
    if (!mounted || model.active == null) return;
    final exercise = HomeViewModel.exercises[model.active!.exercise];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) =>
          _WorkoutPreviewForm(model: model, exercise: exercise),
    );
  }

  void _records() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => WorkoutCalendarPage(model: model)),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) => Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.onboarding?.account?.nickname ?? '회원'}님, ${model.planned(model.today) ? '하체 가는 날' : '오늘은 휴식일'}',
                              maxLines: 2,
                              style: ReferenceStyle.text(
                                20,
                                31,
                                weight: FontWeight.w500,
                                spacing: -.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _info(
                          '연속 운동 기록',
                          '기기 내 미리보기 기준 ${model.streak}일 연속 운동했어요. 완료한 운동이 있는 날짜로 계산합니다.',
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE4E1D8)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_fire_department_outlined,
                                size: 16,
                                color: ReferenceStyle.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${model.streak}일',
                                style: _text(12, color: ReferenceStyle.blue),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: '알림',
                        onPressed: () =>
                            _info('알림', '운동·식단 알림은 서비스 연결 후 제공됩니다.'),
                        icon: SizedBox(
                          width: 22,
                          height: 22,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/bell.svg',
                              width: 17.5,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                ReferenceStyle.muted,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE4E1D8)),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                      if (widget.onLogout != null)
                        PopupMenuButton<String>(
                          tooltip: '계정 메뉴',
                          icon: const Icon(Icons.more_horiz_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'logout',
                              enabled: !widget.loggingOut,
                              child: Text(
                                widget.loggingOut ? '로그아웃 중' : '로그아웃',
                              ),
                            ),
                          ],
                          onSelected: (_) => widget.onLogout!(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: ReferenceStyle.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < 7; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: sameDate(
                                model.week[i],
                                model.selectedDate,
                              ),
                              label:
                                  '${weekdays[i]}요일 ${model.week[i].day}일, ${completedDay(model.week[i])
                                      ? '운동 완료'
                                      : model.planned(model.week[i])
                                      ? '운동 예정'
                                      : '휴식일'}',
                              child: InkWell(
                                key: ValueKey('home-weekday-$i'),
                                onTap: () => model.select(model.week[i]),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 56,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        sameDate(
                                          model.week[i],
                                          model.selectedDate,
                                        )
                                        ? ReferenceStyle.blue
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        weekdays[i],
                                        style: ReferenceStyle.text(
                                          11,
                                          16,
                                          color:
                                              sameDate(
                                                model.week[i],
                                                model.selectedDate,
                                              )
                                              ? Colors.white
                                              : ReferenceStyle.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${model.week[i].day}',
                                        style: ReferenceStyle.text(
                                          13,
                                          20,
                                          weight: FontWeight.w500,
                                          color:
                                              sameDate(
                                                model.week[i],
                                                model.selectedDate,
                                              )
                                              ? Colors.white
                                              : completedDay(model.week[i])
                                              ? ReferenceStyle.blue
                                              : model.planned(model.week[i])
                                              ? ReferenceStyle.ink
                                              : ReferenceStyle.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (model.loading) const LinearProgressIndicator(),
                  if (model.error != null)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            model.error!,
                            style: _text(12, color: Colors.red),
                          ),
                        ),
                        if (!model.loaded)
                          TextButton(
                            onPressed: model.loading ? null : model.initialize,
                            child: const Text('다시 불러오기'),
                          ),
                      ],
                    ),
                  if (widget.logoutError != null)
                    Text(
                      '로그아웃하지 못했어요. 다시 시도해 주세요.',
                      style: _text(12, color: Colors.red),
                    ),
                  if (model.active != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _card(
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.play_circle_outline_rounded,
                            color: ReferenceStyle.blue,
                          ),
                          title: const Text('이어서 운동하기'),
                          subtitle: Text(
                            HomeViewModel
                                .exercises[model.active!.exercise]
                                .name,
                          ),
                          onTap: () =>
                              _exercise(model.active!.exercise, resume: true),
                        ),
                        blue: true,
                      ),
                    ),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                sameDate(model.selectedDate, model.today)
                                    ? '오늘의 루틴'
                                    : '선택한 날짜의 루틴',
                                style: ReferenceStyle.text(
                                  10,
                                  14,
                                  color: ReferenceStyle.blue,
                                  spacing: 1,
                                ),
                              ),
                            ),
                            _restButton(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                model.planned(model.selectedDate)
                                    ? '하체 집중 · 4종목'
                                    : model.isToday
                                    ? '오늘은 휴식일'
                                    : '선택한 날은 휴식일',
                                style: ReferenceStyle.text(
                                  17,
                                  26,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (model.planned(model.selectedDate))
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '예시',
                                    style: _text(
                                      10,
                                      color: ReferenceStyle.muted,
                                    ),
                                  ),
                                  Text(
                                    '52분',
                                    style: _text(
                                      11,
                                      color: ReferenceStyle.muted,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (!model.isToday)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              model.selectedDate.isBefore(model.today)
                                  ? '지난 날짜의 운동은 기록만 조회할 수 있어요.'
                                  : '예정 루틴은 미리보기만 가능해요. 운동은 오늘 시작해 주세요.',
                              style: _text(12, color: ReferenceStyle.muted),
                            ),
                          ),
                        if (model.planned(model.selectedDate)) ...[
                          for (final exercise in HomeViewModel.exercises.take(
                            3,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      exercise.name,
                                      style: _text(13),
                                    ),
                                  ),
                                  Text(
                                    '${exercise.sets}세트 · ${exercise.reps}회',
                                    style: _text(
                                      12,
                                      color: ReferenceStyle.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (model.doneCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${model.doneCount} / 4종목 완료',
                                style: _text(11, color: ReferenceStyle.blue),
                              ),
                            ),
                          TextButton(
                            onPressed: _routine,
                            child: const Text('전체 4종목 보기'),
                          ),
                          const SizedBox(height: 4),
                          ReferenceButton(
                            model.routineDone
                                ? '운동 완료 · 기록 보기'
                                : model.isToday
                                ? '운동 시작'
                                : '루틴 보기',
                            onPressed: !model.canWrite
                                ? null
                                : model.routineDone
                                ? _records
                                : _routine,
                          ),
                        ],
                        if (!model.planned(model.selectedDate)) ...[
                          Text(
                            '가볍게 쉬고 다음 운동을 준비해 주세요.',
                            style: _text(13, color: ReferenceStyle.muted),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: !model.canWrite ? null : _routine,
                            child: const Text('운동 종목 보기'),
                          ),
                        ],
                      ],
                    ),
                    blue: true,
                    radius: 18,
                  ),
                  const SizedBox(height: 16),
                  _recordCard(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _shortcut(
                          Icons.restaurant_outlined,
                          '맞춤 식단',
                          '서비스 연결 준비 중',
                          () => _info(
                            '맞춤 식단',
                            '목표 칼로리와 끼니별 식단은 서버·분석 연결 후 제공됩니다.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _shortcut(
                          Icons.accessibility_new_rounded,
                          '자세 교정',
                          '분석 연결 준비 중',
                          () => _info(
                            '자세 교정',
                            '실제 체형분석 결과의 주의 항목을 바탕으로 안내할 예정입니다.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.track_changes_rounded,
                              size: 19,
                              color: ReferenceStyle.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '이번 주 미션',
                                style: _text(14, bold: true),
                              ),
                            ),
                            Text(
                              '${math.min(model.workoutDays, 3)} / 3',
                              style: _text(12, color: ReferenceStyle.blue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: math.min(model.workoutDays / 3, 1),
                            minHeight: 4,
                            backgroundColor: const Color(0xFFE4E1D8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '예시 목표 · 주 3일 운동하기 · 할인권 발급 준비 중',
                          style: _text(11, color: ReferenceStyle.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 12),
                  Text(
                    '현재 화면의 루틴과 운동 기록은 개발용 미리보기입니다.',
                    textAlign: TextAlign.center,
                    style: _text(10, color: ReferenceStyle.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _recordCard() => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('운동 기록', style: _text(14, bold: true))),
            TextButton(
              onPressed: _records,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('보기'),
            ),
          ],
        ),
        Text(
          '${model.selectedDate.month}월 ${model.selectedDate.day}일',
          style: _text(12, color: ReferenceStyle.muted),
        ),
        const SizedBox(height: 8),
        Text(
          model.loading
              ? '기록을 불러오는 중이에요.'
              : !model.loaded
              ? '기록을 불러온 뒤 요약을 확인할 수 있어요.'
              : model.dayWorkouts.isEmpty
              ? '아직 완료한 운동이 없어요.'
              : '${model.doneCount}종목 · ${model.totalSets}세트 · 총 볼륨 ${model.volume.toStringAsFixed(0)}kg',
          style: _text(14),
        ),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
  );
  bool completedDay(DateTime day) =>
      model.completed.any((w) => sameDate(w.date, day));
  Widget _shortcut(
    IconData icon,
    String title,
    String description,
    VoidCallback action,
  ) => InkWell(
    onTap: action,
    borderRadius: BorderRadius.circular(16),
    child: _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ReferenceStyle.muted),
          const SizedBox(height: 8),
          Text(title, style: _text(14, bold: true)),
          const SizedBox(height: 4),
          Text(description, style: _text(11, color: ReferenceStyle.muted)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

class _WorkoutPreviewForm extends StatefulWidget {
  const _WorkoutPreviewForm({required this.model, required this.exercise});
  final HomeViewModel model;
  final PreviewExercise exercise;
  @override
  State<_WorkoutPreviewForm> createState() => _WorkoutPreviewFormState();
}

class _WorkoutPreviewFormState extends State<_WorkoutPreviewForm> {
  final form = GlobalKey<FormState>();
  final weight = TextEditingController();
  late final TextEditingController reps, sets;
  @override
  void initState() {
    super.initState();
    reps = TextEditingController(text: '${widget.exercise.reps}');
    sets = TextEditingController(text: '${widget.exercise.sets}');
  }

  @override
  void dispose() {
    weight.dispose();
    reps.dispose();
    sets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) => widget.model.active == null
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('진행 중인 운동이 종료되었어요.'),
                  const SizedBox(height: 12),
                  const Text('6시간이 지난 운동은 자동 중단되고 집계에서 제외됩니다.'),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            ),
          )
        : SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.exercise.name,
                        style: ReferenceStyle.text(
                          20,
                          30,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '기기 내 운동 기록 미리보기입니다. 중량은 직접 입력해 주세요.',
                        style: ReferenceStyle.text(
                          12,
                          18,
                          color: ReferenceStyle.muted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final item in [
                        ('무게(kg)', weight, true),
                        ('횟수', reps, false),
                        ('세트 수', sets, false),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            key: Key('preview-${item.$1}'),
                            controller: item.$2,
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: item.$3,
                            ),
                            decoration: InputDecoration(
                              labelText: item.$1,
                              hintText: item.$3 ? '0 (맨몸 운동)' : null,
                            ),
                            validator: (value) {
                              if (item.$3) {
                                return HomeViewModel.parseWeight(value ?? '') ==
                                        null
                                    ? '무게는 0~500kg으로 입력해 주세요.'
                                    : null;
                              }
                              final max = item.$1 == '세트 수' ? 20 : 100;
                              return HomeViewModel.parseCount(
                                        value ?? '',
                                        max,
                                      ) ==
                                      null
                                  ? '1~$max 범위의 정수로 입력해 주세요.'
                                  : null;
                            },
                          ),
                        ),
                      if (widget.model.error != null)
                        Text(
                          widget.model.error!,
                          style: ReferenceStyle.text(12, 18, color: Colors.red),
                        ),
                      ReferenceButton(
                        '종목 완료',
                        busy: widget.model.busy,
                        onPressed: !widget.model.canWrite
                            ? null
                            : () async {
                                if (!form.currentState!.validate()) return;
                                if (await widget.model.complete(
                                      HomeViewModel.parseWeight(weight.text)!,
                                      HomeViewModel.parseCount(reps.text, 100)!,
                                      HomeViewModel.parseCount(sets.text, 20)!,
                                    ) &&
                                    context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                      ),
                      TextButton(
                        onPressed: widget.model.canWrite
                            ? () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('진행 중인 운동을 취소할까요?'),
                                    content: const Text(
                                      '현재 진행 중인 기록만 취소합니다. 이미 완료한 운동 기록은 유지됩니다.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('계속 운동하기'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('운동 취소'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true &&
                                    await widget.model.cancelActive() &&
                                    context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            : null,
                        child: const Text('운동 취소'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}
