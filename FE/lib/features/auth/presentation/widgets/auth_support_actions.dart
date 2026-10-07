import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';

void showAuthComingSoon(BuildContext context, String name) {
  FocusScope.of(context).unfocus();
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text('$name 준비 중'),
      content: Text(
        '$name 기능은 서버 연결 후 이용할 수 있어요. 현재는 이메일 가입과 기기 내 로그인 흐름을 테스트할 수 있습니다. 비밀번호 인증과 실제 메일 발송은 제공되지 않습니다.',
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

class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({
    super.key,
    this.enabled = true,
    this.signup = false,
  });
  final bool enabled, signup;
  Widget _button(BuildContext context, bool google) => SizedBox(
    height: 52,
    width: double.infinity,
    child: OutlinedButton(
      onPressed: enabled
          ? () => showAuthComingSoon(context, google ? '구글 로그인' : '카카오 로그인')
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
