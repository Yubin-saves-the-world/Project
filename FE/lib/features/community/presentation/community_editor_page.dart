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
            widget.dependencies.preview
                ? '미리보기에 저장했어요. 실제 게시되지 않아요.'
                : '게시글을 저장했어요.',
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
    return PopScope(
      canPop: _saved || (!_dirty && !_busy && !_picking),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ManagementPage(
        title: widget.original == null ? '글쓰기' : '게시글 수정',
        onBack: _back,
        body: ListView(
          padding: const EdgeInsets.all(24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (widget.dependencies.preview)
              const CommunityNotice('기기 미리보기 · 실제 게시/전송 없음'),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: '카테고리',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final e in {
                  ...communityCategories,
                  if (widget.original?.category == 'notice') 'notice': '공지',
                }.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: _busy ? null : (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('community-title'),
              controller: _title,
              onChanged: (_) => setState(() {}),
              enabled: !_busy,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '제목을 입력해 주세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('community-content'),
              controller: _content,
              onChanged: (_) => setState(() {}),
              enabled: !_busy,
              maxLength: 2000,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: '내용',
                hintText: '함께 나누고 싶은 이야기를 적어 주세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            communityText(
              '사진 ${retained.length + _images.length}/4 · JPG, PNG · 장당 10MB 이하',
              size: 12,
              color: ReferenceStyle.muted,
            ),
            for (final image in retained)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    CommunityPhoto(image),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _removed.add(image.id)),
                      child: const Text('기존 사진 삭제'),
                    ),
                  ],
                ),
              ),
            for (var i = 0; i < _images.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    CommunityPhoto(
                      CommunityImage(-1, '', bytes: _images[i].bytes),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _images.removeAt(i)),
                      child: const Text('선택한 사진 삭제'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed:
                  _busy || _picking || retained.length + _images.length >= 4
                  ? null
                  : _pick,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_picking ? '사진 가져오는 중…' : '사진 추가'),
            ),
            if (_error != null) CommunityNotice(_error!),
            const SizedBox(height: 20),
            ReferenceButton(
              widget.original == null ? '게시하기' : '수정 완료',
              busy: _busy,
              onPressed: _picking ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
