import '../../../../ui/core/theme/app_colors.dart';
import '../../../../ui/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';

Future<void> showVerificationSentDialog(
  BuildContext context, {
  required String email,
  bool code = true,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(
                  Icons.mail_outline_rounded,
                  size: 26,
                  color: ReferenceStyle.blue,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              code ? '인증번호를 보냈어요' : '재설정 링크를 보냈어요',
              textAlign: TextAlign.center,
              style: ReferenceStyle.text(18, 27, weight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              code ? '아래 주소로 6자리 번호를 보냈어요.' : '가입된 이메일이라면 재설정 링크가 발송됩니다.',
              textAlign: TextAlign.center,
              style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
            ),
            const SizedBox(height: 6),
            Text(
              email.trim().toLowerCase(),
              textAlign: TextAlign.center,
              style: ReferenceStyle.text(14, 21, weight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _row('유효 시간', code ? '5분' : '30분'),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: ReferenceStyle.border),
                  ),
                  _row(code ? '입력 가능 횟수' : '링크 사용 횟수', code ? '5회' : '1회'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '메일이 보이지 않으면 스팸함도 확인해 주세요.',
              textAlign: TextAlign.center,
              style: ReferenceStyle.text(11, 17, color: ReferenceStyle.muted),
            ),
            const SizedBox(height: 20),
            ReferenceButton('확인', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    ),
  ),
);

Widget _row(String label, String value) => Row(
  children: [
    Expanded(
      child: Text(
        label,
        style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
      ),
    ),
    Text(value, style: ReferenceStyle.text(12, 18, weight: FontWeight.w500)),
  ],
);
