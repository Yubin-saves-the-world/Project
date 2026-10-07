import 'package:flutter/material.dart';
import '../../../../app/onboarding/onboarding_view_model.dart';
import '../../../../core/validation/input_validators.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../widgets/auth_support_actions.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.model});
  final OnboardingViewModel model;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _submitted = false;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.model.busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_form.currentState!.validate()) return;
    final ok = await widget.model.login(_email.text, _password.text);
    if (mounted && ok) _password.clear();
  }

  @override
  Widget build(BuildContext context) => ReferencePage(
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
              const ReferenceTitle(
                '이재 3 대 500',
                sourceX: 113,
                sourceWidth: 168,
              ),
              const SizedBox(height: 73),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ReferenceField(
                      key: const Key('login-email'),
                      label: '이메일',
                      controller: _email,
                      hint: 'name@example.com',
                      validator: InputValidators.email,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !widget.model.busy,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                    ),
                    const SizedBox(height: 18),
                    ReferenceField(
                      key: const Key('login-password'),
                      label: '비밀번호',
                      controller: _password,
                      hint: '8자 이상 입력하세요.',
                      obscure: true,
                      enabled: !widget.model.busy,
                      action: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: (v) => v == null || v.isEmpty || v.length > 64
                          ? '비밀번호를 입력해 주세요 (1~64자).'
                          : null,
                      autofillHints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: 15),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => showAuthComingSoon(context, '비밀번호 찾기'),
                        child: Text(
                          '비밀번호 찾기',
                          style: ReferenceStyle.text(
                            15,
                            21,
                            weight: FontWeight.w500,
                            color: ReferenceStyle.blue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (widget.model.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          widget.model.error!,
                          style: ReferenceStyle.text(12, 18, color: Colors.red),
                        ),
                      ),
                    ReferenceButton(
                      '로그인',
                      key: const Key('login-submit'),
                      onPressed: _submit,
                      busy: widget.model.busy,
                    ),
                    const SizedBox(height: 23),
                    AuthSocialButtons(enabled: !widget.model.busy),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '계정이 없으신가요? ',
                          style: ReferenceStyle.text(
                            15,
                            17,
                            weight: FontWeight.w500,
                            color: ReferenceStyle.muted,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.model.busy
                              ? null
                              : widget.model.openSignup,
                          child: Text(
                            '회원가입',
                            style: ReferenceStyle.text(
                              15,
                              17,
                              weight: FontWeight.w500,
                              color: ReferenceStyle.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 143),
            ],
          ),
        ),
      ),
    ),
  );
}
