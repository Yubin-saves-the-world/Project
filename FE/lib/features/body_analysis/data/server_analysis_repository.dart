import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import 'analysis_repository.dart';
import 'models/body_analysis.dart';

class ServerAnalysisRepository implements AnalysisRepository {
  ServerAnalysisRepository(this.api);
  final ApiClient api;
  @override
  Future<AnalysisTicket> start({
    required int photoId,
    int? sidePhotoId,
    int? goalId,
  }) async => AnalysisTicket.fromJson(
    (await api.send(
      'POST',
      ApiContract.photoAnalysis,
      body: {
        'photo_id': photoId,
        'side_photo_id': ?sidePhotoId,
        'goal_body_id': ?goalId,
      },
    ))!,
  );
  @override
  Future<AnalysisTicket> startText({
    required String text,
    int? goalId,
  }) async => AnalysisTicket.fromJson(
    (await api.send(
      'POST',
      ApiContract.textAnalysis,
      body: {
        'text': text,
        'goal_body_id': ?goalId,
      },
    ))!,
  );
  @override
  Future<BodyAnalysis> detail(int id) async => BodyAnalysis.fromJson(
    (await api.send('GET', ApiContract.bodyAnalysis(id)))!,
  );
  @override
  Future<AnalysisPageData> history({int page = 1}) async =>
      AnalysisPageData.fromJson(
        (await api.send(
          'GET',
          Uri(
            path: ApiContract.bodyAnalyses,
            queryParameters: {'page': '$page', 'page_size': '20'},
          ).toString(),
        ))!,
      );
  @override
  Future<AnalysisUsage?> usage() async => AnalysisUsage.fromJson(
    (await api.send('GET', ApiContract.analysisUsage))!,
  );
  @override
  Future<AnalysisGoal?> goal() async {
    try {
      return AnalysisGoal.fromJson(
        (await api.send('GET', ApiContract.goalBodies))!,
      );
    } on ApiRequestError catch (e) {
      if (e.code == 'GOAL_NOT_FOUND') return null;
      rethrow;
    }
  }

  @override
  Future<List<AnalysisRoutine>> generateRoutines(int analysisId) async {
    final json = (await api.send(
      'POST',
      ApiContract.routines,
      body: {'analysis_id': analysisId},
    ))!;
    return List.unmodifiable(
      (json['routines'] as List).map(
        (v) => AnalysisRoutine.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    );
  }
}
