import '../../../ui/core/widgets/app_icon.dart';
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
  final _expandedThreads = <int>{};
  final _expandedComments = <int>{};
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
    _focus.addListener(_dismissNotice);
    _load();
  }

  void _dismissNotice() {
    if (_focus.hasFocus && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.removeListener(_dismissNotice);
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
          '이 사용자의 게시글과 댓글이 목록에서 제외돼요. 목록 아래의 차단한 사용자 관리에서 해제할 수 있어요.',
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

  Widget _postMenu(CommunityPost post) => IconButton(
    tooltip: '게시글 메뉴',
    onPressed: _locked
        ? null
        : () async {
            FocusScope.of(context).unfocus();
            final choice = await showCommunityMenu(
              context,
              '게시글 메뉴',
              post.mine
                  ? [
                      const CommunityMenuOption.edit(),
                      const CommunityMenuOption(
                        'delete',
                        '삭제',
                        Icons.delete_outline_rounded,
                        destructive: true,
                      ),
                    ]
                  : [
                      const CommunityMenuOption(
                        'report',
                        '신고',
                        Icons.flag_outlined,
                      ),
                      const CommunityMenuOption(
                        'block',
                        '작성자 차단',
                        Icons.person_off_outlined,
                      ),
                    ],
            );
            if (!mounted) return;
            switch (choice) {
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
    icon: const AppIcon(Icons.more_horiz_rounded),
  );

  Future<void> _commentMenu(CommunityComment c) async {
    FocusScope.of(context).unfocus();
    final choice = await showCommunityMenu(
      context,
      '댓글 메뉴',
      c.mine
          ? [
              const CommunityMenuOption(
                'delete',
                '삭제',
                Icons.delete_outline_rounded,
                destructive: true,
              ),
            ]
          : [
              const CommunityMenuOption('report', '신고', Icons.flag_outlined),
              const CommunityMenuOption(
                'block',
                '작성자 차단',
                Icons.person_off_outlined,
              ),
            ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'delete':
        _deleteComment(c);
      case 'report':
        _report('comment', c.id);
      case 'block':
        _block(c.author, postAuthor: c.author.id == _post!.author.id);
    }
  }

  Widget _commentText(CommunityComment c) => LayoutBuilder(
    builder: (context, bounds) {
      final text = c.deleted ? '삭제된 댓글입니다.' : c.content;
      final style = ReferenceStyle.text(14, 22);
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 3,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: bounds.maxWidth);
      final long = painter.didExceedMaxLines;
      painter.dispose();
      final expanded = _expandedComments.contains(c.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            key: ValueKey('comment-content-${c.id}'),
            style: style,
            maxLines: expanded ? null : 3,
            overflow: expanded ? null : TextOverflow.ellipsis,
          ),
          if (long)
            TextButton(
              onPressed: () => setState(() {
                if (expanded) {
                  _expandedComments.remove(c.id);
                } else {
                  _expandedComments.add(c.id);
                }
              }),
              key: ValueKey('comment-expand-${c.id}'),
              style: _compactButton,
              child: Text(expanded ? '간략히' : '더 보기'),
            ),
        ],
      );
    },
  );

  ButtonStyle get _compactButton => TextButton.styleFrom(
    padding: EdgeInsets.zero,
    minimumSize: const Size(44, 28),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    foregroundColor: ReferenceStyle.muted,
    textStyle: ReferenceStyle.text(12, 18),
  );

  Widget _replyToggle(int parent, int count) => TextButton.icon(
    key: ValueKey('replies-toggle-$parent'),
    onPressed: () => setState(() {
      if (!_expandedThreads.add(parent)) _expandedThreads.remove(parent);
    }),
    style: _compactButton.copyWith(
      foregroundColor: const WidgetStatePropertyAll(ReferenceStyle.blue),
    ),
    icon: AppIcon(
      _expandedThreads.contains(parent)
          ? Icons.expand_less_rounded
          : Icons.expand_more_rounded,
      size: 18,
    ),
    label: Text(_expandedThreads.contains(parent) ? '답글 숨기기' : '답글 $count개 보기'),
  );

  Widget _commentRow(CommunityComment c, {Widget? toggle}) => Padding(
    padding: EdgeInsets.only(top: 6, left: c.parentId == null ? 0 : 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 32,
          child: Row(
            children: [
              CommunityAvatar(
                c.deleted ? '' : c.author.name,
                owner: !c.deleted && c.mine
                    ? widget.dependencies.profileOwner
                    : null,
                key: ValueKey('comment-avatar-${c.id}'),
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey('comment-name-${c.id}'),
                  child: communityText(
                    c.deleted ? '삭제된 댓글' : c.author.name,
                    size: 13,
                    medium: true,
                    lines: 1,
                  ),
                ),
              ),
              if (!c.deleted)
                IconButton(
                  tooltip: '댓글 메뉴',
                  onPressed: _locked ? null : () => _commentMenu(c),
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const AppIcon(Icons.more_horiz_rounded, size: 19),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _commentText(c),
              Wrap(
                spacing: 12,
                children: [
                  if (!c.deleted)
                    TextButton(
                      onPressed: _locked
                          ? null
                          : () {
                              setState(() => _reply = c);
                              _focus.requestFocus();
                            },
                      style: _compactButton,
                      child: const Text('답글 달기'),
                    ),
                  ?toggle,
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  List<Widget> _commentThreads() {
    final parents = _comments.where((c) => c.parentId == null).toList();
    final groups = <int, List<CommunityComment>>{};
    for (final c in _comments.where((c) => c.parentId != null)) {
      (groups[c.parentId!] ??= []).add(c);
    }
    return [
      for (final parent in parents) ...[
        _commentRow(
          parent,
          toggle: groups.containsKey(parent.id)
              ? _replyToggle(parent.id, groups[parent.id]!.length)
              : null,
        ),
        if (_expandedThreads.contains(parent.id))
          for (final reply in groups[parent.id] ?? <CommunityComment>[])
            _commentRow(reply),
      ],
      // 차단 등으로 원문이 없는 답글도 조용히 누락하지 않는다.
      for (final entry in groups.entries.where(
        (e) => !parents.any((p) => p.id == e.key),
      )) ...[
        Padding(
          padding: const EdgeInsets.only(left: 36, top: 8),
          child: communityText(
            '원문 댓글을 표시할 수 없어요.',
            size: 12,
            color: ReferenceStyle.muted,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: _replyToggle(entry.key, entry.value.length),
        ),
        if (_expandedThreads.contains(entry.key))
          for (final reply in entry.value) _commentRow(reply),
      ],
    ];
  }

  Widget _composer() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
    decoration: BoxDecoration(
      color: communityCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: communityBorder),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_reply != null)
          Row(
            children: [
              Expanded(
                child: communityText(
                  '${_reply!.author.name} 님에게 답글',
                  size: 11,
                  color: ReferenceStyle.blue,
                ),
              ),
              IconButton(
                tooltip: '답글 취소',
                onPressed: _busy ? null : () => setState(() => _reply = null),
                icon: const AppIcon(Icons.close_rounded, size: 16),
              ),
            ],
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('community-comment'),
                controller: _input,
                focusNode: _focus,
                onChanged: (_) => setState(() {}),
                enabled: !_busy,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                style: ReferenceStyle.text(14, 22),
                decoration: const InputDecoration(
                  hintText: '이 게시글에 메시지 보내기',
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '댓글 등록',
              onPressed:
                  _locked ||
                      _commentsError != null ||
                      _input.text.trim().isEmpty
                  ? null
                  : _comment,
              style: IconButton.styleFrom(
                backgroundColor: ReferenceStyle.blue,
                foregroundColor: Colors.white,
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const AppIcon(Icons.arrow_upward_rounded, size: 20),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return PopScope(
      canPop: !_busy,
      child: ManagementPage(
        onBack: _busy ? () {} : null,
        title: post?.title ?? '게시글',
        titleMaxLines: 1,
        actions: post == null ? null : [_postMenu(post)],
        body: LayoutBuilder(
          builder: (context, bounds) => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (_loading)
                      const Center(child: CircularProgressIndicator()),
                    if (_error != null)
                      CommunityNotice(
                        _error!,
                        retry: _busy || _loading || _commentsLoading
                            ? null
                            : _load,
                      ),
                    if (post != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: communityCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CommunityAvatar(
                                  post.author.name,
                                  owner: post.mine
                                      ? widget.dependencies.profileOwner
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      communityText(
                                        post.author.name,
                                        size: 13,
                                        medium: true,
                                      ),
                                      communityText(
                                        communityDate(post.created),
                                        size: 10,
                                        color: ReferenceStyle.muted,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            communityText(post.title, size: 19, medium: true),
                            const SizedBox(height: 10),
                            SelectableText(
                              post.content,
                              style: ReferenceStyle.text(14, 23),
                            ),
                            for (final image in post.images)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: CommunityPhoto(image, height: null),
                              ),
                            const SizedBox(height: 8),
                            CommunityReaction(
                              key: const Key('community-like'),
                              liked: post.liked,
                              count: post.likes,
                              busy: _busy,
                              onPressed: _locked ? null : _like,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const CommunityCommentIcon(),
                          const SizedBox(width: 8),
                          communityText('댓글', size: 13, medium: true),
                          const SizedBox(width: 8),
                          communityText(
                            '$_total',
                            size: 11,
                            color: ReferenceStyle.muted,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Divider(color: communityBorder),
                          ),
                        ],
                      ),
                      if (_commentsError != null)
                        CommunityNotice(
                          _commentsError!,
                          retry: _busy || _commentsLoading
                              ? null
                              : _loadComments,
                        ),
                      if (!_commentsLoading &&
                          _commentsError == null &&
                          _comments.isEmpty)
                        const CommunityNotice('첫 댓글을 남겨 보세요.'),
                      ..._commentThreads(),
                      if (_commentsLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_comments.length < _total)
                        TextButton(
                          onPressed: _locked
                              ? null
                              : () => _loadComments(more: true),
                          child: const Text('댓글 더 보기'),
                        ),
                    ],
                  ],
                ),
              ),
              if (post != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: bounds.maxHeight * .48,
                  ),
                  child: SingleChildScrollView(
                    primary: false,
                    child: _composer(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
