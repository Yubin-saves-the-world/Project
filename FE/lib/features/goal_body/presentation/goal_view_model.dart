import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/media/image_picker_service.dart';
import '../../body_analysis/data/models/body_analysis.dart';
import '../../photos/data/models/selected_photo.dart';
import '../../photos/data/models/body_photo.dart';
import '../../photos/data/photo_preparer.dart';
import '../data/models/goal_body.dart';
import 'goal_dependencies.dart';

class GoalViewModel extends ChangeNotifier {
  GoalViewModel(
    this.dependencies, {
    DateTime Function()? now,
    this.interval = const Duration(seconds: 2),
    this.maxWait = const Duration(seconds: 60),
  }) : _now = now ?? DateTime.now;
  final GoalDependencies dependencies;
  final DateTime Function() _now;
  final Duration interval, maxWait;
  GoalBody? goal;
  SelectedPhoto? photo;
  String description = '';
  String? error, accessCode, validationError;
  bool loading = false,
      busy = false,
      loaded = false,
      timedOut = false,
      checking = false;
  bool _disposed = false, _recovered = false, _active = true;
  int _generation = 0;
  Timer? _timer;
  DateTime? _started, _uploadedAt;
  int? _uploadedId;
  String? _uploadedPath;
  bool get processing => goal?.status == AnalysisStatus.pending;
  bool get dirty =>
      photo != null || description.trim() != (goal?.description ?? '').trim();
  bool get canEdit =>
      loaded &&
      !loading &&
      !busy &&
      (goal == null ||
          goal?.status == AnalysisStatus.done ||
          goal?.status == AnalysisStatus.failed);
  bool get canSelect =>
      loaded &&
      !busy &&
      !loading &&
      !dirty &&
      goal?.status == AnalysisStatus.done;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setDescription(String value) {
    if (!canEdit) return;
    description = value;
    validationError = null;
    error = null;
    _notify();
  }

  void pause() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    checking = false;
    loading = false;
  }

  void _error(Object e) {
    accessCode = e is ApiRequestError ? e.code : null;
    error = e is PhotoPickerException
        ? e.message
        : e is StateError
        ? e.message.toString()
        : '요청에 실패했어요. 연결 상태를 확인하고 다시 시도해 주세요.';
  }

  Future<void> load() async {
    if (busy || loading) return;
    pause();
    final generation = _generation;
    loading = true;
    error = null;
    accessCode = null;
    timedOut = false;
    _notify();
    try {
      final current = await dependencies.repository.load();
      if (_disposed || generation != _generation) return;
      final preserveDraft = dirty;
      goal = current;
      loaded = true;
      if (!preserveDraft) description = current?.description ?? '';
      if (!_recovered) {
        _recovered = true;
        final recovered = await dependencies.picker.recover();
        if (_disposed || generation != _generation) return;
        if (recovered != null && recovered.$1 == PhotoSlot.goal) {
          photo = recovered.$2;
        }
      }
    } catch (e) {
      if (_disposed || generation != _generation) return;
      loaded = false;
      _error(e);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
    if (!_disposed && loaded && processing) _beginPolling();
  }

  void suspend() {
    _active = false;
    pause();
  }

  Future<void> resume() async {
    _active = true;
    await load();
  }

  void _beginPolling() {
    if (!_active || _disposed) return;
    pause();
    _started = _now();
    timedOut = false;
    checking = true;
    _schedule(_generation);
    _notify();
  }

  void _schedule(int generation) {
    final remaining = maxWait - _now().difference(_started!);
    if (remaining <= Duration.zero) {
      timedOut = true;
      checking = false;
      _notify();
      return;
    }
    _timer = Timer(
      remaining < interval ? remaining : interval,
      () => _poll(generation),
    );
  }

  Future<void> _poll(int generation) async {
    if (_disposed || generation != _generation) return;
    final remaining = maxWait - _now().difference(_started!);
    if (remaining <= Duration.zero) {
      timedOut = true;
      checking = false;
      _notify();
      return;
    }
    try {
      final current = await dependencies.repository.load().timeout(remaining);
      if (_disposed || generation != _generation) return;
      final preserveDraft = dirty;
      goal = current;
      loaded = true;
      if (!preserveDraft) description = current?.description ?? '';
      if (processing) {
        _schedule(generation);
      } else {
        checking = false;
      }
    } catch (e) {
      if (_disposed || generation != _generation) return;
      checking = false;
      if (e is TimeoutException) {
        timedOut = true;
      } else {
        loaded = false;
        _error(e);
      }
    }
    _notify();
  }

  Future<void> pick(PhotoSource source) async {
    if (!canEdit) return;
    busy = true;
    error = null;
    _notify();
    try {
      final selected = await dependencies.picker.pick(PhotoSlot.goal, source);
      if (selected != null && !_disposed) {
        final old = photo;
        photo = selected;
        _uploadedId = null;
        validationError = null;
        if (old != null && old.path != selected.path) {
          await dependencies.picker.discard(old);
        }
      } else if (selected != null) {
        await dependencies.picker.discard(selected);
      }
    } catch (e) {
      _error(e);
    } finally {
      busy = false;
      _notify();
    }
  }

  void removePhoto() {
    if (!canEdit) return;
    final old = photo;
    photo = null;
    _uploadedId = null;
    _notify();
    if (old != null) dependencies.picker.discard(old).catchError((Object _) {});
  }

  Future<int?> _upload() async {
    if (photo == null) return null;
    if (_uploadedId != null &&
        _uploadedPath == photo!.path &&
        _uploadedAt != null &&
        _now().difference(_uploadedAt!) < const Duration(hours: 1)) {
      return _uploadedId;
    }
    final selected = photo!;
    final bytes = await (dependencies.preparer ?? FilePhotoPreparer()).prepare(
      selected,
    );
    if (_disposed) throw StateError('사진 업로드가 취소됐어요.');
    final result = await dependencies.photos.upload(
      bytes,
      type: BodyPhotoType.goal,
      side: BodyPhotoSide.front,
    );
    _uploadedPath = selected.path;
    _uploadedAt = _now();
    return _uploadedId = result.id;
  }

  Future<bool> save() async {
    if (!canEdit) return false;
    final text = description.trim();
    if (goal?.description?.trim().isNotEmpty == true && text.isEmpty) {
      validationError =
          '기존 설명만 삭제하는 기능은 아직 지원하지 않아요. 설명을 수정하거나 목표를 삭제한 뒤 다시 등록해 주세요.';
      _notify();
      return false;
    }
    if (text.length > 200 ||
        (text.isEmpty && photo == null && goal?.previewBytes == null)) {
      validationError = text.length > 200
          ? '설명은 200자 이하로 적어 주세요.'
          : '사진을 추가하거나 목표를 설명해 주세요.';
      _notify();
      return false;
    }
    pause();
    busy = true;
    error = null;
    validationError = null;
    accessCode = null;
    _notify();
    var saved = false;
    try {
      dependencies.ensureCanWrite?.call();
      final photoId = await _upload();
      if (_disposed) return false;
      final current = goal;
      final result = current == null
          ? await dependencies.repository.create(
              photoId: photoId,
              description: text.isEmpty ? null : text,
            )
          : await dependencies.repository.update(
              current.id,
              photoId: photoId,
              description: text.isEmpty ? null : text,
            );
      goal = result;
      loaded = true;
      saved = true;
      final old = photo;
      photo = null;
      _uploadedId = null;
      description = result.description ?? '';
      if (old != null) {
        try {
          await dependencies.picker.discard(old);
        } catch (_) {}
      }
    } catch (e) {
      if (e is ApiRequestError && e.code == 'GOAL_ALREADY_EXISTS') {
        try {
          goal = await dependencies.repository.load();
          loaded = true;
        } catch (_) {
          loaded = false;
        }
        error = '이미 등록된 목표가 있어요. 확인 후 변경 저장을 눌러 주세요.';
      } else {
        if (e is ApiRequestError && (e.status == 404 || e.status == 410)) {
          _uploadedId = null;
          if (e.status == 404) loaded = false;
        }
        _error(e);
      }
    } finally {
      busy = false;
      _notify();
    }
    if (!_disposed && loaded && processing) _beginPolling();
    return saved;
  }

  Future<bool> delete() async {
    if (!loaded || loading || busy || goal == null) return false;
    pause();
    busy = true;
    error = null;
    accessCode = null;
    _notify();
    try {
      await dependencies.repository.delete(goal!.id);
      goal = null;
      description = '';
      validationError = null;
      loaded = true;
      final old = photo;
      photo = null;
      _uploadedId = null;
      if (old != null) {
        try {
          await dependencies.picker.discard(old);
        } catch (_) {}
      }
      return true;
    } catch (e) {
      loaded = false;
      _error(e);
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    if (photo != null) {
      dependencies.picker.discard(photo!).catchError((Object _) {});
    }
    super.dispose();
  }
}
