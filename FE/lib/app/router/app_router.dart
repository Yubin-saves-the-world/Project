import 'package:flutter/material.dart';
import '../../features/auth/presentation/pages/password_reset_page.dart';

import '../../core/media/image_picker_service.dart';
import '../../features/auth/data/local_onboarding_repository.dart';
import '../../features/auth/data/onboarding_repository.dart';
import '../onboarding/onboarding_flow.dart';
import '../shell/main_shell.dart';
import 'route_paths.dart';

abstract final class AppRouter {
  static Route<void>? passwordResetRoute(
    RouteSettings settings, {
    OnboardingRepository? repository,
  }) {
    final uri = Uri.tryParse(settings.name ?? '');
    if (uri?.path != RoutePaths.passwordReset) return null;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => PasswordResetPage(
        initialToken: uri!.queryParameters['token'],
        preview: repository == null || repository is LocalOnboardingRepository,
      ),
    );
  }

  static Map<String, WidgetBuilder> routes({
    OnboardingRepository? repository,
    PhotoPicker? photoPicker,
  }) => {
    RoutePaths.passwordReset: (context) => PasswordResetPage(
      preview: repository == null || repository is LocalOnboardingRepository,
      initialToken: ModalRoute.of(context)?.settings.arguments as String?,
    ),
    RoutePaths.home: (_) => const MainShell(),
    RoutePaths.login: (_) => OnboardingFlow(
      repository: repository ?? LocalOnboardingRepository(),
      photoPicker: photoPicker ?? ImagePickerService(),
      startWithLogin: true,
    ),
    RoutePaths.signup: (_) => OnboardingFlow(
      repository: repository ?? LocalOnboardingRepository(),
      photoPicker: photoPicker ?? ImagePickerService(),
    ),
    RoutePaths.analysis: (_) => const MainShell(initialIndex: 1),
    RoutePaths.workouts: (_) => const MainShell(initialIndex: 2),
  };
}
