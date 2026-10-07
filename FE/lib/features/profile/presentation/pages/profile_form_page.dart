import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/onboarding/onboarding_view_model.dart';
import '../../../../core/validation/input_validators.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../data/models/body_profile.dart';

class ProfileFormPage extends StatefulWidget {
  const ProfileFormPage({super.key, required this.model});
  final OnboardingViewModel model;
  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _height, _weight, _age;
  bool _submitted = false;
  final _metricFocus = {
    for (final id in ['height', 'weight', 'age']) id: FocusNode(),
  };
  OnboardingViewModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    _height = TextEditingController(text: model.height);
    _weight = TextEditingController(text: model.weight);
    _age = TextEditingController(text: model.age);
  }

  @override
  void dispose() {
    for (final focus in _metricFocus.values) {
      focus.dispose();
    }
    _height.dispose();
    _weight.dispose();
    _age.dispose();
    super.dispose();
  }

  Widget _metric(
    String label,
    String unit,
    String hint,
    String id,
    TextEditingController controller,
    int min,
    int max, {
    bool integer = false,
  }) => Expanded(
    child: GestureDetector(
      key: Key('profile-$id-card'),
      behavior: HitTestBehavior.opaque,
      onTap: model.busy ? null : () => _metricFocus[id]!.requestFocus(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ReferenceStyle.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: ReferenceStyle.text(11, 17, color: ReferenceStyle.muted),
            ),
            const SizedBox(height: 5),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) => LayoutBuilder(
                builder: (context, c) {
                  final painter = TextPainter(
                    text: TextSpan(
                      text: controller.text.isEmpty ? hint : controller.text,
                      style: ReferenceStyle.text(
                        23,
                        35,
                        weight: FontWeight.w500,
                      ),
                    ),
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  return Stack(
                    children: [
                      TextFormField(
                        key: Key('profile-$id'),
                        controller: controller,
                        focusNode: _metricFocus[id],
                        onChanged: (value) {
                          switch (id) {
                            case 'height':
                              model.height = value;
                            case 'weight':
                              model.weight = value;
                            case 'age':
                              model.age = value;
                          }
                        },
                        enabled: !model.busy,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: !integer,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            integer ? RegExp('[0-9]') : RegExp('[0-9.]'),
                          ),
                        ],
                        style: ReferenceStyle.text(
                          23,
                          35,
                          weight: FontWeight.w500,
                        ),
                        validator: (v) => InputValidators.metric(
                          v,
                          label: label,
                          min: min,
                          max: max,
                          integer: integer,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          hintText: hint,
                          hintStyle: ReferenceStyle.text(
                            23,
                            35,
                            weight: FontWeight.w500,
                            color: ReferenceStyle.muted,
                          ),
                          errorMaxLines: 3,
                          errorStyle: ReferenceStyle.text(
                            10,
                            14,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      Positioned(
                        left: math.min(
                          painter.width + 7,
                          math.max(0, c.maxWidth - 20),
                        ),
                        top: 14,
                        child: IgnorePointer(
                          child: Text(
                            unit,
                            style: ReferenceStyle.text(
                              11,
                              17,
                              color: ReferenceStyle.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _section<T>(
    String label,
    List<T> values,
    T? selected,
    String Function(T) name,
    ValueChanged<T> change,
  ) => Padding(
    padding: const EdgeInsets.only(top: 21),
    child: FormField<T>(
      key: ValueKey('profile-choice-$label'),
      initialValue: selected,
      validator: (value) => values.contains(value)
          ? null
          : '$label${label == '주 운동 횟수' ? '를' : '을'} 선택해 주세요.',
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ReferenceStyle.text(15, 21, weight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    selected: field.value == values[i],
                    button: true,
                    child: InkWell(
                      onTap: model.busy
                          ? null
                          : () {
                              field.didChange(values[i]);
                              change(values[i]);
                              if (_submitted) field.validate();
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          vertical: 11,
                          horizontal: 2,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: field.value == values[i]
                              ? ReferenceStyle.blue
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: field.value == values[i]
                                ? ReferenceStyle.blue
                                : ReferenceStyle.border,
                          ),
                        ),
                        child: Text(
                          name(values[i]),
                          textAlign: TextAlign.center,
                          style: ReferenceStyle.text(
                            13,
                            20,
                            weight: FontWeight.w500,
                            color: field.value == values[i]
                                ? Colors.white
                                : ReferenceStyle.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  field.errorText!,
                  style: ReferenceStyle.text(11, 17, color: Colors.red),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  void _submit() {
    FocusScope.of(context).unfocus();
    model.height = _height.text;
    model.weight = _weight.text;
    model.age = _age.text;
    setState(() => _submitted = true);
    if (_form.currentState!.validate()) model.submitProfile();
  }

  @override
  Widget build(BuildContext context) => ReferencePage(
    backAsset: 'figma-655_776.svg',
    footer: ReferenceButton('다음', onPressed: _submit, busy: model.busy),
    onBack: model.busy ? null : model.back,
    builder: (context, width, height) => SizedBox(
      width: width,
      child: Form(
        key: _form,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 96),
            const ReferenceTitle('신체 정보', sourceX: 151, sourceWidth: 109),
            const SizedBox(height: 43),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metric('키', 'cm', '170', 'height', _height, 100, 250),
                      const SizedBox(width: 10),
                      _metric('몸무게', 'kg', '65', 'weight', _weight, 30, 250),
                      const SizedBox(width: 10),
                      _metric(
                        '나이',
                        '세',
                        '18',
                        'age',
                        _age,
                        10,
                        100,
                        integer: true,
                      ),
                    ],
                  ),
                  _section(
                    '성별',
                    [Gender.male, Gender.female],
                    model.gender,
                    (v) => v == Gender.male ? '남' : '여',
                    (v) => model.updateProfile(gender: v),
                  ),
                  _section(
                    '운동 목적',
                    GoalType.values,
                    model.goalType,
                    (v) => v.label,
                    (v) => model.updateProfile(goal: v),
                  ),
                  _section(
                    '주 운동 횟수',
                    [1, 3, 5, 7],
                    model.frequency,
                    (v) =>
                        {1: '0 ~ 1회', 3: '2 ~ 3회', 5: '4 ~ 5회', 7: '6~7회'}[v]!,
                    (v) => model.updateProfile(frequency: v),
                  ),
                  _section(
                    '운동 기간',
                    ExperienceLevel.values,
                    model.experienceLevel,
                    (v) => v.label,
                    (v) => model.updateProfile(experience: v),
                  ),
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
    ),
  );
}
