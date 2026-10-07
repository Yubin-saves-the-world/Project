import 'package:flutter/material.dart';

import '../../features/auth/data/models/onboarding_progress.dart';
import '../../features/body_analysis/presentation/pages/analysis_entry_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/workout/presentation/pages/workout_history_page.dart';
import 'app_bottom_nav.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialIndex = 0,
    this.onboarding,
    this.onLogout,
    this.loggingOut = false,
    this.logoutError,
  }) : assert(initialIndex >= 0 && initialIndex < 3);

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
