import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/media/image_picker_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_contract.dart';
import '../data/models/body_photo.dart';
import '../data/models/selected_photo.dart';
import '../data/photo_preparer.dart';
import '../data/photo_repository.dart';

class PhotoManagementViewModel extends ChangeNotifier {
  PhotoManagementViewModel({
    required this.repository,
    required this.picker,
    required this.preparer,
  });
  final PhotoRepository repository;
  final PhotoPicker picker;
  final PhotoPreparer preparer;
  List<BodyPhoto> items = const [];
  int total = 0;
  bool loading = false, writing = false, hasLoaded = false, _disposed = false;
  String? error, notice;
  SelectedPhoto? pending;
  BodyPhotoSide pendingSide = BodyPhotoSide.front;
  bool get busy => loading || writing;
  bool get canAdd => hasLoaded && !busy && total < ApiContract.photoLimit;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _message(Object e) {
    if (e is PhotoPickerException) return e.message;
    if (e is ApiRequestError) {
      return switch (e.code) {
        'PHOTO_LIMIT_EXCEEDED' => '사진은 최대 20장까지 올릴 수 있어요. 기존 사진을 삭제해 주세요.',
        'IMAGE_TOO_LARGE' => '10MB 이하의 사진을 선택해 주세요.',
        'IMAGE_INVALID_TYPE' => 'JPG 또는 PNG 사진을 선택해 주세요.',
        'CONSENT_REQUIRED' => '사진 이용 동의가 필요해요. 동의 상태를 확인해 주세요.',
        'PHOTO_IN_USE' => '처리가 끝나면 지울 수 있어요.',
        _ => e.message,
      };
    }
    return e is StateError ? e.message : '사진을 처리하지 못했어요. 다시 시도해 주세요.';
  }

  Future<void> load() async {
    if (busy) return;
    loading = true;
    error = null;
    _notify();
    try {
      await _reload();
    } catch (e) {
      error = _message(e);
      hasLoaded = false;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> _reload() async {
    final page = await repository.list();
    if (_disposed) return;
    items = page.items;
    total = page.total;
    hasLoaded = true;
  }

  Future<void> recover() async {
    if (busy || pending != null) return;
    writing = true;
    _notify();
    try {
      final recovered = await picker.recover();
      if (_disposed) {
        if (recovered != null) await picker.discard(recovered.$2);
        return;
      }
      if (recovered != null) {
        pending = recovered.$2;
        pendingSide = recovered.$1 == PhotoSlot.side
            ? BodyPhotoSide.side
            : BodyPhotoSide.front;
        notice = '선택하던 사진을 복원했어요. 확인 후 올려 주세요.';
      }
    } catch (e) {
      error = _message(e);
    } finally {
      writing = false;
      _notify();
    }
  }

  Future<void> add(PhotoSource source, BodyPhotoSide side) async {
    if (!canAdd) return;
    writing = true;
    error = notice = null;
    _notify();
    try {
      final photo = await picker.pick(
        side == BodyPhotoSide.side ? PhotoSlot.side : PhotoSlot.front,
        source,
      );
      if (photo == null) return;
      if (_disposed) {
        await picker.discard(photo);
        return;
      }
      await _discardPending();
      pending = photo;
      pendingSide = side;
      await _upload();
    } catch (e) {
      error = _message(e);
    } finally {
      writing = false;
      _notify();
    }
  }

  Future<void> retryUpload() async {
    if (busy || !hasLoaded || pending == null) return;
    writing = true;
    error = notice = null;
    _notify();
    try {
      await _upload();
    } catch (e) {
      error = _message(e);
    } finally {
      writing = false;
      _notify();
    }
  }

  Future<void> _upload() async {
    final photo = pending!;
    final bytes = await preparer.prepare(photo);
    if (_disposed) return;
    final uploaded = await repository.upload(
      bytes,
      type: BodyPhotoType.current,
      side: pendingSide,
    );
    items = List.unmodifiable([uploaded, ...items]);
    total++;
    await _discardPending();
    notice = '사진을 올렸어요.';
    try {
      await _reload();
    } catch (e) {
      error = _message(e);
      hasLoaded = false;
    }
  }

  Future<void> discardPending() async {
    if (busy) return;
    await _discardPending();
    error = notice = null;
    _notify();
  }

  Future<void> _discardPending() async {
    final photo = pending;
    pending = null;
    if (photo != null) {
      try {
        await picker.discard(photo);
      } catch (_) {
        /* Uploaded data is kept even if cache cleanup fails. */
      }
    }
  }

  Future<void> remove(BodyPhoto photo) async {
    if (!hasLoaded || busy) return;
    writing = true;
    error = notice = null;
    _notify();
    try {
      await repository.delete(photo.id);
      items = List.unmodifiable(items.where((v) => v.id != photo.id));
      total = total > 0 ? total - 1 : 0;
      notice = '사진을 삭제했어요.';
      try {
        await _reload();
      } catch (e) {
        error = _message(e);
        hasLoaded = false;
      }
    } catch (e) {
      error = _message(e);
    } finally {
      writing = false;
      _notify();
    }
  }

  Future<void> removeAll() async {
    if (!hasLoaded || busy || total == 0) return;
    writing = true;
    error = notice = null;
    _notify();
    try {
      final result = await repository.deleteAll();
      if (result.skipped == 0) {
        items = const [];
        total = 0;
      }
      notice = result.skipped == 0
          ? '사진을 모두 삭제했어요.'
          : '${result.deleted}장 삭제했어요. 처리 중인 ${result.skipped}장은 남아 있어요.';
      try {
        await _reload();
      } catch (e) {
        error = _message(e);
        hasLoaded = false;
      }
    } catch (e) {
      error = _message(e);
    } finally {
      writing = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_discardPending());
    super.dispose();
  }
}
