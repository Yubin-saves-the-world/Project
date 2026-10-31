import '../widgets/analysis_debug_image.dart';
import '../../../routines/presentation/pages/routine_detail_page.dart';
import '../../../routines/presentation/pages/routine_week_page.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../data/models/body_analysis.dart';
import '../analysis_dependencies.dart';
import '../analysis_run_view_model.dart';
import '../widgets/analysis_result_overview.dart';

class AnalysisRunPage extends StatefulWidget {
  const AnalysisRunPage({
    super.key,
    required this.id,
    required this.dependencies,
  });
  final int id;
  final AnalysisDependencies dependencies;
  @override
  State<AnalysisRunPage> createState() => _AnalysisRunPageState();
}

class _AnalysisRunPageState extends State<AnalysisRunPage>
    with WidgetsBindingObserver {
  late final model = AnalysisRunViewModel(
    widget.dependencies.repository,
    widget.dependencies.pending,
    widget.id,
  )..resume();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (model.result?.status != AnalysisStatus.done &&
          model.result?.status != AnalysisStatus.failed) {
        model.resume();
      }
    } else {
      model.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('맞춤 루틴을 만들까요?'),
        content: const Text(
          '이 분석으로 앞으로의 추천 루틴을 새로 만들어요. 기존 추천 중 예정된 루틴은 교체되며, 직접 만든 일정과 완료 기록은 유지돼요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('만들기'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await model.generate();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => ManagementPage(
      title: '체형 분석',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (model.phase == AnalysisRunPhase.done)
            ..._result()
          else
            AnalysisPanel(
              children: [
                if (model.phase == AnalysisRunPhase.loading ||
                    model.phase == AnalysisRunPhase.pending) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 24),
                  Text(
                    '체형을 분석하고 있어요',
                    style: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
                  ),
                  const Text('잠시 기다려 주세요. 화면을 나가도 분석 기록에서 이어서 확인할 수 있어요.'),
                ] else ...[
                  Text(
                    switch (model.phase) {
                      AnalysisRunPhase.failed => '사진을 다시 확인해 주세요',
                      AnalysisRunPhase.timedOut => '분석이 조금 오래 걸리고 있어요',
                      AnalysisRunPhase.networkError => '연결을 확인해 주세요',
                      _ => '분석 상태를 확인해 주세요',
                    },
                    style: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    model.phase == AnalysisRunPhase.failed
                        ? analysisFailureMessage(
                            model.result?.errorCode,
                            model.result?.errorMessage,
                          )
                        : model.error ??
                              '같은 분석의 상태를 다시 확인하거나, 나중에 분석 기록에서 확인할 수 있어요.',
                  ),
                  const SizedBox(height: 24),
                  if ((model.accessCode == 'CONSENT_REQUIRED' ||
                          model.accessCode == 'ONBOARDING_REQUIRED') &&
                      widget.dependencies.onAccessRequired != null)
                    TextButton(
                      onPressed: widget.dependencies.onAccessRequired,
                      child: const Text('동의·신체정보 확인'),
                    ),
                  if (model.phase != AnalysisRunPhase.failed)
                    ReferenceButton('다시 확인', onPressed: model.resume),
                  if (model.phase == AnalysisRunPhase.failed)
                    ReferenceButton(
                      '사진 다시 선택',
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ],
            ),
        ],
      ),
    ),
  );
  List<Widget> _result() {
    final result = model.result!;
    final hasExplanation = result.observations.isNotEmpty;
    if (hasExplanation && result.measurementVersion == 'pixel-dino-v1') {
      return [AnalysisResultOverview(result: result)];
    }
    return [
      AnalysisPanel(
        children: [
          Text(
            '분석 결과',
            style: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            hasExplanation
                ? '사진 측정 완료'
                : result.score == null
                ? '점수 산출 불가'
                : '${result.score}점',
            style: ReferenceStyle.text(30, 39, color: ReferenceStyle.blue),
          ),
          Text(
            hasExplanation
                ? result.summary ?? '이번 사진의 측정값을 확인해 보세요.'
                : result.bodyType ?? '체형을 분류하지 못했어요.',
          ),
          if (hasExplanation) ...[
            const SizedBox(height: 12),
            const Text(
              '균형 점수와 근육 발달 등급은 아직 제공하지 않아요.',
              style: TextStyle(color: ReferenceStyle.muted),
            ),
          ],
          if (result.measurementVersion == 'stub-v0')
            const Text(
              '현재 서버의 시험용 분석 결과예요.',
              style: TextStyle(color: ReferenceStyle.muted),
            ),
        ],
      ),
      if (hasExplanation) ...[
        const SizedBox(height: 16),
        AnalysisPanel(
          children: [
            Text(
              '이번 사진에서 확인한 내용',
              style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
            ),
            for (final item in result.observations)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.title} · ${item.label}',
                      style: ReferenceStyle.text(
                        15,
                        22,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item.description),
                  ],
                ),
              ),
            if (result.interpretationNote case final note?) ...[
              const SizedBox(height: 16),
              Text(note, style: const TextStyle(color: ReferenceStyle.muted)),
            ],
          ],
        ),
      ],
      const SizedBox(height: 16),
      AnalysisPanel(
        children: [
          Text(
            '체형 측정',
            style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
          ),
          for (final (key, label, unavailableKey) in const [
            ('shoulder_tilt_deg', '어깨 기울기', 'shoulder_tilt'),
            ('pelvis_tilt_deg', '골반 기울기', 'pelvis_tilt'),
            ('neck_forward_deg', '목 전방 기울기', 'neck_forward'),
            ('shoulder_hip_ratio', '어깨·골반 비율', 'shoulder_hip_ratio'),
            ('torso_leg_ratio', '상체·다리 비율', 'torso_leg_ratio'),
          ])
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(
                    result.measures[key] == null
                        ? measurementReason(
                            result.unavailable[unavailableKey] ??
                                result.unavailable[key],
                          )
                        : '${result.measures[key]!.toStringAsFixed(1)}${key.endsWith('_deg') ? '°' : ''}',
                    style: ReferenceStyle.text(
                      14,
                      21,
                      color: ReferenceStyle.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      if (!hasExplanation && result.dinoParts.isNotEmpty) ...[
        const SizedBox(height: 16),
        AnalysisPanel(
          children: [
            Text(
              '이미지 특징 분석',
              style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
            ),
            for (final part in result.dinoParts)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${part.part == 'left_upper_arm' ? '왼쪽 상완' : '오른쪽 상완'} · '
                  '${part.status == 'extracted' ? '특징 추출 완료' : '평가 불가'}',
                ),
              ),
            const SizedBox(height: 12),
            const Text('사진 특징을 추출한 결과이며, 근육 발달 등급은 아직 판정하지 않아요.'),
          ],
        ),
      ],
      if (hasExplanation && result.nextSteps.isNotEmpty) ...[
        const SizedBox(height: 16),
        AnalysisPanel(
          children: [
            Text(
              '다음 확인 방법',
              style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
            ),
            for (final step in result.nextSteps)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(step),
              ),
          ],
        ),
      ],
      if (result.debugImageBase64 case final encoded?) ...[
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('관절 검출 이미지 보기'),
          children: [
            SizedBox(
              height: 360,
              child: AnalysisDebugImage(
                encoded: encoded,
                semanticLabel: '관절 및 실루엣 검출 참고 이미지',
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('관절 위치를 확인하기 위한 참고 이미지입니다.'),
            ),
          ],
        ),
      ],
      const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text(
          '사진 기반 참고 분석이며 의료적 진단이 아닙니다.',
          style: TextStyle(color: ReferenceStyle.muted),
        ),
      ),
      if (!hasExplanation && result.judgements.isNotEmpty) ...[
        const SizedBox(height: 16),
        AnalysisPanel(
          children: [
            Text(
              '자세 확인',
              style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
            ),
            for (final item in result.judgements)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${item.label} · ${switch (item.level) {
                    'good' => '양호',
                    'caution' => '확인 필요',
                    _ => '판정 불가',
                  }}'
                  '${item.value == null ? '\n${measurementReason(item.reason)}' : ' (${item.value}${item.unit == 'deg' ? '°' : item.unit ?? ''})'}',
                ),
              ),
          ],
        ),
      ],
      if (result.comparison case final comparison?) ...[
        const SizedBox(height: 16),
        AnalysisPanel(
          children: [
            Text(
              '목표 체형 비교',
              style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
            ),
            Text(comparison.summary),
            Text(comparison.detail),
            if (comparison.parts.isNotEmpty)
              Text('우선 운동 부위: ${comparison.parts.join(', ')}'),
          ],
        ),
      ],
      const SizedBox(height: 24),
      if (result.canGenerateRoutines && model.routines == null)
        ReferenceButton(
          '맞춤 루틴 만들기',
          onPressed: _generate,
          busy: model.generating,
        ),
      if (model.routineError != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            model.routineError!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      if (model.routines != null) ...[
        Text(
          '추천 루틴',
          style: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
        ),
        if (model.routines!.isEmpty) const Text('생성된 추천 루틴이 없어요.'),
        if (widget.dependencies.routines != null && model.routines!.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => RoutineWeekPage(
                  repository: widget.dependencies.routines!,
                  exercises: widget.dependencies.exercises,
                  workouts: widget.dependencies.workouts,
                  date: DateTime.tryParse(model.routines!.first.date),
                  onAccessRequired: widget.dependencies.onAccessRequired,
                ),
              ),
            ),
            child: const Text('주간 루틴 보기'),
          ),

        for (final routine in model.routines!)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AnalysisPanel(
              children: [
                Text(
                  routine.date,
                  style: ReferenceStyle.text(
                    12,
                    18,
                    color: ReferenceStyle.muted,
                  ),
                ),
                Text(
                  routine.title,
                  style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
                ),
                for (final exercise in routine.items) Text(exercise),
                if (widget.dependencies.routines != null)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => RoutineDetailPage(
                          repository: widget.dependencies.routines!,
                          id: routine.id,
                          exercises: widget.dependencies.exercises,
                          workouts: widget.dependencies.workouts,
                          onAccessRequired:
                              widget.dependencies.onAccessRequired,
                        ),
                      ),
                    ),
                    child: const Text('루틴 상세 보기'),
                  ),
              ],
            ),
          ),
      ],
    ];
  }
}

class AnalysisPanel extends StatelessWidget {
  const AnalysisPanel({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ReferenceStyle.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}
