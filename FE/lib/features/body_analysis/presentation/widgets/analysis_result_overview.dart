import 'analysis_debug_image.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../data/models/body_analysis.dart';

/// User-facing geometry summary. Never converts embeddings into muscle grades.
class AnalysisResultOverview extends StatelessWidget {
  const AnalysisResultOverview({super.key, required this.result});
  final BodyAnalysis result;

  String get _headline {
    final shoulder = result.measures['shoulder_tilt_deg'];
    final pelvis = result.measures['pelvis_tilt_deg'];
    if (shoulder != null &&
        pelvis != null &&
        shoulder.abs() <= 2.5 &&
        pelvis.abs() <= 2.5) {
      return '어깨·골반선이\n수평에 가까워요';
    }
    return '사진에서 확인한\n정렬과 비율이에요';
  }

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(
        '어깨선 기울기',
        result.measures['shoulder_tilt_deg'],
        '°',
        '수평선을 기준으로 좌우 어깨를 이은 선의 기울기예요.',
        angle: true,
      ),
      _Metric(
        '골반선 기울기',
        result.measures['pelvis_tilt_deg'],
        '°',
        '수평선을 기준으로 좌우 골반을 이은 선의 기울기예요.',
        angle: true,
      ),
      _Metric(
        '어깨 / 골반 너비',
        result.measures['shoulder_hip_ratio'],
        '배',
        '골반 너비를 1로 봤을 때의 어깨 너비예요. 관절 위치를 기준으로 계산해요.',
      ),
      _Metric(
        '상체 / 하체 길이',
        result.measures['torso_leg_ratio'],
        '배',
        '골반~발목 길이를 1로 봤을 때의 어깨~골반 길이예요.',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ReferenceStyle.blue.withValues(alpha: .12),
                const Color(0xFFF4F7FF),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: ReferenceStyle.blue.withValues(alpha: .15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.accessibility_new_rounded,
                      color: ReferenceStyle.blue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MOVID · BODY REPORT',
                          style: ReferenceStyle.text(
                            11,
                            17,
                            weight: FontWeight.w500,
                            color: ReferenceStyle.blue,
                            spacing: 1,
                          ),
                        ),
                        Text('분석 요약', style: ReferenceStyle.text(14, 21)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _headline,
                style: ReferenceStyle.text(
                  27,
                  38,
                  weight: FontWeight.w500,
                  color: ReferenceStyle.ink,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '정면 사진의 관절 위치로 정렬과 비율을 살펴봤어요. 수치의 의미와 다음 확인 방법을 함께 확인하세요.',
                style: ReferenceStyle.text(14, 22, color: ReferenceStyle.muted),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(
                    Icons.check_circle_outline_rounded,
                    '측정 ${metrics.where((m) => m.value != null).length}개 항목',
                  ),
                  const _Tag(Icons.photo_camera_outlined, '정면 사진 기준'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '01  부위별 측정 결과',
          style: ReferenceStyle.text(18, 26, weight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns =
                constraints.maxWidth >= 600 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.5;
            final width = twoColumns
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: width,
                    child: _MetricCard(metric: metric),
                  ),
              ],
            );
          },
        ),
        if (result.measures['neck_forward_deg'] == null) ...[
          const SizedBox(height: 12),
          _Surface(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: ReferenceStyle.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '목 전방 각도 · 이번 분석에서는 제공하지 않아요.',
                    style: ReferenceStyle.text(
                      13,
                      20,
                      color: ReferenceStyle.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '02  다음에는 이렇게 확인해 보세요',
                style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              const _Step(
                '1',
                '같은 조건으로 한 번 더 촬영',
                '카메라 높이·거리와 발 위치를 맞추고, 카메라가 기울지 않게 해 주세요.',
              ),
              const SizedBox(height: 12),
              const _Step(
                '2',
                '분석 기록에서 수치를 비교',
                '한 장의 수치보다 같은 조건에서 촬영한 결과가 반복되는지 확인해 보세요.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (result.debugImageBase64 case final encoded?)
          ExpansionTile(
            title: const Text('관절 위치 확인하기'),
            children: [
              SizedBox(
                height: 340,
                child: AnalysisDebugImage(
                  encoded: encoded,
                  semanticLabel: '사진에서 추정한 관절 위치',
                ),
              ),
            ],
          ),
        ExpansionTile(
          title: const Text('분석 범위와 기준'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '수치는 사진에서 추정한 관절 위치를 기준으로 해요. 옷·포즈·카메라 높이에 따라 달라지며 실제 신체 치수나 근육량은 아니에요.',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    result.interpretationNote ??
                        '사진상 기울기 구분은 설명용 임시 기준이며 정상·이상 판정이 아니에요.',
                  ),
                  const SizedBox(height: 10),
                  const Text('균형 점수·근육 발달 등급·개인별 운동 처방은 제공하지 않아요.'),
                  if (result.dinoParts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '상완 이미지 특징 추출: ${result.dinoParts.where((p) => p.status == 'extracted').length}/${result.dinoParts.length}개 영역 완료. 근육 등급 판정과는 별개예요.',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '사진 기반 참고 분석이며 의료적 진단이 아닙니다.',
          style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
        ),
      ],
    );
  }
}

class _Metric {
  const _Metric(
    this.title,
    this.value,
    this.unit,
    this.description, {
    this.angle = false,
  });
  final String title, unit, description;
  final num? value;
  final bool angle;
  String get label => value == null
      ? '미측정'
      : !angle
      ? '사진상 비율'
      : value!.abs() <= 2.5
      ? '사진상 수평에 가까움'
      : value!.abs() <= 5
      ? '사진상 기울기 관찰'
      : '촬영 자세 재확인';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;
  @override
  Widget build(BuildContext context) {
    final value = metric.value;
    final isWidth = metric.title.contains('너비');
    final icon = metric.angle
        ? Icons.horizontal_rule_rounded
        : isWidth
        ? Icons.swap_horiz_rounded
        : Icons.height_rounded;
    final meaning = value == null
        ? '사진에서 이 항목을 측정하지 못했어요.'
        : metric.angle
        ? value.abs() <= 2.5
              ? '좌우 관절을 이은 선의 기울기가 작게 나타났어요. 이 사진에서는 두 추정점이 비슷한 높이에 있어요.'
              : '좌우 관절을 이은 선의 기울기가 보여요. 몸에 한쪽으로 체중을 싣거나 카메라가 돌아가도 차이가 생길 수 있어요.'
        : isWidth
        ? '골반의 관절 간 너비를 100으로 두면 어깨는 약 ${(value * 100).round()}이에요. 관절 사이의 거리 비교이므로 근육 크기를 뜻하지는 않아요.'
        : '골반부터 발목까지를 100으로 두면 어깨부터 골반까지는 약 ${(value * 100).round()}이에요. 다리가 길거나 짧다는 체형 판정은 아니에요.';
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ReferenceStyle.blue.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: ReferenceStyle.blue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  metric.title,
                  style: ReferenceStyle.text(15, 24, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value == null ? '—' : '${value.toStringAsFixed(2)}${metric.unit}',
            style: ReferenceStyle.text(
              34,
              44,
              color: ReferenceStyle.blue,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ReferenceStyle.blue.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              metric.label,
              style: ReferenceStyle.text(12, 18, color: ReferenceStyle.blue),
            ),
          ),
          if (value != null && !metric.angle) ...[
            const SizedBox(height: 18),
            _RatioBars(
              value: value.toDouble(),
              firstLabel: isWidth ? '골반' : '하체',
              secondLabel: isWidth ? '어깨' : '상체',
            ),
          ],
          const SizedBox(height: 18),
          Divider(height: 1, color: ReferenceStyle.border),
          const SizedBox(height: 14),
          Text(
            '이 수치는 무엇인가요?',
            style: ReferenceStyle.text(12, 18, weight: FontWeight.w500),
          ),
          const SizedBox(height: 5),
          Text(
            metric.description,
            style: ReferenceStyle.text(13, 21, color: ReferenceStyle.muted),
          ),
          const SizedBox(height: 14),
          Text(
            '이번 사진에서는',
            style: ReferenceStyle.text(12, 18, weight: FontWeight.w500),
          ),
          const SizedBox(height: 5),
          Text(
            meaning,
            style: ReferenceStyle.text(13, 21, color: ReferenceStyle.muted),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .85),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: ReferenceStyle.blue),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: ReferenceStyle.text(12, 18))),
      ],
    ),
  );
}

class _RatioBars extends StatelessWidget {
  const _RatioBars({
    required this.value,
    required this.firstLabel,
    required this.secondLabel,
  });
  final double value;
  final String firstLabel, secondLabel;
  @override
  Widget build(BuildContext context) {
    final maxValue = value > 1 ? value : 1.0;
    return Column(
      children: [
        for (final entry in [(firstLabel, 1.0), (secondLabel, value)])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.$1,
                        style: ReferenceStyle.text(
                          11,
                          17,
                          color: ReferenceStyle.muted,
                        ),
                      ),
                    ),
                    Text(
                      '${(entry.$2 * 100).round()}',
                      style: ReferenceStyle.text(
                        11,
                        17,
                        color: ReferenceStyle.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (entry.$2 / maxValue).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: entry.$1 == firstLabel
                        ? const Color(0xFFB8C4EC)
                        : ReferenceStyle.blue,
                    backgroundColor: const Color(0xFFF0F3FA),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title, this.description);
  final String number, title, description;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ReferenceStyle.blue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(number, style: const TextStyle(color: ReferenceStyle.blue)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: ReferenceStyle.text(14, 21, weight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: ReferenceStyle.text(13, 20, color: ReferenceStyle.muted),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ReferenceStyle.border),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1B2B64).withValues(alpha: .025),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}
