import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../features/auth/data/server_onboarding_repository.dart';
import 'vitality_app.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    VitalityApp(
      onboardingRepository: AppConfig.useLocalPreview
          ? null
          : ServerOnboardingRepository(baseUrl: AppConfig.apiBaseUrl),
    ),
  );
}
