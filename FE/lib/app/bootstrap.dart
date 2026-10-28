import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../core/config/app_config.dart';
import '../features/auth/data/server_onboarding_repository.dart';
import 'router/route_paths.dart';
import 'vitality_app.dart';

void bootstrap() {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);
  final navigatorKey = GlobalKey<NavigatorState>();
  late final ServerOnboardingRepository repository;
  if (!AppConfig.useLocalPreview) {
    repository = ServerOnboardingRepository(
      baseUrl: AppConfig.apiBaseUrl,
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
