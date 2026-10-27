import '../../../../ui/core/theme/app_colors.dart';
import '../../../../ui/core/widgets/app_icon.dart';
import '../../../workout/presentation/pages/workout_history_page.dart';
import '../home_server_dependencies.dart';
import '../home_server_view_model.dart';
import '../widgets/server_home_cards.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../auth/data/models/onboarding_progress.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../data/home_preview_repository.dart';
import '../home_view_model.dart';
import 'workout_calendar_page.dart';
import 'weekly_routine_editor.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.onboarding,
    this.onOpenMyPage,
    this.onOpenExercises,
    this.loggingOut = false,
    this.logoutError,
    this.repository,
    this.today,
    this.server,
    this.onOpenAnalysis,
    this.refreshToken = 0,
    this.isActive = true,
  });
  final OnboardingProgress? onboarding;
  final VoidCallback? onOpenMyPage;
  final VoidCallback? onOpenExercises;
  final bool loggingOut;
  final String? logoutError;
  final HomePreviewRepository? repository;
  final DateTime? today;
  final HomeServerDependencies? server;
  final VoidCallback? onOpenAnalysis;
  final int refreshToken;
  final bool isActive;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Timer? _clockTimer;
  late final HomeViewModel model;
  HomeServerViewModel? server;
  static const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  @override
  void initState() {
    super.initState();
    model = HomeViewModel(
      repository:
          widget.repository ??
          LocalHomePreviewRepository(
            widget.onboarding?.account?.storageOwner ?? 'demo',
          ),
      today: widget.today,
      frequency: widget.onboarding?.profile?.weeklyFrequency ?? 3,
    );
    WidgetsBinding.instance.addObserver(this);
    server = widget.server == null
        ? null
        : HomeServerViewModel(widget.server!, model);
    _refresh();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        final previous = HomeViewModel.dateKey(model.today);
        model.refreshClock().then((_) {
          if (mounted &&
              widget.isActive &&
              (previous != HomeViewModel.dateKey(model.today) ||
                  server != null)) {
            server?.refresh();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    server?.dispose();
    model.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) _refresh();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken ||
        (widget.isActive && !oldWidget.isActive)) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (server?.busy == true) return;
    await model.refreshClock();
    await model.initialize();
    if (mounted) await server?.refresh();
  }

  Future<void> _chooseRecommended() async {
    final data = server;
    if (data == null || !data.canChoose) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('추천 루틴으로 교체할까요?'),
        content: const Text(
          '선택한 날짜에는 추천 루틴을 사용해요. 다른 날짜와 반복 일정, 완료한 기록은 유지돼요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('내 운동 유지'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('추천 루틴으로 교체'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await data.chooseRecommended();
  }

  Future<void> _releaseRest() async {
    if (server != null && await server!.restoreRestDay()) return;
    if (mounted) await _editSchedule();
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
      border: Border.all(color: blue ? ReferenceStyle.blue : AppColors.border),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: child,
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
  Future<void> _editSchedule() async {
    if (!model.canWrite || server?.busy == true) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WeeklyRoutineEditor(
          model: model,
          date: model.selectedDate,
          onOpenExercises: widget.onOpenExercises,
        ),
      ),
    );
    if (saved == true && mounted) {
      await server?.manualSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일정을 저장했어요.')));
    }
  }

  Widget _restButton() => TextButton.icon(
    key: const Key('home-rest-toggle'),
    onPressed: model.canWrite ? _editSchedule : null,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(44, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: _text(12),
    ),
    icon: const AppIcon(Icons.edit_calendar_outlined, size: 16),
    label: const Text('일정 수정'),
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
                Text(
                  model.selectedRoutine?.title ?? '운동 루틴',
                  style: _text(20, bold: true),
                ),
                for (final item in model.routineItems)
                  ListTile(
                    title: Text(HomeViewModel.exercises[item.exercise].name),
                    subtitle: Text('${item.sets}세트 · ${item.reps}회'),
                    trailing: model.exerciseDone(item.exercise)
                        ? const Text('완료')
                        : !model.isToday
                        ? const Text('조회')
                        : const AppIcon(Icons.play_circle_outline_rounded),
                    onTap:
                        !model.isToday ||
                            !model.canWrite ||
                            model.exerciseDone(item.exercise)
                        ? null
                        : () {
                            Navigator.pop(context);
                            _exercise(item.exercise);
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
      builder: (context) => server == null
          ? _WorkoutPreviewForm(model: model, exercise: exercise)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (server != null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('이 운동 기록은 현재 기기에 저장돼요.'),
                  ),
                Flexible(
                  child: _WorkoutPreviewForm(model: model, exercise: exercise),
                ),
              ],
            ),
    );
  }

  Future<void> _records() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => widget.server?.workouts != null
            ? WorkoutHistoryPage(
                server: widget.server,
                local: model,
                initialDate: model.selectedDate,
              )
            : WorkoutCalendarPage(
                model: model,
                serverRepository: widget.server?.repository,
              ),
      ),
    );
    if (mounted) await server?.refresh();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([model, ?server]),
    builder: (context, _) => Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _refreshable(
              SingleChildScrollView(
                physics: server == null
                    ? null
                    : const AlwaysScrollableScrollPhysics(),
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
                                '${widget.onboarding?.account?.nickname ?? '회원'}님, ${_planned(model.today)
                                    ? '오늘도 함께해요'
                                    : model.routineFor(model.today) == null
                                    ? '일정을 정해요'
                                    : '오늘은 휴식일'}',
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
                            server?.streakDescription ??
                                '${model.streak}일 연속 운동했어요.',
                          ),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const AppIcon(
                                  Icons.local_fire_department_outlined,
                                  size: 16,
                                  color: ReferenceStyle.blue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  server?.streakLabel ?? '${model.streak}일',
                                  style: _text(12, color: ReferenceStyle.blue),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: '알림',
                          onPressed: () => _info('알림', '알림을 준비하고 있어요.'),
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
                            side: const BorderSide(color: AppColors.border),
                            minimumSize: const Size(36, 36),
                          ),
                        ),
                        if (widget.onOpenMyPage != null)
                          IconButton(
                            tooltip: '마이페이지',
                            onPressed: widget.loggingOut
                                ? null
                                : widget.onOpenMyPage,
                            icon: SizedBox(
                              width: 22,
                              height: 22,
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/icons/profile.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: const ColorFilter.mode(
                                    ReferenceStyle.muted,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                            style: IconButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              minimumSize: const Size(36, 36),
                            ),
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
                                        : _planned(model.week[i])
                                        ? '운동 예정'
                                        : model.routineFor(model.week[i]) == null
                                        ? '일정 미설정'
                                        : '휴식일'}',
                                child: InkWell(
                                  key: ValueKey('home-weekday-$i'),
                                  onTap: server?.busy == true
                                      ? null
                                      : () {
                                          model.select(model.week[i]);
                                          server?.loadDay();
                                        },
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
                                                : _planned(model.week[i])
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
                              onPressed: model.loading
                                  ? null
                                  : model.initialize,
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
                            leading: const AppIcon(
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
                    if (server != null &&
                        (server!.usesRecommended ||
                            model.selectedRoutine == null))
                      ServerRecommendationCard(
                        model: server!,
                        onEdit: _editSchedule,
                        onChoose: _chooseRecommended,
                        onAnalysis: widget.onOpenAnalysis,
                      )
                    else
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
                                        ? '${model.selectedRoutine!.title} · ${model.routineItems.length}종목'
                                        : model.selectedRoutine == null
                                        ? '일주일 운동 일정을 만들어 주세요'
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
                                if (model.selectedRoutine?.minutes != null)
                                  Text(
                                    '${model.selectedRoutine!.minutes}분',
                                    style: _text(
                                      11,
                                      color: ReferenceStyle.muted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (model.planned(model.selectedDate)) ...[
                              for (final item in model.routineItems.take(3))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          HomeViewModel
                                              .exercises[item.exercise]
                                              .name,
                                          style: _text(13),
                                        ),
                                      ),
                                      Text(
                                        '${item.sets}세트 · ${item.reps}회',
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
                                    '${model.routineDoneCount} / ${model.routineItems.length}종목 완료',
                                    style: _text(
                                      11,
                                      color: ReferenceStyle.blue,
                                    ),
                                  ),
                                ),
                              TextButton(
                                onPressed: _routine,
                                child: Text(
                                  '전체 ${model.routineItems.length}종목 보기',
                                ),
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
                              ReferenceButton(
                                model.selectedRoutine == null
                                    ? '일정 만들기'
                                    : '운동일로 변경',
                                onPressed: model.canWrite
                                    ? (model.selectedRoutine?.rest == true &&
                                              server != null
                                          ? _releaseRest
                                          : _editSchedule)
                                    : null,
                              ),
                            ],
                          ],
                        ),
                        blue: true,
                        radius: 18,
                      ),
                    const SizedBox(height: 16),
                    if (server != null &&
                        !server!.usesRecommended &&
                        model.selectedRoutine != null &&
                        server!.recommendation != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: server!.canChoose
                              ? _chooseRecommended
                              : null,
                          child: const Text('추천 루틴으로 교체'),
                        ),
                      ),
                    if (server?.warning != null) ...[
                      Text(
                        server!.warning!,
                        style: _text(12, color: Colors.red),
                      ),
                      TextButton(
                        onPressed: server!.refresh,
                        child: const Text('동기화 다시 확인'),
                      ),
                    ],
                    if (server?.error != null &&
                        model.selectedRoutine != null) ...[
                      Text(server!.error!, style: _text(12, color: Colors.red)),
                      TextButton(
                        onPressed: server!.refresh,
                        child: const Text('서버 다시 확인'),
                      ),
                    ],
                    if (server?.accessCode == 'ONBOARDING_REQUIRED' &&
                        widget.server?.onAccessRequired != null)
                      TextButton(
                        onPressed: widget.server!.onAccessRequired,
                        child: const Text('신체정보 확인'),
                      ),
                    if (server == null)
                      _recordCard()
                    else
                      ServerHomeRecordCard(model: server!, onRecords: _records),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _shortcut(
                            Icons.restaurant_outlined,
                            '맞춤 식단',
                            '준비 중',
                            () => _info('맞춤 식단', '맞춤 식단을 준비하고 있어요.'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _shortcut(
                            Icons.accessibility_new_rounded,
                            '자세 교정',
                            '준비 중',
                            () => _info('자세 교정', '자세 교정을 준비하고 있어요.'),
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
                              const AppIcon(
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
                                server != null &&
                                        (server!.loading ||
                                            server!.error != null)
                                    ? '확인 중'
                                    : '${math.min(server?.workoutDays ?? model.workoutDays, 3)} / 3',
                                style: _text(12, color: ReferenceStyle.blue),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: server?.error != null
                                ? const SizedBox(height: 4)
                                : LinearProgressIndicator(
                                    value:
                                        server != null &&
                                            (server!.loading ||
                                                server!.error != null)
                                        ? null
                                        : math.min(
                                            (server?.workoutDays ??
                                                    model.workoutDays) /
                                                3,
                                            1,
                                          ),
                                    minHeight: 4,
                                    backgroundColor: AppColors.border,
                                  ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '주 3일 운동하기',
                            style: _text(11, color: ReferenceStyle.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
  bool _planned(DateTime date) => server?.planned(date) ?? model.planned(date);
  bool completedDay(DateTime day) => server == null
      ? model.completed.any((w) => sameDate(w.date, day))
      : server!.completedDates.contains(HomeViewModel.dateKey(day));
  Widget _refreshable(Widget child) => server == null
      ? child
      : RefreshIndicator(onRefresh: _refresh, child: child);
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
          AppIcon(icon, size: 20, color: ReferenceStyle.muted),
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
    final active = widget.model.active;
    reps = TextEditingController(
      text:
          '${active != null && active.reps > 0 ? active.reps : widget.exercise.reps}',
    );
    sets = TextEditingController(
      text:
          '${active != null && active.sets > 0 ? active.sets : widget.exercise.sets}',
    );
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
