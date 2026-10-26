import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
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
    this.apiClient,
  });
  final PasswordResetRepository? repository;
  final String? initialToken;
  final bool? preview;
  final ApiClient? apiClient;
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
  bool get codeMode => preview || widget.initialToken == null;

  @override
  void initState() {
    super.initState();
    model = PasswordResetViewModel(
      widget.repository ??
          ((widget.preview ?? AppConfig.useLocalPreview)
              ? PreviewPasswordResetRepository()
              : ServerPasswordResetRepository(
                  baseUrl: AppConfig.apiBaseUrl,
                  apiClient: widget.apiClient,
                )),
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
    if (remaining == null) return null;
    final seconds = (remaining.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _startCountdown() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if ((model.verification.remaining == null ||
              model.verification.remaining == Duration.zero) &&
          model.verification.retryAfter(email.text) == Duration.zero) {
        timer?.cancel();
      }
    });
  }

  Future<void> _issue() async {
    FocusScope.of(context).unfocus();
    if (!emailForm.currentState!.validate()) return;
    final sent = await model.request(email.text);
    if (!mounted) return;
    if (!sent) {
      emailForm.currentState!.validate();
      return;
    }
    code.clear();
    _startCountdown();
    await showVerificationSentDialog(
      context,
      email: email.text,
      code: codeMode,
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
    } else if (codeMode) {
      success = await model.resetWithServerCode(
        email.text,
        code.text,
        password.text,
      );
    } else {
      model.openLink(code.text);
      if (model.step != PasswordResetStep.password) return;
      success = await model.reset(password.text, password.text);
    }
    if (!mounted) return;
    resetForm.currentState!.validate();
    if (success) {
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
      (!codeMode ||
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
                          preview ? '비밀번호 변경 요청 완료' : '비밀번호가 변경됐어요',
                          textAlign: TextAlign.center,
                          style: ReferenceStyle.text(
                            20,
                            30,
                            weight: FontWeight.w500,
                          ),
                        ),
                        if (!preview) ...[
                          const SizedBox(height: 12),
                          Text(
                            '새 비밀번호로 로그인해 주세요.',
                            textAlign: TextAlign.center,
                            style: _text(12, muted: true),
                          ),
                        ],
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
                codeMode
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
                        errorText: model.fieldErrors['email'],
                        hint: 'name@example.com',
                        validator: widget.initialToken == null
                            ? (value) =>
                                  InputValidators.email(value) ??
                                  model.fieldErrors['email']
                            : null,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !model.busy,
                        onChanged: (_) {
                          model.emailChanged();
                          code.clear();
                          timer?.cancel();
                          if (model.verification.retryAfter(email.text) !=
                              Duration.zero) {
                            _startCountdown();
                          }
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
                          onPressed:
                              model.busy ||
                                  (model.verification.retryAfter(email.text) !=
                                      Duration.zero)
                              ? null
                              : _issue,
                          style: TextButton.styleFrom(
                            textStyle: ReferenceStyle.text(12, 18),
                          ),
                          child: Text(
                            model.verification.retryAfter(email.text) !=
                                    Duration.zero
                                ? '${(model.verification.retryAfter(email.text).inMilliseconds / 1000).ceil()}초 후 재요청'
                                : model.step == PasswordResetStep.sent
                                ? '재전송'
                                : codeMode
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
                            label: codeMode ? '인증번호' : '재설정 링크',
                            controller: code,
                            onChanged: (_) => model.clearFieldError('code'),
                            hint: codeMode
                                ? '인증번호를 입력하세요.'
                                : '메일의 링크를 붙여 넣어 주세요',
                            enabled: !model.busy,
                            keyboardType: codeMode
                                ? TextInputType.number
                                : TextInputType.url,
                            validator: (value) => codeMode
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
                              (codeMode && _timeLeft == '0:00')) ...[
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
                            errorText: model.fieldErrors['new_password'],
                            onChanged: (_) =>
                                model.clearFieldError('new_password'),
                            hint: '8자 이상 입력하세요.',
                            validator: (value) =>
                                InputValidators.password(value) ??
                                model.fieldErrors['new_password'],
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
                    if (model.error != null &&
                        model.error != model.codeError &&
                        !model.fieldErrors.containsValue(model.error)) ...[
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
