import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../photos/data/models/selected_photo.dart';
import '../../photos/data/models/body_photo.dart';
import '../../photos/data/photo_preparer.dart';
import '../data/models/analysis_input.dart';
import '../data/models/body_analysis.dart';
import 'analysis_dependencies.dart';
import 'analysis_form_controller.dart';

class AnalysisInputViewModel extends ChangeNotifier
    implements AnalysisFormController {
  AnalysisInputViewModel(this.dependencies);
  final AnalysisDependencies dependencies;
  @override
  AnalysisInput analysis = const AnalysisInput();
  @override
  bool busy = false;
  @override
  bool get bodyPhotoAgreed => true; // 서버가 동의 상태를 최종 검증한다.
  @override
  String? error;
  String? accessCode, usageError;
  AnalysisUsage? usage;
  AnalysisGoal? selectedGoal;
  int? pendingId;
  bool _disposed = false;
  final _uploaded = <String, int>{};
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      pendingId = await dependencies.pending.read();
    } catch (_) {
      error = '진행 중인 분석을 복원하지 못했어요. 분석 기록에서 확인해 주세요.';
    }
    try {
      final recovered = await dependencies.picker.recover();
      if (!_disposed && recovered != null && recovered.$1 != PhotoSlot.goal) {
        analysis = analysis.copyWith(slot: recovered.$1, photo: recovered.$2);
      }
    } catch (_) {
      error = '선택했던 사진을 복원하지 못했어요. 다시 선택해 주세요.';
    }
    await refreshPending();
    await refreshUsage();
    busy = false;
    _notify();
  }

  Future<void> refreshPending() async {
    if (pendingId == null) return;
    try {
      final detail = await dependencies.repository.detail(pendingId!);
      if (detail.status == AnalysisStatus.done ||
          detail.status == AnalysisStatus.failed) {
        pendingId = null;
        try {
          await dependencies.pending.clear(detail.id);
        } catch (_) {}
      }
    } catch (_) {
      /* 조회 실패 시 ID를 유지해 사용자가 다시 확인할 수 있게 한다. */
    }
    _notify();
  }

  Future<void> refreshUsage() async {
    try {
      usage = await dependencies.repository.usage();
      usageError = null;
    } catch (_) {
      usageError = '남은 분석 횟수를 확인하지 못했어요.';
    }
    _notify();
  }

  @override
  void setMethod(AnalysisMethod method) {
    if (!busy) {
      analysis = analysis.copyWith(method: method);
      _notify();
    }
  }

  @override
  void setText(String value) {}
  @override
  void back() {}
  @override
  SelectedPhoto? photoFor(PhotoSlot slot) => switch (slot) {
    PhotoSlot.front => analysis.front,
    PhotoSlot.side => analysis.side,
    PhotoSlot.goal => null,
  };
  @override
  Future<void> pickPhoto(PhotoSlot slot, PhotoSource source) async {
    if (busy || slot == PhotoSlot.goal) return;
    busy = true;
    error = null;
    _notify();
    try {
      final photo = await dependencies.picker.pick(slot, source);
      if (photo != null && !_disposed) {
        final old = photoFor(slot);
        analysis = analysis.copyWith(slot: slot, photo: photo);
        if (old != null && old.path != photo.path) {
          await dependencies.picker.discard(old);
        }
      } else if (photo != null) {
        await dependencies.picker.discard(photo);
      }
    } catch (_) {
      error = '사진을 가져오지 못했어요. 권한과 파일을 확인해 주세요.';
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void removePhoto(PhotoSlot slot) {
    if (busy) return;
    final old = photoFor(slot);
    analysis = analysis.copyWith(slot: slot, photo: null);
    error = null;
    _notify();
    if (old != null) {
      dependencies.picker.discard(old).catchError((Object _) {});
    }
  }

  Future<AnalysisGoal?> loadGoal() async {
    if (busy) return null;
    busy = true;
    error = null;
    _notify();
    try {
      return await dependencies.repository.goal();
    } catch (e) {
      _showError(e);
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  void selectGoal(AnalysisGoal? goal) {
    selectedGoal = goal;
    _notify();
  }

  Future<void> refreshSelectedGoal() async {
    if (selectedGoal == null || dependencies.goals == null) return;
    try {
      final goal = await dependencies.goals!.repository.load();
      selectedGoal = goal?.status == AnalysisStatus.done
          ? goal!.comparison
          : null;
    } catch (e) {
      _showError(e);
    }
    _notify();
  }

  void _showError(Object e) {
    accessCode = e is ApiRequestError ? e.code : null;
    error = e is StateError
        ? e.message.toString()
        : '요청에 실패했어요. 연결 상태를 확인하고 다시 시도해 주세요.';
  }

  Future<int> _upload(SelectedPhoto photo, BodyPhotoSide side) async {
    final key = '${side.name}:${photo.path}';
    final cached = _uploaded[key];
    if (cached != null) return cached;
    final bytes = await (dependencies.preparer ?? FilePhotoPreparer()).prepare(
      photo,
    );
    final uploaded = await dependencies.photos.upload(
      bytes,
      type: BodyPhotoType.current,
      side: side,
    );
    return _uploaded[key] = uploaded.id;
  }

  @override
  Future<bool> finish({required bool prepareAnalysis}) async {
    if (busy) return false;
    if (pendingId != null) return true;
    if (analysis.front == null) {
      error = '정면 사진을 추가해 주세요.';
      _notify();
      return false;
    }
    if (usage != null && usage!.remaining <= 0) {
      error = '오늘의 분석 횟수를 모두 사용했어요.';
      _notify();
      return false;
    }
    busy = true;
    error = null;
    accessCode = null;
    _notify();
    try {
      dependencies.ensureCanAnalyze?.call();
      if (selectedGoal != null && dependencies.goals != null) {
        final currentGoal = await dependencies.goals!.repository.load();
        if (currentGoal?.status != AnalysisStatus.done ||
            currentGoal?.id != selectedGoal?.id) {
          selectedGoal = null;
          error = '목표 체형이 변경되었거나 처리 중이에요. 목표를 다시 선택해 주세요.';
          return false;
        }
        selectedGoal = currentGoal!.comparison;
      }
      final front = await _upload(analysis.front!, BodyPhotoSide.front);
      final side = analysis.side == null
          ? null
          : await _upload(analysis.side!, BodyPhotoSide.side);
      if (_disposed) return false;
      final ticket = await dependencies.repository.start(
        photoId: front,
        sidePhotoId: side,
        goalId: selectedGoal?.id,
      );
      pendingId = ticket.id;
      try {
        await dependencies.pending.write(ticket.id);
      } catch (_) {
        error = '분석은 시작됐어요. 기록 저장에 실패해 이번 화면에서 결과를 확인해 주세요.';
      }
      return true;
    } catch (e) {
      if (e is ApiRequestError && e.code == 'ANALYSIS_IN_PROGRESS') {
        try {
          final history = await dependencies.repository.history();
          final pending = history.items
              .where((v) => v.status == AnalysisStatus.pending)
              .firstOrNull;
          if (pending != null) {
            pendingId = pending.id;
            try {
              await dependencies.pending.write(pending.id);
            } catch (_) {}
            return true;
          }
        } catch (_) {}
      }
      _showError(e);
      if (e is ApiRequestError && e.code == 'ANALYSIS_QUOTA_EXCEEDED') {
        await refreshUsage();
      }
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final photo in [analysis.front, analysis.side]) {
      if (photo != null) {
        dependencies.picker.discard(photo).catchError((Object _) {});
      }
    }
    super.dispose();
  }
}
