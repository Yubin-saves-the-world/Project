import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../ui/core/widgets/design_reference_page.dart';
import '../../../ui/core/widgets/management_page.dart';
import '../data/community_models.dart';
import 'community_controller.dart';
import 'community_widgets.dart';
import 'community_editor_page.dart';
import 'community_safety_pages.dart';

class CommunityDetailPage extends StatefulWidget {
  const CommunityDetailPage({
    super.key,
    required this.dependencies,
    required this.postId,
  });
  final CommunityDependencies dependencies;
  final int postId;
  @override
  State<CommunityDetailPage> createState() => _CommunityDetailPageState();
}

class _CommunityDetailPageState extends State<CommunityDetailPage> {
  CommunityPost? _post;
  final _comments = <CommunityComment>[];
  final _input = TextEditingController();
  final _focus = FocusNode();
  CommunityComment? _reply;
  bool _loading = true,
      _commentsLoading = false,
      _busy = false,
      _needsRefresh = false,
      _uncertainComment = false;
  String? _error, _commentsError;
  int _page = 0, _total = 0;
  bool get _locked => _busy || _loading || _commentsLoading || _needsRefresh;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _loading = true;
      _error = null;
      _post = null;
    });
    try {
      final p = await widget.dependencies.repository.post(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = p;
        _needsRefresh = false;
      });
      await _loadComments();
    } catch (e) {
      if (mounted) {
        setState(() => _error = communityError(e, widget.dependencies));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadComments({bool more = false}) async {
    if (_commentsLoading) return;
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
      if (!more) {
        _comments.clear();
        _page = 0;
        _total = 0;
      }
    });
    try {
      final result = await widget.dependencies.repository.comments(
        widget.postId,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _comments.addAll(
          result.items.where((c) => !_comments.any((old) => old.id == c.id)),
        );
        _page = result.page;
        _total = result.items.isEmpty ? _comments.length : result.total;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _commentsError = communityError(e, widget.dependencies));
      }
    } finally {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_locked) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _needsRefresh = e is! ApiRequestError;
          _error = communityError(e, widget.dependencies, writing: true);
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _like() async {
    final p = _post;
    if (p == null) return;
    await _run(() async {
      try {
        final result = await widget.dependencies.repository.like(
          p.id,
          !p.liked,
        );
        if (mounted) setState(() => _post = p.withLike(result));
      } on ApiRequestError catch (e) {
        if (e.code != 'ALREADY_LIKED') rethrow;
        final refreshed = await widget.dependencies.repository.post(p.id);
        if (mounted) setState(() => _post = refreshed);
      }
    });
  }

  Future<void> _comment() async {
    if (_locked || _commentsError != null) return;
    final content = _input.text.trim();
    if (content.isEmpty || content.runes.length > 500) {
      setState(() => _error = '댓글은 1~500자로 입력해 주세요.');
      return;
    }
    if (_uncertainComment &&
        !await communityConfirm(
          context,
          '댓글을 다시 전송할까요?',
          '이전 댓글이 저장됐을 수도 있어요. 댓글 목록에서 저장 여부를 확인한 뒤 다시 전송해 주세요.',
          action: '다시 전송',
        )) {
      return;
    }
    if (!mounted) return;
    final ok = await _run(() async {
      await widget.dependencies.repository.comment(
        widget.postId,
        content,
        parentId: _reply?.parentId ?? _reply?.id,
      );
    });
    if (!mounted) return;
    if (ok) {
      _input.clear();
      _focus.unfocus();
      setState(() {
        _reply = null;
        _uncertainComment = false;
      });
      await _loadComments();
    } else {
      _uncertainComment = _needsRefresh;
    }
  }

  Future<void> _delete() async {
    if (_locked ||
        _post?.mine != true ||
        !await communityConfirm(
          context,
          '게시글을 삭제할까요?',
          '게시글과 첨부 사진, 댓글을 다시 볼 수 없어요.',
          action: '삭제',
        )) {
      return;
    }
    if (!mounted) return;
    if (await _run(
          () => widget.dependencies.repository.deletePost(widget.postId),
        ) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteComment(CommunityComment c) async {
    if (_locked ||
        !c.mine ||
        !await communityConfirm(
          context,
          '댓글을 삭제할까요?',
          '답글이 있는 댓글은 삭제 안내로 표시돼요.',
          action: '삭제',
        )) {
      return;
    }
    if (!mounted) return;
    final ok = await _run(
      () => widget.dependencies.repository.deleteComment(widget.postId, c.id),
    );
    if (mounted && ok) {
      if (_reply?.id == c.id) setState(() => _reply = null);
      await _loadComments();
    }
  }

  Future<void> _edit() async {
    if (_locked || _post?.mine != true) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CommunityEditorPage(
          dependencies: widget.dependencies,
          original: _post,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _report(String type, int id) async {
    if (_locked) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CommunityReportPage(
          dependencies: widget.dependencies,
          type: type,
          targetId: id,
        ),
      ),
    );
  }

  Future<void> _block(
    CommunityAuthor author, {
    required bool postAuthor,
  }) async {
    if (_locked ||
        !await communityConfirm(
          context,
          '${author.name} 님을 차단할까요?',
          '이 사용자의 게시글과 댓글이 목록에서 제외돼요. 커뮤니티 관리에서 해제할 수 있어요.',
          action: '차단',
        )) {
      return;
    }
    if (!mounted) return;
    final ok = await _run(() async {
      try {
        await widget.dependencies.repository.block(author.id);
      } on ApiRequestError catch (e) {
        if (e.code != 'ALREADY_BLOCKED') rethrow;
      }
    });
    if (!mounted || !ok) return;
    if (postAuthor) {
      Navigator.pop(context);
    } else {
      await _loadComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return PopScope(
      canPop: !_busy,
      child: ManagementPage(
        onBack: _busy ? () {} : null,
        title: '게시글',
        actions: post == null
            ? null
            : [
                PopupMenuButton<String>(
                  enabled: !_locked,
                  tooltip: '게시글 메뉴',
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        _edit();
                      case 'delete':
                        _delete();
                      case 'report':
                        _report('post', post.id);
                      case 'block':
                        _block(post.author, postAuthor: true);
                    }
                  },
                  itemBuilder: (_) => post.mine
                      ? [
                          const PopupMenuItem(value: 'edit', child: Text('수정')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('삭제'),
                          ),
                        ]
                      : [
                          const PopupMenuItem(
                            value: 'report',
                            child: Text('신고'),
                          ),
                          const PopupMenuItem(
                            value: 'block',
                            child: Text('작성자 차단'),
                          ),
                        ],
                ),
              ],
        body: ListView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (widget.dependencies.preview)
              const CommunityNotice('기기 미리보기 · 실제 게시/전송 없음'),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              CommunityNotice(
                _error!,
                retry: _busy || _loading || _commentsLoading ? null : _load,
              ),
            if (post != null) ...[
              communityText(
                post.category == 'notice'
                    ? '공지'
                    : communityCategories[post.category] ?? post.category,
                size: 12,
                color: ReferenceStyle.blue,
              ),
              const SizedBox(height: 10),
              communityText(post.title, size: 21, medium: true),
              const SizedBox(height: 8),
              communityText(
                '${post.author.name} · ${communityDate(post.created)} · 조회 ${post.views}',
                size: 12,
                color: ReferenceStyle.muted,
              ),
              const SizedBox(height: 24),
              SelectableText(post.content, style: ReferenceStyle.text(15, 25)),
              for (final image in post.images)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: CommunityPhoto(image, height: 260),
                ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _locked ? null : _like,
                  icon: Icon(
                    post.liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 19,
                    color: post.liked
                        ? ReferenceStyle.blue
                        : ReferenceStyle.muted,
                  ),
                  label: Text('좋아요 ${post.likes}'),
                ),
              ),
              const Divider(height: 40),
              communityText('댓글', size: 17, medium: true),
              if (_commentsError != null)
                CommunityNotice(
                  _commentsError!,
                  retry: _busy || _commentsLoading ? null : _loadComments,
                ),
              if (!_commentsLoading &&
                  _commentsError == null &&
                  _comments.isEmpty)
                const CommunityNotice('첫 댓글을 남겨 보세요.'),
              for (final c in _comments)
                Padding(
                  padding: EdgeInsets.only(
                    top: 12,
                    left: c.parentId == null ? 0 : 20,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: communityCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: communityText(
                                  c.deleted ? '삭제된 댓글' : c.author.name,
                                  size: 12,
                                  medium: true,
                                ),
                              ),
                              if (!c.deleted)
                                PopupMenuButton<String>(
                                  tooltip: '댓글 메뉴',
                                  enabled: !_locked,
                                  onSelected: (v) {
                                    switch (v) {
                                      case 'delete':
                                        _deleteComment(c);
                                      case 'report':
                                        _report('comment', c.id);
                                      case 'block':
                                        _block(
                                          c.author,
                                          postAuthor:
                                              c.author.id == post.author.id,
                                        );
                                    }
                                  },
                                  itemBuilder: (_) => c.mine
                                      ? [
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('삭제'),
                                          ),
                                        ]
                                      : [
                                          const PopupMenuItem(
                                            value: 'report',
                                            child: Text('신고'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'block',
                                            child: Text('작성자 차단'),
                                          ),
                                        ],
                                ),
                            ],
                          ),
                          communityText(
                            c.deleted ? '삭제된 댓글입니다.' : c.content,
                            size: 14,
                          ),
                          if (!c.deleted)
                            TextButton(
                              onPressed: _locked
                                  ? null
                                  : () {
                                      setState(() => _reply = c);
                                      _focus.requestFocus();
                                    },
                              child: const Text('답글 달기'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_commentsLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_comments.length < _total)
                TextButton(
                  onPressed: _locked ? null : () => _loadComments(more: true),
                  child: const Text('댓글 더 보기'),
                ),
              const SizedBox(height: 20),
              if (_reply != null)
                Row(
                  children: [
                    Expanded(
                      child: communityText(
                        '${_reply!.author.name} 님에게 답글',
                        size: 12,
                        color: ReferenceStyle.blue,
                      ),
                    ),
                    IconButton(
                      tooltip: '답글 취소',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _reply = null),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              TextField(
                key: const Key('community-comment'),
                controller: _input,
                focusNode: _focus,
                enabled: !_busy,
                maxLength: 500,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '댓글을 입력해 주세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ReferenceButton(
                '댓글 등록',
                busy: _busy,
                onPressed: _locked || _commentsError != null ? null : _comment,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
