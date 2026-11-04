// AI-owned handoff widget. This file does not modify or wire the team's FE.
import 'package:flutter/material.dart';

typedef CoachApiRequest =
    Future<Map<String, dynamic>?> Function(
      String method,
      String path,
      Map<String, dynamic>? body,
    );

class AiCoachPage extends StatefulWidget {
  const AiCoachPage({super.key, required this.request});
  final CoachApiRequest request;

  @override
  State<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends State<AiCoachPage> {
  final _question = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _busy = false;
  bool _needsReload = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _readMessages(Object? value) {
    if (value is! List) throw const FormatException('대화 목록');
    return value.map((item) {
      if (item is! Map ||
          !['user', 'assistant'].contains(item['role']) ||
          item['content'] is! String) {
        throw const FormatException('대화 항목');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.request(
        'GET',
        '/api/ai-coach/messages',
        null,
      );
      final messages = _readMessages(result?['messages']);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _needsReload = false;
      });
      _scrollDown();
    } catch (_) {
      if (mounted)
        setState(() {
          _needsReload = true;
          _error = '대화를 불러오지 못했어요. 로그인과 서버 연결을 확인하고 다시 불러오세요.';
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final question = _question.text.trim();
    if (_busy || _needsReload || question.isEmpty || question.length > 500)
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.request('POST', '/api/ai-coach/messages', {
        'content': question,
      });
      final pair = _readMessages([
        result?['user_message'],
        result?['assistant_message'],
      ]);
      if (pair[0]['role'] != 'user' || pair[1]['role'] != 'assistant') {
        throw const FormatException('대화 순서');
      }
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, ...pair];
        if (_messages.length > 20)
          _messages = _messages.sublist(_messages.length - 20);
        _question.clear();
      });
      _scrollDown();
    } catch (_) {
      if (mounted)
        setState(() {
          _needsReload = true;
          _error = '전송 결과를 확인하지 못했어요. 다시 보내기 전에 대화를 불러와 저장 여부를 확인하세요.';
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 코치'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            tooltip: '대화 불러오기',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '저장한 오늘의 플랜과 함께 운동 습관을 이야기해요. 일반 안내이며 의료적 판정은 제공하지 않아요.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: colors.error)),
              ),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('궁금한 점을 물어보세요.'))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final mine = message['role'] == 'user';
                        final model = message['model'];
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(14),
                            constraints: const BoxConstraints(maxWidth: 520),
                            decoration: BoxDecoration(
                              color: mine
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mine
                                      ? '나'
                                      : model is String
                                      ? '코치 · $model'
                                      : '코치 · 저장 정보 및 규칙 안내',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                const SizedBox(height: 6),
                                SelectableText(message['content'] as String),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _question,
                      enabled: !_busy && !_needsReload,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '코치에게 질문',
                        hintText: '오늘 플랜을 알려주세요',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy || _needsReload ? null : _send,
                    child: const Text('보내기'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
