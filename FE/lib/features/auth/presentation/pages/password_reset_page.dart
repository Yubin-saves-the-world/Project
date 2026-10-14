import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/validation/input_validators.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../data/password_reset_repository.dart';
import '../password_reset_view_model.dart';
import '../widgets/verification_sent_dialog.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({
    super.key,
    this.repository,
    this.initialToken,
    this.preview,
  });
  final PasswordResetRepository? repository;
  final String? initialToken;
  final bool? preview;
  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final emailForm = GlobalKey<FormState>();
  final resetForm = GlobalKey<FormState>();
  final email = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  late final PasswordResetViewModel model;
  Timer? timer;
  bool get preview => model.repository.isPreview;

  @override
  void initState() {
    super.initState();
    model = PasswordResetViewModel(
      widget.repository ??
          ((widget.preview ?? AppConfig.useLocalPreview)
              ? PreviewPasswordResetRepository()
              : ServerPasswordResetRepository(baseUrl: AppConfig.apiBaseUrl)),
      initialToken: widget.initialToken,
    );
    code.text = widget.initialToken ?? '';
    code.addListener(_inputChanged);
    password.addListener(_inputChanged);
  }

  void _inputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    code.dispose();
    password.dispose();
    if (widget.repository == null) model.repository.dispose();
    model.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RoutePaths.login);
    }
  }

  String? get _timeLeft {
    final remaining = model.verification.remaining;
    if (!preview || remaining == null) return null;
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _issue() async {
    FocusScope.of(context).unfocus();
    if (!emailForm.currentState!.validate()) return;
    if (!await model.request(email.text) || !mounted) return;
    code.clear();
    timer?.cancel();
    if (preview) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (model.verification.remaining == Duration.zero) timer?.cancel();
      });
    }
    await showVerificationSentDialog(
      context,
      email: email.text,
      preview: preview,
      code: preview,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (widget.initialToken == null && !emailForm.currentState!.validate()) {
      return;
    }
    final validCode = !preview || model.validateCode(email.text, code.text);
    if (!resetForm.currentState!.validate() || !validCode) return;
    final bool success;
    if (preview) {
      success = await model.resetWithCode(email.text, code.text, password.text);
    } else {
      model.openLink(code.text);
      if (model.step != PasswordResetStep.password) return;
      success = await model.reset(password.text, password.text);
    }
    if (success && mounted) {
      password.clear();
      code.clear();
      timer?.cancel();
    }
  }

  TextStyle _text(double size, {bool muted = false}) => ReferenceStyle.text(
    size,
    size * 1.5,
    color: muted ? ReferenceStyle.muted : ReferenceStyle.ink,
  );

  bool get _canSubmit =>
      !model.busy &&
      password.text.isNotEmpty &&
      code.text.isNotEmpty &&
      (!preview ||
          (model.verification.remaining != null &&
              model.verification.remaining != Duration.zero));

  Widget _complete() => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: ReferenceStyle.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          preview ? '비밀번호 변경 미리보기 완료' : '비밀번호가 변경됐어요',
                          textAlign: TextAlign.center,
                          style: ReferenceStyle.text(
                            20,
                            30,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          preview
                              ? '개발용 미리보기로, 실제 비밀번호는 변경되지 않았어요.'
                              : '새 비밀번호로 로그인해 주세요.',
                          textAlign: TextAlign.center,
                          style: _text(12, muted: true),
                        ),
                      ],
                    ),
                  ),
                ),
                ReferenceButton('로그인하러 가기', onPressed: _back),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      if (model.step == PasswordResetStep.complete) return _complete();
      return ReferencePage(
        alignment: Alignment.topCenter,
        backAsset: 'figma-655_782.svg',
        onBack: _back,
        builder: (context, width, height) => SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 96),
              Text(
                '비밀번호 찾기',
                textAlign: TextAlign.center,
                style: ReferenceStyle.text(24, 34, weight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(
                preview
                    ? '가입한 이메일로 인증번호를 보내드려요.\n번호를 확인한 뒤 새 비밀번호를 정해 주세요.'
                    : '가입한 이메일로 재설정 링크를 보내드려요.\n메일의 링크를 확인한 뒤 새 비밀번호를 정해 주세요.',
                textAlign: TextAlign.center,
                style: _text(12, muted: true),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Form(
                      key: emailForm,
                      child: ReferenceField(
                        key: const Key('reset-email'),
                        label: '이메일',
                        controller: email,
                        hint: 'name@example.com',
                        validator: widget.initialToken == null
                            ? InputValidators.email
                            : null,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !model.busy,
                        onChanged: (_) {
                          model.emailChanged();
                          code.clear();
                          timer?.cancel();
                        },
                        labelTrailing: _timeLeft == null
                            ? null
                            : Text(
                                _timeLeft!,
                                style: ReferenceStyle.text(
                                  12,
                                  18,
                                  color: ReferenceStyle.blue,
                                ),
                              ),
                        suffix: TextButton(
                          onPressed: model.busy ? null : _issue,
                          style: TextButton.styleFrom(
                            textStyle: ReferenceStyle.text(12, 18),
                          ),
                          child: Text(
                            model.step == PasswordResetStep.sent
                                ? '재전송'
                                : preview
                                ? '인증번호 받기'
                                : '링크 받기',
                          ),
                        ),
                      ),
                    ),
                    if (model.step == PasswordResetStep.sent) ...[
                      const SizedBox(height: 8),
                      Text(
                        '메일이 보이지 않으면 스팸함도 확인해 주세요.',
                        style: _text(11, muted: true),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Form(
                      key: resetForm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReferenceField(
                            key: const Key('reset-code'),
                            label: preview ? '인증번호' : '재설정 링크',
                            controller: code,
                            hint: preview
                                ? '인증번호를 입력하세요.'
                                : '메일의 링크를 붙여 넣어 주세요',
                            enabled: !model.busy,
                            keyboardType: preview
                                ? TextInputType.number
                                : TextInputType.url,
                            validator: (value) => preview
                                ? RegExp(r'^\d{6}$').hasMatch(value ?? '')
                                      ? null
                                      : '6자리 인증번호를 입력해 주세요.'
                                : PasswordResetViewModel.parseToken(
                                        value ?? '',
                                      ) !=
                                      null
                                ? null
                                : '메일의 재설정 링크를 확인해 주세요.',
                          ),
                          if (model.codeError != null ||
                              (preview && _timeLeft == '0:00')) ...[
                            const SizedBox(height: 6),
                            Text(
                              _timeLeft == '0:00'
                                  ? '인증번호가 만료됐어요. 다시 받아 주세요.'
                                  : model.codeError!,
                              style: ReferenceStyle.text(
                                11,
                                17,
                                color: Colors.red,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          ReferenceField(
                            key: const Key('reset-password'),
                            label: '새 비밀번호',
                            controller: password,
                            hint: '8자 이상 입력하세요.',
                            validator: InputValidators.password,
                            enabled: !model.busy,
                            obscure: true,
                            action: TextInputAction.done,
                            onSubmitted: (_) {
                              if (_canSubmit) _submit();
                            },
                          ),
                        ],
                      ),
                    ),
                    if (model.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        model.error!,
                        style: ReferenceStyle.text(12, 18, color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ReferenceButton(
                      '비밀번호 변경',
                      busy: model.busy,
                      onPressed: _canSubmit ? _submit : null,
                    ),
                    if (preview) ...[
                      const SizedBox(height: 12),
                      Text(
                        '개발용 미리보기 · 실제 메일 발송 및 비밀번호 변경 없음',
                        textAlign: TextAlign.center,
                        style: _text(10, muted: true),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
