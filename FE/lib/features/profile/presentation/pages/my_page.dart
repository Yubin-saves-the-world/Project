import 'package:flutter/material.dart';
import '../../../../core/media/image_picker_service.dart';
import '../../../../ui/core/theme/app_colors.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../auth/data/models/onboarding_progress.dart';
import '../../../photos/data/photo_repository.dart';
import '../../../photos/presentation/pages/photo_management_page.dart';
import '../../data/models/body_profile.dart';
import '../../data/profile_repository.dart';
import '../../../routines/data/routine_refresh_repository.dart';
import '../my_page_view_model.dart';
import 'profile_edit_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({
    super.key,
    required this.onboarding,
    required this.profileRepository,
    required this.photoRepository,
    required this.photoPicker,
    this.onProfileSaved,
    this.onOpenAnalysisHistory,
    this.onOpenGoal,
    this.onOpenExercises,
    this.onOpenRoutines,
    this.onLogout,
    this.routineRefreshRepository,
  });
  final OnboardingProgress onboarding;
  final ProfileRepository profileRepository;
  final RoutineRefreshRepository? routineRefreshRepository;
  final PhotoRepository photoRepository;
  final PhotoPicker photoPicker;
  final ValueChanged<BodyProfile>? onProfileSaved;
  final VoidCallback? onLogout;
  final VoidCallback? onOpenAnalysisHistory;
  final VoidCallback? onOpenGoal;
  final VoidCallback? onOpenExercises;
  final VoidCallback? onOpenRoutines;
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  late final model = MyPageViewModel(
    widget.profileRepository,
    profile: widget.onboarding.profile,
    routines: widget.routineRefreshRepository,
  )..load();
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    if (model.regenerating) return;
    final result = await Navigator.push<ProfileSaveResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileEditPage(repository: widget.profileRepository),
      ),
    );
    if (result == null || !mounted) return;
    model.apply(result);
    widget.onProfileSaved?.call(result.profile);
    if (result.routineRefreshRecommended) {
      final regenerate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('맞춤 루틴을 새로 만들까요?'),
          content: const Text(
            '바뀐 신체정보와 가장 최근에 완료한 분석으로 추천 루틴을 다시 만들어요. 직접 만든 일정은 유지돼요.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('새로 만들기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('나중에'),
            ),
          ],
        ),
      );
      if (regenerate == true && mounted) {
        final success = await model.regenerate();
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('추천 루틴을 새로 만들었어요.'),
              action: widget.onOpenRoutines == null
                  ? null
                  : SnackBarAction(
                      label: '보기',
                      onPressed: widget.onOpenRoutines!,
                    ),
            ),
          );
        } else {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('추천 루틴을 만들지 못했어요'),
              content: Text(model.error!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신체정보를 저장했어요.')));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('로그아웃할까요?'),
        content: const Text('다시 로그인하면 기록은 그대로 남아 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final logout = widget.onLogout;
      Navigator.pop(context);
      logout?.call();
    }
  }

  Widget _card(List<Widget> children) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.border),
          children[i],
        ],
      ],
    ),
  );
  Widget _row(
    String title,
    String value,
    VoidCallback action, {
    IconData? icon,
  }) => InkWell(
    onTap: action,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(title, style: ReferenceStyle.text(15, 22))),
          const SizedBox(width: 12),
          Flexible(
            fit: FlexFit.tight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: ReferenceStyle.text(13, 20, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.muted,
          ),
        ],
      ),
    ),
  );
  String _number(double n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final account = widget.onboarding.account;
      final p = model.profile;
      return ManagementPage(
        title: '마이페이지',
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _card([
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      foregroundColor: AppColors.primary,
                      child: Text(
                        account?.nickname.characters.firstOrNull ?? '나',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account?.nickname ?? '내 정보',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ReferenceStyle.text(
                              18,
                              26,
                              weight: FontWeight.w500,
                            ),
                          ),
                          if (account != null && account.email.isNotEmpty)
                            Text(
                              account.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ReferenceStyle.text(
                                12,
                                19,
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Text(
              '내 신체정보',
              style: ReferenceStyle.text(13, 20, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            if (model.loading || model.regenerating)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            if (model.error != null) ...[
              Text(
                model.error!,
                style: ReferenceStyle.text(13, 20, color: AppColors.error),
              ),
              TextButton(onPressed: model.load, child: const Text('다시 시도')),
            ],
            _card([
              _row(
                '신체정보',
                p == null
                    ? '입력하기'
                    : '${_number(p.heightCm)}cm · ${_number(p.weightKg)}kg · ${p.age}세',
                _edit,
              ),
              _row('운동 목적', p?.goalType.label ?? '입력하기', _edit),
              _row(
                '주 운동 횟수',
                p == null ? '입력하기' : '주 ${p.weeklyFrequency}회',
                _edit,
              ),
              _row('운동 기간', p?.experienceLevel.label ?? '입력하기', _edit),
            ]),
            const SizedBox(height: 24),
            Text(
              '계정',
              style: ReferenceStyle.text(13, 20, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            _card([
              if (widget.onOpenRoutines != null)
                _row(
                  '추천 루틴',
                  '',
                  widget.onOpenRoutines!,
                  icon: Icons.calendar_view_week_outlined,
                ),
              if (widget.onOpenExercises != null)
                _row(
                  '운동 종목',
                  '',
                  widget.onOpenExercises!,
                  icon: Icons.fitness_center_outlined,
                ),
              if (widget.onOpenGoal != null)
                _row(
                  '목표 체형',
                  '',
                  widget.onOpenGoal!,
                  icon: Icons.flag_outlined,
                ),
              if (widget.onOpenAnalysisHistory != null)
                _row(
                  '분석 기록',
                  '',
                  widget.onOpenAnalysisHistory!,
                  icon: Icons.analytics_outlined,
                ),
              _row(
                '사진 데이터 관리',
                '',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotoManagementPage(
                      repository: widget.photoRepository,
                      picker: widget.photoPicker,
                    ),
                  ),
                ),
                icon: Icons.photo_library_outlined,
              ),
              if (widget.onLogout != null)
                _row('로그아웃', '', _logout, icon: Icons.logout_rounded),
            ]),
          ],
        ),
      );
    },
  );
}
