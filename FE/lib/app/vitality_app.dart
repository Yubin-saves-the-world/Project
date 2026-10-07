import 'package:flutter/material.dart';

import '../ui/core/theme/app_theme.dart';
import '../core/media/image_picker_service.dart';
import '../features/auth/data/onboarding_repository.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';

class VitalityApp extends StatelessWidget {
  const VitalityApp({
    super.key,
    this.initialRoute = RoutePaths.login,
    this.onboardingRepository,
    this.photoPicker,
  });

  final String initialRoute;
  final OnboardingRepository? onboardingRepository;
  final PhotoPicker? photoPicker;

  @override
  Widget build(BuildContext context) {
    final routes = AppRouter.routes(
      repository: onboardingRepository,
      photoPicker: photoPicker,
    );
    return MaterialApp(
      title: 'Project Vitality',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: initialRoute,
      routes: routes,
      onGenerateInitialRoutes: (route) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: route),
          builder: routes[route]!,
        ),
      ],
    );
  }
}
