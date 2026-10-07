import 'package:flutter/material.dart';

import '../../../auth/data/models/onboarding_progress.dart';
import '../../../../ui/core/theme/app_colors.dart';
import '../../../../ui/core/widgets/app_scaffold.dart';
import '../../../../ui/core/widgets/empty_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.onboarding,
    this.onLogout,
    this.loggingOut = false,
    this.logoutError,
  });
  final OnboardingProgress? onboarding;
  final VoidCallback? onLogout;
  final bool loggingOut;
  final String? logoutError;

  @override
  Widget build(BuildContext context) {
    final progress = onboarding;
    if (progress != null) {
      return AppScaffold(
        title: '홈',
        actions: [
          if (onLogout != null)
            TextButton.icon(
              onPressed: loggingOut ? null : onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: Text(loggingOut ? '로그아웃 중' : '로그아웃'),
            ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (logoutError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '로그아웃하지 못했어요. 다시 시도해 주세요.',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            Text(
              '${progress.account!.nickname}님, 반가워요.',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(
              '${progress.profile!.goalType.label} · 주 ${progress.profile!.weeklyFrequency}회',
              style: const TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '내 설정',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '키 ${progress.profile!.heightCm}cm · 몸무게 ${progress.profile!.weightKg}kg',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress.analysisPrepared
                        ? '분석 입력이 저장됐어요. 서비스 연결 후 분석할 수 있어요.'
                        : '체형 분석은 나중에 시작할 수 있어요.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '현재는 기기 내 미리보기예요. 로그아웃하면 로그인 화면으로 돌아갑니다. 가입 정보와 기록은 유지됩니다.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    }
    return const AppScaffold(
      title: '홈',
      body: EmptyView(
        title: '홈 화면 개발 준비',
        description: '오늘의 루틴과 운동 기록을 연결할 화면입니다.',
      ),
    );
  }
}
