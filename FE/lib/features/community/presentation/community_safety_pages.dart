import 'package:flutter/material.dart';
import '../../../ui/core/widgets/design_reference_page.dart';
import '../../../ui/core/widgets/management_page.dart';
import '../../../core/network/api_client.dart';
import '../data/community_models.dart';
import 'community_controller.dart';
import 'community_widgets.dart';

class CommunityReportPage extends StatefulWidget {
  const CommunityReportPage({
    super.key,
    required this.dependencies,
    required this.type,
    required this.targetId,
  });
  final CommunityDependencies dependencies;
  final String type;
  final int targetId;
  @override
  State<CommunityReportPage> createState() => _CommunityReportPageState();
}

class _CommunityReportPageState extends State<CommunityReportPage> {
  final _detail = TextEditingController();
  String? _reason, _error;
  bool _busy = false, _uncertain = false;
  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_reason == null) {
      setState(() => _error = '신고 사유를 선택해 주세요.');
      return;
    }
    if (_uncertain &&
        !await communityConfirm(
          context,
          '신고 결과를 다시 확인할까요?',
          '이전 신고가 접수됐을 수 있어요. 같은 대상에 대한 신고는 중복 접수되지 않아요.',
          action: '확인',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.dependencies.repository.report(
        widget.type,
        widget.targetId,
        _reason!,
        _detail.text,
      );
      if (mounted) {
        _done(
          widget.dependencies.preview
              ? '미리보기에서 신고했어요. 실제 접수되지 않아요.'
              : '신고가 접수됐어요.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is ApiRequestError && e.code == 'ALREADY_REPORTED') {
        _done('이미 신고한 항목이에요.');
        return;
      }
      setState(() {
        _uncertain = e is! ApiRequestError && !widget.dependencies.preview;
        _error = communityError(e, widget.dependencies, writing: true);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done(String message) {
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: ManagementPage(
      title: widget.type == 'post' ? '게시글 신고' : '댓글 신고',
      onBack: _busy ? () {} : null,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.dependencies.preview)
            const CommunityNotice('기기 미리보기 · 실제 신고/전송 없음'),
          communityText('어떤 문제가 있나요?', size: 18, medium: true),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(
              labelText: '신고 사유',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final e in {
                'spam': '스팸·광고',
                'abuse': '욕설·괴롭힘',
                'inappropriate': '부적절한 내용',
                'other': '기타',
              }.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _reason = v),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _detail,
            enabled: !_busy,
            maxLength: 200,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '상세 내용 (선택)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) CommunityNotice(_error!),
          const SizedBox(height: 24),
          ReferenceButton('신고하기', busy: _busy, onPressed: _submit),
        ],
      ),
    ),
  );
}

class CommunityBlocksPage extends StatefulWidget {
  const CommunityBlocksPage({super.key, required this.dependencies});
  final CommunityDependencies dependencies;
  @override
  State<CommunityBlocksPage> createState() => _CommunityBlocksPageState();
}

class _CommunityBlocksPageState extends State<CommunityBlocksPage> {
  final _items = <BlockedMember>[];
  int _page = 0, _total = 0;
  bool _loading = false, _writing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items.clear();
        _page = 0;
        _total = 0;
      }
    });
    try {
      final result = await widget.dependencies.repository.blocks(
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(
          result.items.where((i) => !_items.any((old) => old.id == i.id)),
        );
        _page = result.page;
        _total = result.items.isEmpty ? _items.length : result.total;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = communityError(e, widget.dependencies));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(BlockedMember member) async {
    if (_writing ||
        _loading ||
        !await communityConfirm(
          context,
          '차단을 해제할까요?',
          '${member.name} 님의 게시글과 댓글이 다시 표시돼요.',
          action: '차단 해제',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _writing = true;
      _error = null;
    });
    try {
      await widget.dependencies.repository.unblock(member.id);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = communityError(e, widget.dependencies, writing: true),
        );
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_writing,
    child: ManagementPage(
      onBack: _writing ? () {} : null,
      title: '차단한 사용자',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (widget.dependencies.preview)
            const CommunityNotice('기기 미리보기 · 실제 차단 목록이 아니에요.'),
          if (_error != null)
            CommunityNotice(
              _error!,
              retry: _loading || _writing ? null : _load,
            ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _error == null && _items.isEmpty)
            const CommunityNotice('차단한 사용자가 없어요.'),
          for (final member in _items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: communityText(member.name),
              trailing: TextButton(
                onPressed: _loading || _writing ? null : () => _unblock(member),
                child: const Text('차단 해제'),
              ),
            ),
          if (_items.length < _total)
            TextButton(
              onPressed: _loading || _writing ? null : () => _load(more: true),
              child: const Text('더 보기'),
            ),
        ],
      ),
    ),
  );
}
