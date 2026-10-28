import 'package:flutter/foundation.dart';
import '../data/models/body_profile.dart';
import '../data/profile_repository.dart';
import '../../routines/data/routine_refresh_repository.dart';

class MyPageViewModel extends ChangeNotifier {
  MyPageViewModel(this.repository, {this.profile, this.routines});
  final RoutineRefreshRepository? routines;
  bool regenerating = false;
  Future<bool> regenerate() async {
    if (regenerating) return false;
    regenerating = true;
    error = null;
    _notify();
    try {
      if (routines == null) throw StateError('완료된 체형 분석이 필요해요.');
      await routines!.regenerate();
      return true;
    } catch (e) {
      error = e is StateError ? e.message : '추천 루틴을 만들지 못했어요. 다시 시도해 주세요.';
      return false;
    } finally {
      regenerating = false;
      _notify();
    }
  }

  final ProfileRepository repository;
  BodyProfile? profile;
  bool loading = false, _disposed = false;
  String? error;
  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    _notify();
    try {
      profile = await repository.load();
    } catch (e) {
      error = e is StateError ? e.message : '신체정보를 불러오지 못했어요. 다시 시도해 주세요.';
    } finally {
      loading = false;
      _notify();
    }
  }

  void apply(ProfileSaveResult result) {
    profile = result.profile;
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
