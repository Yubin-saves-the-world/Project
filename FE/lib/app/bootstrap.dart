import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../features/auth/data/token_store.dart';

import '../core/config/app_config.dart';
import '../features/auth/data/server_onboarding_repository.dart';
import 'router/route_paths.dart';
import 'vitality_app.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  final navigatorKey = GlobalKey<NavigatorState>();
  late final ServerOnboardingRepository repository;
  if (!AppConfig.useLocalPreview) {
    repository = ServerOnboardingRepository(
      baseUrl: AppConfig.apiBaseUrl,
      // Unsigned local macOS demo: keep the JWT only in memory, avoiding
      // Keychain entitlements that require an Apple development certificate.
      tokenStore:
          kDebugMode &&
              defaultTargetPlatform == TargetPlatform.macOS &&
              const bool.fromEnvironment('DESKTOP_DEMO')
          ? MemoryTokenStore()
          : null,
      onSessionExpired: () async {
        repository.clearSessionData();
        // The old routes own personal screen state; discard them on expiry.
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          RoutePaths.login,
          (_) => false,
        );
      },
    );
  }
  runApp(
    VitalityApp(
      navigatorKey: navigatorKey,
      onboardingRepository: AppConfig.useLocalPreview ? null : repository,
    ),
  );
}
