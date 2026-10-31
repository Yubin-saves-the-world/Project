import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';
import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/body_analysis/presentation/analysis_run_view_model.dart';
import 'package:fe/features/body_analysis/presentation/widgets/analysis_debug_image.dart';
import '../../fakes/fake_analysis_repository.dart';

void main() {
  testWidgets('잘못된 base64가 있어도 화면을 중단하지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AnalysisDebugImage(
          encoded: '%%invalid%%',
          semanticLabel: '검출 이미지',
        ),
      ),
    );
    expect(find.text('이미지를 표시하지 못했어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('비유한 수치는 미측정으로 처리한다', () {
    final result = BodyAnalysis.fromJson({
      'analysis_id': 1,
      'status': 'done',
      'created_at': '2026-10-31T00:00:00+09:00',
      'measures': {
        'shoulder_tilt_deg': double.nan,
        'torso_leg_ratio': double.infinity,
      },
    });
    expect(result.measures['shoulder_tilt_deg'], isNull);
    expect(result.measures['torso_leg_ratio'], isNull);
  });

  test('미지원 루틴은 화면 밖 호출에서도 서버 요청을 보내지 않는다', () async {
    final repo = FakeAnalysisRepository()
      ..response = BodyAnalysis(
        id: 31,
        status: AnalysisStatus.done,
        createdAt: DateTime(2026),
        canGenerateRoutines: false,
      );
    final model = AnalysisRunViewModel(repo, MemoryAnalysisPendingStore(), 31);
    await model.resume();
    await model.generate();
    expect(repo.generated, 0);
    model.dispose();
  });

  testWidgets('90초 이내 서버 처리는 화면에서 조기에 시간 초과되지 않는다', (tester) async {
    final repo = FakeAnalysisRepository();
    final model = AnalysisRunViewModel(
      repo,
      MemoryAnalysisPendingStore(),
      31,
      now: tester.binding.clock.now,
    );
    await model.resume();
    await tester.pump(const Duration(seconds: 85));
    expect(model.phase, AnalysisRunPhase.pending);
    repo.response = result(AnalysisStatus.done);
    await tester.pump(const Duration(seconds: 2));
    expect(model.phase, AnalysisRunPhase.done);
    model.dispose();
  });
}
