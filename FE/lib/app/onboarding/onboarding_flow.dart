import 'package:flutter/material.dart';

import '../../core/media/image_picker_service.dart';
import '../../features/auth/data/onboarding_repository.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/consent_page.dart';
import '../../features/body_analysis/presentation/pages/onboarding_analysis_page.dart';
import '../../features/profile/presentation/pages/profile_form_page.dart';
import '../../ui/core/widgets/primary_button.dart';
import '../shell/main_shell.dart';
import 'onboarding_view_model.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.repository,
    required this.photoPicker,
    this.startWithLogin = false,
  });
  final OnboardingRepository repository;
  final PhotoPicker photoPicker;
  final bool startWithLogin;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final OnboardingViewModel _model;
  @override
  void initState() {
    super.initState();
    _model = OnboardingViewModel(
      repository: widget.repository,
      photoPicker: widget.photoPicker,
    );
    _model.initialize(startWithLogin: widget.startWithLogin);
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, child) {
      if (_model.loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (_model.showLogin) return LoginPage(model: _model);
      if (_model.progress.signedIn &&
          _model.progress.account != null &&
          !_model.progress.consentCompleted) {
        return ConsentPage(model: _model);
      }
      if (_model.progress.completed && _model.progress.signedIn) {
        return MainShell(
          onboarding: _model.progress,
          onLogout: _model.signOut,
          loggingOut: _model.busy,
          logoutError: _model.error,
        );
      }
      if (_model.error != null &&
          _model.progress.account == null &&
          _model.step == 0 &&
          !_model.busy &&
          _model.nickname.isEmpty) {
        // 저장소 장애는 새 가입으로 덮어쓰지 않고 복원 재시도를 제공한다.
        if (_model.error!.startsWith('저장된')) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_model.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: '다시 시도',
                      onPressed: () => _model.initialize(
                        startWithLogin: widget.startWithLogin,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_model.busy) {
            if (_model.step == 0) {
              _model.openLogin();
            } else {
              _model.back();
            }
          }
        },
        child: switch (_model.step) {
          0 => SignupPage(key: const ValueKey('signup'), model: _model),
          1 => ProfileFormPage(key: const ValueKey('profile'), model: _model),
          _ => OnboardingAnalysisPage(
            key: const ValueKey('analysis'),
            model: _model,
            onCompleted: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('설정이 완료됐어요. 환영합니다!')),
              );
            },
          ),
        },
      );
    },
  );
}
