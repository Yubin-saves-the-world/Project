import 'dart:async';
import '../../../ui/core/theme/app_colors.dart';
import '../../../ui/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../ui/core/widgets/design_reference_page.dart';
import '../data/community_models.dart';
import 'community_controller.dart';
import 'community_widgets.dart';
import 'community_detail_page.dart';
import 'community_editor_page.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({
    super.key,
    this.dependencies,
    this.isActive = false,
    this.onOpenMyPage,
  });
  final CommunityDependencies? dependencies;
  final bool isActive;
  final FutureOr<void> Function()? onOpenMyPage;
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with WidgetsBindingObserver {
  CommunityController? _model;
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('community-search'),
                            controller: _search,
                            onChanged: model.search,
                            style: ReferenceStyle.text(14, 22),
                            decoration: InputDecoration(
                              hintText: '불러온 게시글에서 검색',
                              prefixIcon: const AppIcon(
                                Icons.search_rounded,
                                color: ReferenceStyle.muted,
                                size: 23,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: ReferenceStyle.border,
                                ),
                              ),
                              suffixIcon: model.query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: '검색 지우기',
                                      onPressed: () {
                                        _search.clear();
                                        model.search('');
                                      },
                                      icon: const AppIcon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('community-profile'),
                          tooltip: '마이페이지',
                          onPressed: widget.onOpenMyPage == null
                              ? null
                              : () async {
                                  await widget.onOpenMyPage!();
                                  if (mounted) await model.load();
                                },
                          style: IconButton.styleFrom(
                            side: const BorderSide(color: communityBorder),
                            fixedSize: const Size(44, 44),
                          ),
                          icon: SvgPicture.asset(
                            'assets/icons/profile.svg',
                            width: 20,
                            height: 20,
                            colorFilter: const ColorFilter.mode(
                              ReferenceStyle.muted,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
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
                                        : communityBorder,
                                  ),
                                  shape: const StadiumBorder(),
                                  onSelected: (_) => model.filter(e.key),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: model.load,
                          child: ListView(
                            key: const Key('community-list'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 4, 24, 100),
                            children: [
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
                                    onOpenMyPage: widget.onOpenMyPage,
                                    onTap: () => _open(
                                      CommunityDetailPage(
                                        dependencies: model.deps,
                                        postId: post.id,
                                        onOpenMyPage: widget.onOpenMyPage,
                                      ),
                                    ),
                                  ),
                                ),
                              if (model.hasMore)
                                TextButton(
                                  onPressed: model.loading
                                      ? null
                                      : () => model.load(more: true),
                                  child: Text(
                                    model.loading ? '불러오는 중…' : '게시글 더 보기',
                                  ),
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
                              tooltip: '글쓰기',
                              elevation: 0,
                              focusElevation: 0,
                              hoverElevation: 0,
                              highlightElevation: 0,
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
  const _PostCard({required this.post, required this.onTap, this.onOpenMyPage});
  final CommunityPost post;
  final FutureOr<void> Function()? onOpenMyPage;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final image = post.images.isNotEmpty
        ? post.images.first
        : post.thumbnail == null
        ? null
        : CommunityImage(0, post.thumbnail!);
    return SizedBox(
      key: ValueKey('community-card-${post.id}'),
      height: 148 * scale,
      child: Material(
        color: communityCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: post.pinned ? AppColors.accentBorder : communityBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (post.pinned) ...[
                                  const AppIcon(
                                    Icons.push_pin_outlined,
                                    size: 14,
                                    color: ReferenceStyle.blue,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: communityText(
                                    post.title,
                                    size: 15,
                                    medium: true,
                                    lines: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            communityText(
                              post.preview,
                              size: 13,
                              color: ReferenceStyle.muted,
                              lines: 2,
                            ),
                          ],
                        ),
                      ),
                      if (image != null) ...[
                        const SizedBox(width: 12),
                        SizedBox(
                          key: ValueKey('community-thumbnail-${post.id}'),
                          width: 76 * scale,
                          height: 76 * scale,
                          child: CommunityPhoto(
                            image,
                            height: 76 * scale,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: post.mine ? onOpenMyPage : null,
                        child: communityText(
                          '${post.author.name} · ${communityDate(post.created)}',
                          size: 10,
                          color: ReferenceStyle.muted,
                          lines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      key: ValueKey('community-reactions-${post.id}'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CommunityAsset('heart'),
                        const SizedBox(width: 4),
                        communityText(
                          '${post.likes}',
                          size: 10,
                          color: ReferenceStyle.muted,
                        ),
                        const SizedBox(width: 10),
                        const CommunityAsset('comment'),
                        const SizedBox(width: 4),
                        communityText(
                          '${post.comments}',
                          size: 10,
                          color: ReferenceStyle.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
