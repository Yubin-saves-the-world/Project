import '../../../ui/core/theme/app_colors.dart';
import '../../../ui/core/widgets/app_icon.dart';
import 'package:flutter/material.dart';
import '../../../ui/core/widgets/design_reference_page.dart';
import '../../../ui/core/widgets/management_page.dart';
import '../../../core/network/api_client.dart';
import '../data/community_models.dart';
import 'community_controller.dart';
import 'community_widgets.dart';

class CommunityEditorPage extends StatefulWidget {
  const CommunityEditorPage({
    super.key,
    required this.dependencies,
    this.original,
  });
  final CommunityDependencies dependencies;
  final CommunityPost? original;
  @override
  State<CommunityEditorPage> createState() => _CommunityEditorPageState();
}

class _CommunityEditorPageState extends State<CommunityEditorPage> {
  late final TextEditingController _title, _content;
  late String _category;
  String get _authorName {
    final current = widget.dependencies.currentNickname?.call().trim();
    return current != null && current.isNotEmpty
        ? current
        : widget.original?.author.name ?? '나';
  }

  final _images = <CommunityUpload>[];
  final _removed = <int>[];
  bool _busy = false, _saved = false, _uncertain = false, _picking = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.original?.title ?? '');
    _content = TextEditingController(text: widget.original?.content ?? '');
    _category = widget.original?.category ?? 'info';
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _title.text != (widget.original?.title ?? '') ||
      _content.text != (widget.original?.content ?? '') ||
      _images.isNotEmpty ||
      _removed.isNotEmpty ||
      _category != (widget.original?.category ?? 'info');
  Future<void> _back() async {
    if (_busy || _picking) return;
    if (_dirty &&
        !await communityConfirm(
          context,
          '작성을 그만할까요?',
          '저장하지 않은 내용과 선택한 사진은 사라져요.',
          action: '나가기',
        )) {
      return;
    }
    if (mounted) {
      setState(() => _saved = true);
      Navigator.pop(context);
    }
  }

  Future<void> _pick() async {
    if (_picking || _busy) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final retained =
          widget.original?.images
              .where((i) => !_removed.contains(i.id))
              .length ??
          0;
      final result = await widget.dependencies.picker.pick(
        4 - retained - _images.length,
      );
      if (mounted) setState(() => _images.addAll(result));
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : '사진을 가져오지 못했어요. 사진 접근 권한을 확인해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _picking) return;
    FocusScope.of(context).unfocus();
    final draft = CommunityDraft(
      category: _category,
      title: _title.text,
      content: _content.text,
      images: List.of(_images),
      removeImageIds: List.of(_removed),
    );
    try {
      draft.validate(original: widget.original);
    } catch (e) {
      setState(() => _error = (e as StateError).message.toString());
      return;
    }
    if (_uncertain &&
        !await communityConfirm(
          context,
          '다시 전송할까요?',
          '이전 요청이 저장됐을 수도 있어요. 목록에서 저장 여부를 확인한 후에만 다시 전송해 주세요.',
          action: '다시 전송',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.dependencies.repository.save(
        draft,
        original: widget.original,
      );
      if (!mounted) return;
      setState(() {
        _saved = true;
        _busy = false;
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.dependencies.preview ? '게시글을 현재 앱에 저장했어요.' : '게시글을 저장했어요.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uncertain = e is! ApiRequestError && !widget.dependencies.preview;
        _error = communityError(e, widget.dependencies, writing: true);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final retained =
        widget.original?.images
            .where((i) => !_removed.contains(i.id))
            .toList() ??
        <CommunityImage>[];
    final count = retained.length + _images.length;
    return PopScope(
      canPop: _saved || (!_dirty && !_busy && !_picking),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ManagementPage(
        title: widget.original == null ? '글쓰기' : '게시글 수정',
        onBack: _back,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _busy || _picking ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.original == null ? '게시하기' : '수정 완료'),
            ),
          ),
        ],
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Row(
              children: [
                CommunityAvatar(
                  _authorName,
                  owner: widget.dependencies.profileOwner,
                ),
                const SizedBox(width: 12),
                Expanded(child: communityText(_authorName, medium: true)),
              ],
            ),
            const SizedBox(height: 20),
            communityText('카테고리', size: 12, color: ReferenceStyle.muted),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final e in {
                  ...communityCategories,
                  if (widget.original?.category == 'notice') 'notice': '공지',
                }.entries)
                  ChoiceChip(
                    label: Text('# ${e.value}'),
                    selected: _category == e.key,
                    showCheckmark: false,
                    backgroundColor: communityCard,
                    selectedColor: AppColors.primarySoft,
                    labelStyle: ReferenceStyle.text(
                      12,
                      18,
                      color: _category == e.key
                          ? ReferenceStyle.blue
                          : ReferenceStyle.muted,
                    ),
                    side: BorderSide(
                      color: _category == e.key
                          ? ReferenceStyle.blue
                          : communityBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _category = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: communityCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: communityBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('community-title'),
                    controller: _title,
                    enabled: !_busy,
                    onChanged: (_) => setState(() {}),
                    maxLength: 50,
                    maxLines: 2,
                    minLines: 1,
                    style: ReferenceStyle.text(18, 28, weight: FontWeight.w500),
                    decoration: const InputDecoration(
                      hintText: '게시글 제목',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      counterStyle: TextStyle(fontSize: 10),
                    ),
                  ),
                  const Divider(color: communityBorder, height: 24),
                  TextField(
                    key: const Key('community-content'),
                    controller: _content,
                    enabled: !_busy,
                    onChanged: (_) => setState(() {}),
                    maxLength: 2000,
                    minLines: 7,
                    maxLines: 16,
                    style: ReferenceStyle.text(14, 23),
                    decoration: const InputDecoration(
                      hintText: '함께 나누고 싶은 이야기를 적어 주세요.',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      counterStyle: TextStyle(fontSize: 10),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final image in retained)
                            _attachment(
                              image,
                              '기존 사진 삭제',
                              () => _removed.add(image.id),
                            ),
                          for (var i = 0; i < _images.length; i++)
                            _attachment(
                              CommunityImage(-1, '', bytes: _images[i].bytes),
                              '선택한 사진 삭제',
                              () => _images.removeAt(i),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(color: communityBorder, height: 24),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _busy || _picking || count >= 4
                            ? null
                            : _pick,
                        icon: const AppIcon(
                          Icons.add_circle_outline_rounded,
                          size: 22,
                        ),
                        label: Text(_picking ? '가져오는 중…' : '사진 추가'),
                      ),
                      const Spacer(),
                      communityText(
                        '$count/4',
                        size: 12,
                        color: ReferenceStyle.muted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            communityText(
              'JPG, PNG · 사진 한 장당 10MB 이하',
              size: 11,
              color: ReferenceStyle.muted,
            ),
            if (_error != null) CommunityNotice(_error!),
          ],
        ),
      ),
    );
  }

  Widget _attachment(CommunityImage image, String label, VoidCallback remove) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SizedBox(
          width: 112,
          height: 112,
          child: Stack(
            children: [
              CommunityPhoto(image, height: 112, fit: BoxFit.cover),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton.filledTonal(
                  tooltip: label,
                  onPressed: _busy ? null : () => setState(remove),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                  icon: const AppIcon(Icons.close_rounded, size: 17),
                ),
              ),
            ],
          ),
        ),
      );
}
