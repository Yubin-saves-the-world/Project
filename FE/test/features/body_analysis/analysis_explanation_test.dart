import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';
import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/body_analysis/presentation/analysis_dependencies.dart';
import 'package:fe/features/body_analysis/presentation/pages/analysis_run_page.dart';
import '../../fakes/fake_analysis_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';

void main() {
  test('관리자는 잔여 숫자가 0이어도 무제한이며 일반 계정 한도는 유지한다', () {
    final payload = <String, dynamic>{
      'used': 100,
      'limit': 0,
      'remaining': 0,
      'reset_at': '2026-10-29T00:00:00+09:00',
      'unlimited': true,
    };
    expect(AnalysisUsage.fromJson(payload).exhausted, isFalse);
    payload.remove('unlimited');
    payload['limit'] = 3;
    expect(AnalysisUsage.fromJson(payload).exhausted, isTrue);
  });

  testWidgets('측정 완료와 사진상 해석을 표시하고 미지원 루틴 버튼은 숨긴다', (tester) async {
    final result = BodyAnalysis.fromJson({
      'analysis_id': 31,
      'status': 'done',
      'created_at': '2026-10-28T17:17:00+09:00',
      'measurement_version': 'pixel-dino-v1',
      'summary': '이번 사진에서는 어깨선이 수평에 가깝게 측정됐습니다.',
      'measures': {'shoulder_tilt_deg': .4},
      'observations': [
        {
          'title': '어깨선',
          'label': '사진상 수평에 가까움',
          'description': '수평선과 약 0.40° 차이 납니다.',
        },
      ],
      'capabilities': {'routine_generation': false},
    });
    expect(result.canGenerateRoutines, isFalse);
    final repo = FakeAnalysisRepository()..response = result;
    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisRunPage(
          id: 31,
          dependencies: AnalysisDependencies(
            repository: repo,
            photos: FakePhotoRepository(),
            picker: FakePhotoPicker(),
            pending: MemoryAnalysisPendingStore(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('분석 요약'), findsOneWidget);
    expect(find.text('점수 산출 불가'), findsNothing);
    expect(find.text('체형을 분류하지 못했어요.'), findsNothing);
    expect(find.text('0.40°'), findsOneWidget);
    expect(find.text('맞춤 루틴 만들기'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
