import 'package:flutter/widgets.dart';

import '../../core/media/image_picker_service.dart';
import '../../features/auth/data/local_onboarding_repository.dart';
import '../../features/auth/data/onboarding_repository.dart';
import '../onboarding/onboarding_flow.dart';
import '../shell/main_shell.dart';
import 'route_paths.dart';

abstract final class AppRouter {
  static Map<String, WidgetBuilder> routes({
    OnboardingRepository? repository,
    PhotoPicker? photoPicker,
  }) => {
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
