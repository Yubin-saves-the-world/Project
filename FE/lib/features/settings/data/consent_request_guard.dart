import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import '../../auth/data/models/onboarding_progress.dart';

/// Reads current account state on every write; saved records remain readable.
class ConsentRequestGuard {
  const ConsentRequestGuard(this.account);
  final OnboardingAccount? Function() account;
  void check(String method, String url) {
    final path = Uri.parse(url).path;
    final photo = method == 'POST' && path == ApiContract.photos;
    final ai =
        method == 'POST' &&
            [
              ApiContract.photoAnalysis,
              ApiContract.routines,
              ApiContract.goalBodies,
            ].contains(path) ||
        method == 'PATCH' && path.startsWith('${ApiContract.goalBodies}/');
    if ((photo && account()?.bodyPhotoAgreed != true) ||
        (ai && account()?.aiProcessingAgreed != true)) {
      throw ApiRequestError(
        ApiFailure(
          code: 'CONSENT_REQUIRED',
          message: photo
              ? '사진 이용 동의가 필요해요. 동의 관리에서 확인해 주세요.'
              : 'AI 처리 동의가 필요해요. 동의 관리에서 확인해 주세요.',
          status: 403,
          fields: null,
        ),
      );
    }
  }
}
