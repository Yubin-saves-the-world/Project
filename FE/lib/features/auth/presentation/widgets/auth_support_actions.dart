import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../data/oauth_service.dart';

void showAuthComingSoon(BuildContext context, String name) {
  FocusScope.of(context).unfocus();
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text('$name 준비 중'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({
    super.key,
    this.enabled = true,
    this.signup = false,
    this.onGoogle,
    this.onKakao,
  });
  final bool enabled, signup;
  final Future<void> Function(String idToken)? onGoogle;
  final Future<void> Function(String accessToken)? onKakao;

  Future<void> _handleGoogle(BuildContext context) async {
    final token = await OAuthService.signInWithGoogle();
    if (token == null) return;
    if (context.mounted) await onGoogle?.call(token);
  }

  Future<void> _handleKakao(BuildContext context) async {
    final token = await OAuthService.signInWithKakao();
    if (token == null) return;
    if (context.mounted) await onKakao?.call(token);
  }

  Widget _button(BuildContext context, bool google) => SizedBox(
    height: 52,
    width: double.infinity,
    child: OutlinedButton(
      onPressed: enabled
          ? () => google ? _handleGoogle(context) : _handleKakao(context)
          : null,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        side: const BorderSide(color: ReferenceStyle.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final style = ReferenceStyle.text(14, 21, weight: FontWeight.w500);
          final painter = TextPainter(
            text: TextSpan(text: '카카오로 계속하기', style: style),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          return SizedBox(
            width: painter.width + 32,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(
                    child: Image.asset(
                      'assets/icons/figma/figma-${signup ? (google ? '681_33' : '681_41') : (google ? '681_31' : '681_39')}.png',
                      width: 18,
                      height: google ? 18 : 16.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(google ? '구글로 계속하기' : '카카오로 계속하기', style: style),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ReferenceDivider(signup: signup),
      const SizedBox(height: 23),
      _button(context, true),
      const SizedBox(height: 10),
      _button(context, false),
    ],
  );
}
