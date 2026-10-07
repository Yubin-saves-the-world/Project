import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/onboarding/onboarding_view_model.dart';
import '../../../../core/validation/input_validators.dart';
import '../../../../features/auth/data/development_email_verification.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../widgets/auth_support_actions.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.model});
  final OnboardingViewModel model;
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nickname, _email, _code, _password;
  bool _submitted = false;
  Timer? _countdown;
  String? get _timeLeft {
    final duration = model.emailVerification.remaining;
    if (duration == null) return null;
    final seconds = (duration.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  OnboardingViewModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: model.nickname);
    _email = TextEditingController(text: model.email);
    _code = TextEditingController(text: model.verificationCode);
    _password = TextEditingController(text: model.password);
    if (model.emailVerification.remaining != null) _startCountdown();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    for (final c in [_nickname, _email, _code, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (model.emailVerification.remaining == Duration.zero) {
        _countdown?.cancel();
      }
    });
  }

  void _issue() {
    model.email = _email.text;
    if (InputValidators.email(model.email) != null) {
      _form.currentState!.validate();
      return;
    }
    model.issueVerification();
    _startCountdown();
    setState(() {});
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('개발용 이메일 인증'),
        content: const Text(
          '실제 이메일은 발송되지 않습니다. 테스트 인증번호: ${DevelopmentEmailVerification.code}\n유효 시간은 5분이며, 5회 틀리면 다시 받아야 합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (model.busy) return;
    FocusScope.of(context).unfocus();
    model.nickname = _nickname.text;
    model.email = _email.text;
    model.password = _password.text;
    model.verificationCode = _code.text;
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    final verification =
        (model.progress.account != null && model.progress.signedIn)
        ? null
        : model.emailVerification.validate(_email.text, _code.text);
    if (verification != null) {
      model.showError(verification);
      return;
    }
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '필수 약관 동의',
                    style: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '현재는 기기 내 가입 미리보기입니다. 정식 약관·처리방침은 서비스 연결 전에 제공됩니다.',
                  ),
                  CheckboxListTile(
                    title: const Text('전체 동의'),
                    value:
                        model.termsAgreed &&
                        model.privacyAgreed &&
                        model.bodyPhotoAgreed &&
                        model.aiProcessingAgreed,
                    onChanged: (v) {
                      model.updateConsent(
                        terms: v,
                        privacy: v,
                        photo: v,
                        ai: v,
                      );
                      refresh(() {});
                    },
                  ),
                  for (final item in [
                    (
                      '서비스 이용약관 동의 (필수)',
                      model.termsAgreed,
                      (bool v) => model.updateConsent(terms: v),
                    ),
                    (
                      '개인정보 수집·이용 동의 (필수)',
                      model.privacyAgreed,
                      (bool v) => model.updateConsent(privacy: v),
                    ),
                    (
                      '신체 사진 수집·이용 동의 (필수)',
                      model.bodyPhotoAgreed,
                      (bool v) => model.updateConsent(photo: v),
                    ),
                    (
                      'AI 분석 처리 동의 (필수)',
                      model.aiProcessingAgreed,
                      (bool v) => model.updateConsent(ai: v),
                    ),
                  ])
                    CheckboxListTile(
                      title: Text(item.$1),
                      value: item.$2,
                      onChanged: (v) {
                        item.$3(v!);
                        refresh(() {});
                      },
                    ),
                  ReferenceButton(
                    '동의하고 계속',
                    onPressed:
                        model.termsAgreed &&
                            model.privacyAgreed &&
                            model.bodyPhotoAgreed &&
                            model.aiProcessingAgreed
                        ? () => Navigator.pop(context, true)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (accepted == true && mounted) await model.submitAccount();
  }

  @override
  Widget build(BuildContext context) => ReferencePage(
    backAsset: 'figma-655_768.svg',
    onBack: model.busy ? null : model.openLogin,
    builder: (context, width, height) => SizedBox(
      width: width,
      child: Form(
        key: _form,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 96),
              const ReferenceTitle('회원가입', sourceX: 151, sourceWidth: 102),
              const SizedBox(height: 38),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReferenceField(
                      signup: true,
                      key: const Key('signup-nickname'),
                      label: '닉네임',
                      controller: _nickname,
                      hint: '닉네임을 입력하세요.',
                      validator: InputValidators.nickname,
                      onChanged: (v) => model.nickname = v,
                      enabled: !model.busy,
                    ),
                    const SizedBox(height: 18),
                    ReferenceField(
                      signup: true,
                      key: const Key('signup-email'),
                      label: '이메일',
                      labelTrailing: _timeLeft == null
                          ? null
                          : Text(
                              _timeLeft!,
                              style: ReferenceStyle.text(
                                14,
                                21,
                                color: ReferenceStyle.blue,
                              ),
                            ),
                      controller: _email,
                      hint: 'name@example.com',
                      validator: InputValidators.email,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) {
                        if (model.email.trim().toLowerCase() !=
                            v.trim().toLowerCase()) {
                          model.emailVerification.clear();
                          model.verificationCode = '';
                          _code.clear();
                          _countdown?.cancel();
                        }
                        model.email = v;
                        setState(() {});
                      },
                      enabled: !model.busy,
                      suffix: TextButton(
                        onPressed: model.busy ? null : _issue,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: Text(
                          '인증번호 받기',
                          style: ReferenceStyle.text(
                            14,
                            21,
                            color: ReferenceStyle.blue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ReferenceField(
                      signup: true,
                      key: const Key('signup-code'),
                      label: '인증번호',
                      controller: _code,
                      hint: '인증번호를 입력하세요.',
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (model.progress.account != null &&
                              model.progress.signedIn)
                          ? null
                          : (v == null || v.length != 6
                                ? '인증번호 6자리를 입력해 주세요.'
                                : null),
                      onChanged: (v) => model.verificationCode = v,
                      enabled: !model.busy,
                    ),
                    const SizedBox(height: 18),
                    ReferenceField(
                      signup: true,
                      key: const Key('signup-password'),
                      label: '비밀번호',
                      controller: _password,
                      hint: '8자 이상 입력하세요.',
                      obscure: true,
                      validator: InputValidators.password,
                      onChanged: (v) => model.password = v,
                      enabled: !model.busy,
                      action: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 18),
                    if (model.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          model.error!,
                          style: ReferenceStyle.text(12, 18, color: Colors.red),
                        ),
                      ),
                    ReferenceButton('다음', onPressed: _submit, busy: model.busy),
                    const SizedBox(height: 23),
                    AuthSocialButtons(signup: true, enabled: !model.busy),
                  ],
                ),
              ),
              const SizedBox(height: 62),
            ],
          ),
        ),
      ),
    ),
  );
}
