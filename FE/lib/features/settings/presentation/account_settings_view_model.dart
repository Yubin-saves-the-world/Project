import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../auth/data/models/auth_session.dart';
import 'account_settings_dependencies.dart';

class AccountSettingsViewModel extends ChangeNotifier {
  AccountSettingsViewModel(this.dependencies);
  final AccountSettingsDependencies dependencies;
  CurrentUser? user;
  bool loading = false,
      busy = false,
      needsReload = false,
      serverDeleted = false,
      deleted = false,
      _disposed = false;
  String? error, nicknameError;
  bool get canWrite =>
      user != null && !loading && !busy && !needsReload && !serverDeleted;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _failure(Object e) {
    error = e is StateError
        ? e.message.toString()
        : '요청을 처리하지 못했어요. 다시 시도해 주세요.';
  }

  void _apply(CurrentUser value) {
    if (_disposed) return;
    user = value;
    dependencies.onChanged?.call(value);
  }

  Future<void> load() async {
    if (loading || busy || serverDeleted) return;
    loading = true;
    error = null;
    nicknameError = null;
    _notify();
    try {
      _apply(await dependencies.repository.load());
      needsReload = false;
    } catch (e) {
      needsReload = true;
      _failure(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> rename(String value) async {
    if (!canWrite) return false;
    final name = value.trim();
    if (name.runes.length < 2 || name.runes.length > 20) {
      nicknameError = '닉네임은 2~20자로 입력해 주세요.';
      _notify();
      return false;
    }
    return _patch({'nickname': name}, nickname: true);
  }

  Future<bool> consent({bool? photo, bool? ai}) async {
    if (!canWrite || photo == null && ai == null) return false;
    return _patch({'body_photo_agreed': ?photo, 'ai_processing_agreed': ?ai});
  }

  Future<bool> _patch(
    Map<String, dynamic> body, {
    bool nickname = false,
  }) async {
    busy = true;
    error = null;
    nicknameError = null;
    _notify();
    try {
      _apply(await dependencies.repository.update(body));
      return true;
    } catch (e) {
      _failure(e);
      if (nickname &&
          e is ApiRequestError &&
          (e.code == 'NICKNAME_DUPLICATED' || e.status == 400)) {
        nicknameError = error;
        error = null;
      } else {
        needsReload = true;
      }
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> removeAccount() async {
    if (busy || loading || deleted || (!serverDeleted && !canWrite)) {
      return false;
    }
    busy = true;
    error = null;
    _notify();
    try {
      if (!serverDeleted) {
        await dependencies.repository.delete();
        serverDeleted = true;
      }
      // A cleanup failure is retried without repeating the destructive request.
      await dependencies.cleanup();
      await dependencies.onDeleted();
      deleted = true;
      return true;
    } catch (e) {
      _failure(e);
      if (!serverDeleted) needsReload = true;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
