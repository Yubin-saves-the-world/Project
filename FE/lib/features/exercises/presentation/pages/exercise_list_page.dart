import '../../../../ui/core/widgets/app_icon.dart';
import '../../../workout/presentation/workout_dependencies.dart';
import '../../../../ui/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../../ui/core/widgets/app_selection.dart';
import '../../data/exercise_repository.dart';
import '../../data/models/exercise.dart';
import '../exercise_list_view_model.dart';
import 'exercise_detail_page.dart';

class ExerciseListPage extends StatefulWidget {
  const ExerciseListPage({
    super.key,
    required this.repository,
    this.localPreview = false,
    this.onAccessRequired,
    this.workouts,
  });
  final ExerciseRepository repository;
  final bool localPreview;
  final VoidCallback? onAccessRequired;
  final WorkoutDependencies? workouts;
  @override
  State<ExerciseListPage> createState() => _ExerciseListPageState();
}

class _ExerciseListPageState extends State<ExerciseListPage> {
  late final model = ExerciseListViewModel(widget.repository)..load();
  final _search = TextEditingController();
  @override
  void dispose() {
    model.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _equipment() async {
    final value = await showAppSelection<String>(
      context,
      title: '운동 기구',
      selected: model.filter.equipment ?? '',
      options: [
        const AppSelectionOption('', '전체 기구'),
        for (final e in exerciseEquipment.entries)
          AppSelectionOption(e.key, e.value),
      ],
    );
    if (value != null && mounted) {
      model.change(model.filter.withEquipment(value.isEmpty ? null : value));
    }
  }

  Future<void> _difficulty() async {
    final value = await showAppSelection<int>(
      context,
      title: '운동 난이도',
      selected: model.filter.difficulty ?? 0,
      options: [
        const AppSelectionOption(0, '전체 난이도'),
        for (var i = 1; i <= 5; i++) AppSelectionOption(i, '난이도 $i 이하'),
      ],
    );
    if (value != null && mounted) {
      model.change(model.filter.withDifficulty(value == 0 ? null : value));
    }
  }

  void _reset() {
    _search.clear();
    model.change(const ExerciseFilter());
  }

  Widget _partChip(String? part, String label) {
    final selected = model.filter.part == part;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primarySoft,
      backgroundColor: Colors.white,
      checkmarkColor: ReferenceStyle.blue,
      labelStyle: ReferenceStyle.text(
        13,
        20,
        color: selected ? ReferenceStyle.blue : ReferenceStyle.ink,
      ),
      side: BorderSide(
        color: selected ? ReferenceStyle.blue : ReferenceStyle.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (_) => model.change(model.filter.withPart(part)),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => ManagementPage(
      title: '운동 종목',
      body: RefreshIndicator(
        onRefresh: model.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.localPreview)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          '로컬 미리보기 · 팀의 예시 종목 데이터',
                          style: TextStyle(color: ReferenceStyle.muted),
                        ),
                      ),
                    TextField(
                      key: const Key('exercise-search'),
                      controller: _search,
                      maxLength: 30,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => model.change(
                        model.filter.withQuery(value),
                        search: true,
                      ),
                      onSubmitted: (_) => model.load(),
                      decoration: InputDecoration(
                        hintText: '운동 이름 검색',
                        prefixIcon: const AppIcon(Icons.search_rounded),
                        counterText: '',
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '검색어 지우기',
                                onPressed: () {
                                  _search.clear();
                                  model.change(model.filter.withQuery(''));
                                },
                                icon: const AppIcon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    if (model.queryError != null)
                      Text(
                        model.queryError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _partChip(null, '전체'),
                        for (final part in exerciseParts.entries)
                          _partChip(part.key, part.value),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _equipment,
                          icon: const AppIcon(Icons.tune_rounded, size: 18),
                          label: Text(
                            exerciseEquipment[model.filter.equipment] ??
                                '전체 기구',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _difficulty,
                          child: Text(
                            model.filter.difficulty == null
                                ? '전체 난이도'
                                : '난이도 ${model.filter.difficulty} 이하',
                          ),
                        ),
                        if (model.filter.active)
                          TextButton(
                            onPressed: _reset,
                            child: const Text('초기화'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!model.loading && model.queryError == null)
                      Text(
                        '${model.total}개 종목',
                        style: ReferenceStyle.text(
                          12,
                          18,
                          color: ReferenceStyle.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final exercise = model.items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: ReferenceStyle.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ExerciseDetailPage(
                              repository: widget.repository,
                              id: exercise.id,
                              workouts: widget.workouts,
                              localPreview: widget.localPreview,
                              onAccessRequired: widget.onAccessRequired,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise.name,
                                      style: ReferenceStyle.text(
                                        16,
                                        24,
                                        weight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${exercise.partLabel} · ${exercise.equipmentLabel} · ${exercise.difficultyLabel}',
                                      style: ReferenceStyle.text(
                                        12,
                                        18,
                                        color: ReferenceStyle.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      exercise.setsLabel,
                                      style: ReferenceStyle.text(
                                        12,
                                        18,
                                        color: ReferenceStyle.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const AppIcon(
                                Icons.chevron_right_rounded,
                                color: ReferenceStyle.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }, childCount: model.items.length),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (model.loading || model.loadingMore)
                      const CircularProgressIndicator(),
                    if (!model.loading &&
                        model.items.isEmpty &&
                        model.error == null &&
                        model.queryError == null) ...[
                      const Text('조건에 맞는 운동이 없어요.'),
                      if (model.filter.active)
                        TextButton(
                          onPressed: _reset,
                          child: const Text('필터 초기화'),
                        ),
                    ],
                    if (model.error != null) ...[
                      Text(model.error!),
                      TextButton(
                        onPressed: model.items.isEmpty
                            ? model.load
                            : model.more,
                        child: const Text('다시 시도'),
                      ),
                    ],
                    if (model.accessCode == 'ONBOARDING_REQUIRED' &&
                        widget.onAccessRequired != null)
                      TextButton(
                        onPressed: widget.onAccessRequired,
                        child: const Text('신체정보 확인'),
                      ),
                    if (!model.loading &&
                        !model.loadingMore &&
                        model.hasMore &&
                        model.error == null)
                      TextButton(
                        onPressed: model.more,
                        child: const Text('더 보기'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
