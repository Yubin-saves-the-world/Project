import 'package:flutter/material.dart';
import '../../../../app/onboarding/onboarding_view_model.dart';
import '../../../../ui/core/theme/app_colors.dart';
import '../../../../ui/core/widgets/primary_button.dart';

class ConsentPage extends StatelessWidget {
  const ConsentPage({super.key, required this.model});
  final OnboardingViewModel model;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('필수 동의 확인')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '가입 정보를 유지하고 필수 동의를 확인해 주세요.',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: model.termsAgreed,
                  onChanged: model.busy
                      ? null
                      : (v) => model.updateConsent(terms: v),
                  title: const Text('[필수] 이용약관'),
                ),
                CheckboxListTile(
                  value: model.privacyAgreed,
                  onChanged: model.busy
                      ? null
                      : (v) => model.updateConsent(privacy: v),
                  title: const Text('[필수] 개인정보 처리'),
                ),
                CheckboxListTile(
                  value: model.bodyPhotoAgreed,
                  onChanged: model.busy
                      ? null
                      : (v) => model.updateConsent(photo: v),
                  title: const Text('[필수] 신체 사진 이용'),
                ),
                CheckboxListTile(
                  value: model.aiProcessingAgreed,
                  onChanged: model.busy
                      ? null
                      : (v) => model.updateConsent(ai: v),
                  title: const Text('[필수] AI 처리'),
                ),
                const SizedBox(height: 16),
                const Text(
                  '현재는 동의 화면의 개발용 미리보기입니다. 정식 약관·처리방침과 동의 저장은 서비스 연결 시 적용합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                if (model.error != null)
                  Text(
                    model.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                PrimaryButton(
                  label: '동의 후 계속',
                  onPressed: model.acceptRequiredConsents,
                  loading: model.busy,
                ),
                TextButton(
                  onPressed: model.busy ? null : model.signOut,
                  child: const Text('로그아웃'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
