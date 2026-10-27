import 'package:flutter/material.dart';
import '../../../ui/core/widgets/design_reference_page.dart';
import '../data/community_models.dart';
import 'community_controller.dart';
import 'community_widgets.dart';
import 'community_detail_page.dart';
import 'community_editor_page.dart';
import 'community_safety_pages.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, this.dependencies, this.isActive = false});
  final CommunityDependencies? dependencies;
  final bool isActive;
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with WidgetsBindingObserver {
  CommunityController? _model;
  bool _searching = false;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  void _connect() {
    _model?.dispose();
    _model = widget.dependencies == null
        ? null
        : CommunityController(widget.dependencies!);
    if (widget.isActive) _model?.load();
  }

  @override
  void didUpdateWidget(covariant CommunityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dependencies != widget.dependencies) {
      _search.clear();
      _searching = false;
      _connect();
    } else if (widget.isActive && !oldWidget.isActive) {
      _model?.load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) _model?.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model?.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) await _model?.load();
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    if (model == null) {
      return const SafeArea(child: Center(child: Text('로그인 후 커뮤니티를 이용해 주세요.')));
    }
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => Material(
        color: communityBackground,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: model.load,
                    child: ListView(
                      key: const Key('community-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: communityText(
                                '커뮤니티',
                                size: 23,
                                medium: true,
                              ),
                            ),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE4E1D8),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                tooltip: '게시글 검색',
                                padding: EdgeInsets.zero,
                                onPressed: () => setState(() {
                                  _searching = !_searching;
                                  if (!_searching) {
                                    _search.clear();
                                    model.search('');
                                  }
                                }),
                                icon: const CommunityAsset('search'),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: '커뮤니티 관리',
                              onSelected: (_) => _open(
                                CommunityBlocksPage(dependencies: model.deps),
                              ),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'blocks',
                                  child: Text('차단한 사용자'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_searching) ...[
                          TextField(
                            key: const Key('community-search'),
                            controller: _search,
                            onChanged: model.search,
                            decoration: const InputDecoration(
                              hintText: '불러온 게시글에서 검색',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final e in <String?, String>{
                                null: '전체',
                                ...communityCategories,
                              }.entries)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: communityText(
                                      e.value,
                                      size: 12,
                                      color: model.category == e.key
                                          ? Colors.white
                                          : ReferenceStyle.muted,
                                    ),
                                    selected: model.category == e.key,
                                    showCheckmark: false,
                                    selectedColor: ReferenceStyle.blue,
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: model.category == e.key
                                          ? ReferenceStyle.blue
                                          : const Color(0xFFE4E1D8),
                                    ),
                                    shape: const StadiumBorder(),
                                    onSelected: (_) => model.filter(e.key),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (model.deps.preview)
                          const CommunityNotice(
                            '기기 미리보기 · 실제 게시/전송 없음\n예시 글과 변경 내용은 앱 종료 시 초기화돼요.',
                          ),
                        const SizedBox(height: 12),
                        if (model.error != null)
                          CommunityNotice(
                            model.error!,
                            retry: () =>
                                model.load(more: model.items.isNotEmpty),
                          ),
                        if (model.loading && model.items.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        if (!model.loading &&
                            model.error == null &&
                            model.visible.isEmpty)
                          CommunityNotice(
                            model.query.isEmpty
                                ? '아직 게시글이 없어요. 첫 이야기를 남겨 보세요.'
                                : '불러온 게시글에 검색 결과가 없어요.',
                          ),
                        for (final post in model.visible)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PostCard(
                              post: post,
                              onTap: () => _open(
                                CommunityDetailPage(
                                  dependencies: model.deps,
                                  postId: post.id,
                                ),
                              ),
                            ),
                          ),
                        if (model.hasMore)
                          TextButton(
                            onPressed: model.loading
                                ? null
                                : () => model.load(more: true),
                            child: Text(model.loading ? '불러오는 중…' : '게시글 더 보기'),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 24,
                    bottom: 24,
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: FloatingActionButton(
                        heroTag: 'community-write',
                        elevation: 0,
                        focusElevation: 0,
                        hoverElevation: 0,
                        highlightElevation: 0,
                        tooltip: '글쓰기',
                        backgroundColor: ReferenceStyle.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        onPressed: () => _open(
                          CommunityEditorPage(dependencies: model.deps),
                        ),
                        child: const CommunityAsset('write'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});
  final CommunityPost post;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: post.pinned ? Colors.white : communityCard,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: post.pinned
          ? const BorderSide(color: Color(0xFF9FA6E2))
          : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.pinned) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ReferenceStyle.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: communityText('공지', size: 10, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: communityText(
                      post.author.name,
                      size: 12,
                      color: ReferenceStyle.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            communityText(
              post.title,
              size: post.pinned ? 14 : 15,
              medium: true,
              lines: 2,
            ),
            if (!post.pinned) ...[
              const SizedBox(height: 8),
              communityText(
                post.preview,
                size: 13,
                color: ReferenceStyle.muted,
                lines: 2,
              ),
              if (post.thumbnail != null) ...[
                const SizedBox(height: 10),
                CommunityPhoto(CommunityImage(0, post.thumbnail!), height: 110),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: communityText(
                      '${post.author.name} · ${communityDate(post.created)}',
                      size: 11,
                      color: ReferenceStyle.muted,
                      lines: 1,
                    ),
                  ),
                  const CommunityAsset('heart'),
                  const SizedBox(width: 4),
                  communityText(
                    '${post.likes}',
                    size: 11,
                    color: ReferenceStyle.muted,
                  ),
                  const SizedBox(width: 12),
                  const CommunityAsset('comment'),
                  const SizedBox(width: 4),
                  communityText(
                    '${post.comments}',
                    size: 11,
                    color: ReferenceStyle.muted,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
