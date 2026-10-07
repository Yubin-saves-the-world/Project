import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../app/onboarding/onboarding_view_model.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../photos/data/models/selected_photo.dart';
import '../../../photos/presentation/widgets/photo_input_field.dart';
import '../../data/models/analysis_input.dart';

class OnboardingAnalysisPage extends StatefulWidget {
  const OnboardingAnalysisPage({
    super.key,
    required this.model,
    required this.onCompleted,
  });
  final OnboardingViewModel model;
  final VoidCallback onCompleted;
  @override
  State<OnboardingAnalysisPage> createState() => _OnboardingAnalysisPageState();
}

class _OnboardingAnalysisPageState extends State<OnboardingAnalysisPage> {
  late final TextEditingController _text;
  OnboardingViewModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: model.analysis.text);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _select(PhotoSlot slot) async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null && mounted) await model.pickPhoto(slot, source);
  }

  Future<void> _photos({bool goal = false}) async {
    if (!goal) model.setMethod(AnalysisMethod.photo);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AnimatedBuilder(
        animation: model,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    goal ? '목표 체형 사진' : '분석할 사진',
                    style: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  for (final slot
                      in goal
                          ? [PhotoSlot.goal]
                          : [PhotoSlot.front, PhotoSlot.side])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: PhotoInputField(
                        key: Key('${slot.name}-photo'),
                        label: switch (slot) {
                          PhotoSlot.front => '정면',
                          PhotoSlot.side => '측면',
                          PhotoSlot.goal => '목표 체형',
                        },
                        photo: model.photoFor(slot),
                        requiredPhoto: slot == PhotoSlot.front,
                        enabled: model.bodyPhotoAgreed && !model.busy,
                        onSelect: () => _select(slot),
                        onRemove: () => model.removePhoto(slot),
                      ),
                    ),
                  if (model.error != null)
                    Text(
                      model.error!,
                      style: ReferenceStyle.text(12, 18, color: Colors.red),
                    ),
                  ReferenceButton(
                    '확인',
                    onPressed: model.busy ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _description() async {
    model.setMethod(AnalysisMethod.text);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '글로 설명하기',
                  style: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('analysis-text'),
                  controller: _text,
                  maxLength: 500,
                  maxLines: 5,
                  onChanged: model.setText,
                  decoration: const InputDecoration(
                    hintText: '체형이나 자세에 대한 고민을 적어 주세요.',
                  ),
                ),
                const SizedBox(height: 16),
                ReferenceButton('확인', onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    FocusScope.of(context).unfocus();
    if (await model.finish(prepareAnalysis: true) && mounted) {
      widget.onCompleted();
    }
  }

  Widget _svg(String id, double w, double h) =>
      SvgPicture.asset('assets/icons/figma/figma-$id.svg', width: w, height: h);
  Widget _card({required bool photo}) {
    final selected =
        model.analysis.method ==
        (photo ? AnalysisMethod.photo : AnalysisMethod.text);
    return InkWell(
      key: Key(photo ? 'analysis-photo-method' : 'analysis-text-method'),
      onTap: model.busy ? null : () => photo ? _photos() : _description(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? ReferenceStyle.blue : ReferenceStyle.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? ReferenceStyle.blue : ReferenceStyle.border,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: photo
                    ? _svg('521_55', 16.9, 14.2)
                    : SizedBox(
                        width: 14.9,
                        height: 14.9,
                        child: Stack(
                          children: [
                            _svg('521_58', 14.9, 14.9),
                            Positioned(
                              left: 9.6,
                              top: 2.8,
                              child: _svg('521_59', 2.5, 2.5),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 13,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        photo ? '사진으로 분석' : '글로 설명하기',
                        style: ReferenceStyle.text(
                          16,
                          24,
                          weight: FontWeight.w500,
                        ),
                      ),
                      if (photo)
                        Container(
                          width: 30,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ReferenceStyle.blue,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '추천',
                            style: ReferenceStyle.text(
                              9,
                              14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    photo
                        ? (model.analysis.front != null
                              ? '정면 사진 선택됨 · 눌러서 확인하기'
                              : '정면·측면 사진으로 좌우 균형까지 측정해요')
                        : (model.analysis.text.isNotEmpty
                              ? '몸 상태 입력됨 · 눌러서 수정하기'
                              : '사진 없이 내 몸 상태를 직접 적어요'),
                    style: ReferenceStyle.text(
                      12,
                      18,
                      color: ReferenceStyle.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guide() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ReferenceStyle.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SHOOTING GUIDE',
          style: ReferenceStyle.text(
            10,
            15,
            spacing: 1.3,
            color: ReferenceStyle.muted,
          ),
        ),
        const SizedBox(height: 12),
        for (final text in [
          '머리부터 발끝까지 전신이 나오게',
          '밝은 곳, 단색 벽 앞에서',
          '몸선이 보이는 옷으로',
        ])
          Padding(
            padding: EdgeInsets.only(bottom: text == '몸선이 보이는 옷으로' ? 0 : 12),
            child: Row(
              children: [
                Text(
                  '✓',
                  style: ReferenceStyle.text(
                    14,
                    21,
                    color: ReferenceStyle.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: ReferenceStyle.text(12, 18))),
              ],
            ),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ReferencePage(
    backAsset: 'figma-655_782.svg',
    footer: ReferenceButton('분석 시작', onPressed: _finish, busy: model.busy),
    onBack: model.busy ? null : model.back,
    builder: (context, width, height) => SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 96),
          const ReferenceTitle('체형 분석', sourceX: 151, sourceWidth: 109),
          const SizedBox(height: 43),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _card(photo: true),
                const SizedBox(height: 15),
                _card(photo: false),
                const SizedBox(height: 15),
                _guide(),
                const SizedBox(height: 15),
                InkWell(
                  onTap: model.busy ? null : () => _photos(goal: true),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 86),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ReferenceStyle.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '목표 체형 사진',
                                style: ReferenceStyle.text(
                                  14,
                                  21,
                                  weight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                model.analysis.goal == null
                                    ? '되고 싶은 몸 사진을 올리면 반영돼요 (선택)'
                                    : '목표 사진 선택됨 · 눌러서 확인하기',
                                style: ReferenceStyle.text(
                                  11,
                                  17,
                                  color: ReferenceStyle.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: ReferenceStyle.border,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 13,
                              height: 13,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 5.6,
                                    child: _svg('521_98', 2, 13),
                                  ),
                                  Positioned(
                                    top: 5.6,
                                    child: _svg('521_99', 13, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (model.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      model.error!,
                      style: ReferenceStyle.text(12, 18, color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
