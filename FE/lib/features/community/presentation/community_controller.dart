import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../data/community_models.dart';
import '../data/community_repository.dart';

class CommunityDependencies {
  const CommunityDependencies({
    required this.repository,
    required this.picker,
    this.preview = false,
    this.onAccessRequired,
  });
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

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    super.dispose();
  }
}
