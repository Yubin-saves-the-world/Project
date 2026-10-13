import 'package:flutter/material.dart';

import '../../features/auth/data/models/onboarding_progress.dart';
import '../../features/body_analysis/presentation/pages/analysis_entry_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/workout/presentation/pages/workout_history_page.dart';
import 'app_bottom_nav.dart';
import '../../ui/core/widgets/app_scaffold.dart';
import '../../ui/core/widgets/empty_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialIndex = 0,
    this.onboarding,
    this.onLogout,
    this.loggingOut = false,
    this.logoutError,
  }) : assert(initialIndex >= 0 && initialIndex < 5);

  final int initialIndex;
  final OnboardingProgress? onboarding;
  final VoidCallback? onLogout;
  final bool loggingOut;
  final String? logoutError;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(
            onboarding: widget.onboarding,
            onLogout: widget.onLogout,
            loggingOut: widget.loggingOut,
            logoutError: widget.logoutError,
          ),
          const AnalysisEntryPage(),
          const WorkoutHistoryPage(),
          const AppScaffold(
            title: '인공지능 코치',
            body: EmptyView(
              title: '인공지능 코치 준비 중',
              description: '분석과 서버 연결 후 질문과 루틴 수정 제안을 받을 수 있어요.',
            ),
          ),
          const AppScaffold(
            title: '커뮤니티',
            body: EmptyView(
              title: '커뮤니티 준비 중',
              description: '게시글과 댓글 기능은 서비스 연결 후 제공됩니다.',
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}
