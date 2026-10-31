import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/core/network/api_client.dart';
import 'package:fe/features/auth/data/token_store.dart';
import 'package:fe/features/photos/data/server_photo_repository.dart';
import 'package:fe/features/photos/data/models/body_photo.dart';
import 'package:fe/features/body_analysis/data/server_analysis_repository.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';

void main() {
  const image = String.fromEnvironment('LIVE_AI_IMAGE');
  const base = String.fromEnvironment(
    'LIVE_API_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );
  test(
    '실제 사진: Flutter 저장소 → Spring → FastAPI → DINOv3 → 결과 파싱',
    () async {
      final tokens = MemoryTokenStore();
      final api = ApiClient(baseUrl: base, tokenStore: tokens);
      addTearDown(api.dispose);
      final login = await api.send(
        'POST',
        '/api/auth/login',
        authorized: false,
        body: {'email': 'demo@movid.local', 'password': 'movid1234'},
      );
      await tokens.write(login!['access_token'] as String);
      final photos = ServerPhotoRepository(api);
      final analysis = ServerAnalysisRepository(api);
      final photo = await photos.upload(
        await File(image).readAsBytes(),
        type: BodyPhotoType.current,
        side: BodyPhotoSide.front,
      );
      final ticket = await analysis.start(photoId: photo.id);
      BodyAnalysis? result;
      for (var i = 0; i < 95; i++) {
        result = await analysis.detail(ticket.id);
        if (result.status != AnalysisStatus.pending) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(result!.status, AnalysisStatus.done, reason: result.errorMessage);
      expect(result.measures['shoulder_tilt_deg'], isNotNull);
      expect(result.dinoParts.length, 2);
      expect(result.dinoParts.every((p) => p.status == 'extracted'), isTrue);
      expect(result.debugImageBase64, isNotEmpty);
      expect(result.score, isNull);
      expect(
        (await analysis.history()).items.any((a) => a.id == ticket.id),
        isTrue,
      );
    },
    skip: image.isEmpty ? 'LIVE_AI_IMAGE 지정 시 실행' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
