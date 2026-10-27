import '../../auth/data/models/auth_session.dart';
import '../data/account_repository.dart';

class AccountSettingsDependencies {
  const AccountSettingsDependencies({
    required this.repository,
    required this.cleanup,
    required this.onDeleted,
    this.onChanged,
  });
  final AccountRepository repository;
  final Future<void> Function() cleanup, onDeleted;
  final void Function(CurrentUser)? onChanged;
}
