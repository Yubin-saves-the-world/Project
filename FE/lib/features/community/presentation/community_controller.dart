import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../data/community_models.dart';
import '../data/community_repository.dart';

class CommunityDependencies {
  const CommunityDependencies({
    required this.repository,
    required this.picker,
    this.preview = false,
    this.profileOwner,
    this.currentNickname,
    this.onAccessRequired,
  });
  final String? profileOwner;
  final String Function()? currentNickname;
  final CommunityRepository repository;
  final CommunityImagePicker picker;
  final bool preview;
  final VoidCallback? onAccessRequired;
}

String communityError(
  Object error,
  CommunityDependencies deps, {
  bool writing = false,
}) {
  if (error is ApiRequestError) {
    if (error.status == 401) return '로그인이 만료됐어요. 다시 로그인해 주세요.';
    if (error.code == 'ONBOARDING_REQUIRED') {
      deps.onAccessRequired?.call();
      return '가입 정보를 먼저 완료해 주세요.';
    }
    return error.failure.displayMessage;
  }
  if (writing && !deps.preview) {
    return '처리 결과를 확인하지 못했어요. 작성 내용은 유지돼요. 목록에서 결과를 먼저 확인해 주세요.';
  }
  if (error is StateError) return error.message.toString();
  return '내용을 불러오지 못했어요. 다시 확인해 주세요.';
}

/// 새 필터 조회가 시작된 뒤 도착한 이전 응답은 반영하지 않는다.
class CommunityController extends ChangeNotifier {
  CommunityController(this.deps);
  final CommunityDependencies deps;
  List<CommunityPost> items = [];
  String? category, error;
  String query = '';
  final reactions = <int, bool>{};
  final reacting = <int>{};
  bool loading = false;
  int _page = 0, _total = 0, _revision = 0;
  bool _disposed = false;
  bool get hasMore => items.length < _total && _page > 0;
  List<CommunityPost> get visible => items
      .where(
        (p) => '${p.title} ${p.preview} ${p.author.name}'
            .toLowerCase()
            .contains(query.trim().toLowerCase()),
      )
      .toList();
  void search(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> filter(String? value) async {
    category = value;
    await load();
  }

  Future<void> load({bool more = false}) async {
    if (more && (loading || !hasMore)) return;
    final revision = ++_revision;
    final page = more ? _page + 1 : 1;
    final categoryAtStart = category;
    loading = true;
    error = null;
    if (!more) {
      reactions.clear();
      items = [];
      _page = 0;
      _total = 0;
    }
    notifyListeners();
    try {
      final result = await deps.repository.posts(
        category: categoryAtStart,
        page: page,
      );
      if (_disposed || revision != _revision) return;
      final merged = <int, CommunityPost>{
        for (final p in items) p.id: p,
        for (final p in result.items) p.id: p,
      };
      items = merged.values.toList();
      _page = result.page;
      _total = result.total;
      if (result.items.isEmpty) _total = items.length;
    } catch (e) {
      if (_disposed || revision != _revision) return;
      error = communityError(e, deps);
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleLike(int id) async {
    if (reacting.contains(id) || _disposed) return;
    final revision = _revision;
    reacting.add(id);
    error = null;
    notifyListeners();
    try {
      // 목록 계약에는 liked_by_me가 없어 첫 반응 때 상세로 현재 상태를 확인한다.
      final current = reactions[id] ?? (await deps.repository.post(id)).liked;
      Map<String, dynamic> result;
      try {
        result = await deps.repository.like(id, !current);
      } on ApiRequestError catch (e) {
        if (e.code != 'ALREADY_LIKED') rethrow;
        final post = await deps.repository.post(id);
        result = {'like_count': post.likes, 'liked_by_me': post.liked};
      }
      if (_disposed || revision != _revision) return;
      reactions[id] = result['liked_by_me'] as bool;
      items = [for (final p in items) p.id == id ? p.withLike(result) : p];
    } catch (e) {
      if (!_disposed && revision == _revision) {
        error = communityError(e, deps, writing: true);
      }
    } finally {
      if (!_disposed) {
        reacting.remove(id);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}
