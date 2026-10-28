import '../../../workout/presentation/pages/workout_page.dart';
import '../../../workout/presentation/workout_dependencies.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../body_analysis/presentation/pages/analysis_run_page.dart'
    show AnalysisPanel;
import '../../data/exercise_repository.dart';
import '../../data/models/exercise.dart';

class ExerciseDetailPage extends StatefulWidget {
  const ExerciseDetailPage({
    super.key,
    required this.repository,
    required this.id,
    this.onAccessRequired,
    this.workouts,
    this.openMedia,
    this.localPreview = false,
  });
  final ExerciseRepository repository;
  final int id;
  final VoidCallback? onAccessRequired;
  final WorkoutDependencies? workouts;
  final Future<bool> Function(Uri)? openMedia;
  final bool localPreview;
  @override
  State<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  Exercise? _exercise;
  String? _error, _mediaError, _accessCode;
  bool _loading = true, _opening = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _accessCode = null;
    });
    try {
      final exercise = await widget.repository.detail(widget.id);
      if (mounted) setState(() => _exercise = exercise);
    } catch (e) {
      _accessCode = e is ApiRequestError ? e.code : null;
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : '종목 정보를 불러오지 못했어요.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    final uri = _exercise?.mediaUri;
    if (uri == null || _opening) return;
    setState(() {
      _opening = true;
      _mediaError = null;
    });
    try {
      final success =
          await (widget.openMedia ??
              (uri) =>
                  launchUrl(uri, mode: LaunchMode.externalApplication))(uri);
      if (!success && mounted) {
        setState(() => _mediaError = '영상을 열지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    } catch (_) {
      if (mounted) setState(() => _mediaError = '영상을 열지 못했어요. 연결할 앱을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ManagementPage(
    title: '운동 정보',
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null) ...[
          if (_accessCode == 'ONBOARDING_REQUIRED' &&
              widget.onAccessRequired != null)
            TextButton(
              onPressed: widget.onAccessRequired,
              child: const Text('신체정보 확인'),
            ),
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('다시 시도')),
        ] else if (_exercise case final exercise?) ...[
          if (widget.localPreview)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '로컬 미리보기 · 팀의 예시 종목 데이터',
                style: TextStyle(color: ReferenceStyle.muted),
              ),
            ),
          AnalysisPanel(
            children: [
              Text(
                exercise.name,
                style: ReferenceStyle.text(24, 32, weight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(
                '${exercise.partLabel} · ${exercise.equipmentLabel} · ${exercise.difficultyLabel}',
                style: ReferenceStyle.text(14, 21, color: ReferenceStyle.muted),
              ),
              const SizedBox(height: 20),
              Text(
                exercise.setsLabel,
                style: ReferenceStyle.text(18, 26, color: ReferenceStyle.blue),
              ),
              const SizedBox(height: 4),
              Text(
                '운동 기간에 따른 권장 세트예요.',
                style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnalysisPanel(
            children: [
              Text(
                '운동 방법',
                style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(
                exercise.description?.trim().isNotEmpty == true
                    ? exercise.description!
                    : '등록된 운동 설명이 없어요.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (exercise.mediaUri != null)
            ReferenceButton('시범 영상 보기', onPressed: _open, busy: _opening)
          else
            Text(
              exercise.mediaUrl == null
                  ? '등록된 시범 영상이 없어요.'
                  : '시범 영상 주소를 확인할 수 없어요.',
              style: ReferenceStyle.text(14, 21, color: ReferenceStyle.muted),
            ),
          if (widget.workouts != null) ...[
            const SizedBox(height: 16),
            ReferenceButton(
              '이 운동 시작',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => WorkoutPage(
                    dependencies: widget.workouts!,
                    exerciseId: exercise.id,
                  ),
                ),
              ),
            ),
          ],
          if (_mediaError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _mediaError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ],
    ),
  );
}
