import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/body_analysis/data/analysis_repository.dart';
import 'package:fe/features/body_analysis/data/analysis_pending_store.dart';
import 'package:fe/features/body_analysis/data/models/analysis_input.dart';
import 'package:fe/features/body_analysis/data/models/body_analysis.dart';
import 'package:fe/features/body_analysis/presentation/analysis_dependencies.dart';
import 'package:fe/features/body_analysis/presentation/analysis_input_view_model.dart';
import '../../fakes/fake_analysis_repository.dart';
import '../../fakes/fake_onboarding_repository.dart';
import '../../fakes/fake_profile_photo_repositories.dart';

class TextRepository extends FakeAnalysisRepository
    implements TextAnalysisRepository {
  String? input;
  @override
  Future<AnalysisTicket> startText(String text) async {
    input = text;
    return const AnalysisTicket(32);
  }
}

void main() {
  test('글 분석은 공백·길이를 검증하고 사진 업로드 없이 요청하며 중복 시작을 막는다', () async {
    final repository = TextRepository();
    final photos = FakePhotoRepository();
    final pending = MemoryAnalysisPendingStore();
    final model = AnalysisInputViewModel(
      AnalysisDependencies(
        repository: repository,
        photos: photos,
        picker: FakePhotoPicker(),
        pending: pending,
        preparer: FakePhotoPreparer(),
      ),
    );
    addTearDown(model.dispose);
    model.setMethod(AnalysisMethod.text);
    model.setText('   ');
    expect(await model.finish(prepareAnalysis: true), isFalse);
    model.setText('a' * 501);
    expect(await model.finish(prepareAnalysis: true), isFalse);
    model.setText('  어깨가 자주 뻐근해요.  ');
    expect(await model.finish(prepareAnalysis: true), isTrue);
    expect(repository.input, '어깨가 자주 뻐근해요.');
    expect(repository.starts, 0);
    expect(photos.uploads, 0);
    expect(await pending.read(), 32);
    repository.input = null;
    expect(await model.finish(prepareAnalysis: true), isTrue);
    expect(repository.input, isNull);
  });
  test('글 분석 응답의 요약을 보존하며 사진 측정값을 생성하지 않는다', () {
    final result = BodyAnalysis.fromJson({
      'analysis_id': 32,
      'status': 'done',
      'created_at': '2026-10-28T10:00:00Z',
      'source': 'text',
      'text_summary': '어깨 주변의 긴장을 줄이는 운동이 필요해요.',
      'measures': null,
      'balance_score': null,
      'body_type': null,
      'judgements': [],
    });
    expect(result.source, 'text');
    expect(result.textSummary, '어깨 주변의 긴장을 줄이는 운동이 필요해요.');
    expect(result.score, isNull);
    expect(result.measures.values.every((value) => value == null), isTrue);
  });
}
