import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../data/models/body_analysis.dart';
import '../analysis_dependencies.dart';
import 'analysis_run_page.dart';

class AnalysisHistoryPage extends StatefulWidget {
  const AnalysisHistoryPage({super.key, required this.dependencies});
  final AnalysisDependencies dependencies;
  @override
  State<AnalysisHistoryPage> createState() => _AnalysisHistoryPageState();
}

class _AnalysisHistoryPageState extends State<AnalysisHistoryPage> {
  final _items = <AnalysisSummary>[];
  int _page = 0, _total = 0;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.dependencies.repository.history(
        page: reset ? 1 : _page + 1,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        for (final item in page.items) {
          if (!_items.any((v) => v.id == item.id)) _items.add(item);
        }
        _page = page.page;
        _total = page.total;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '분석 기록을 불러오지 못했어요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ManagementPage(
    title: '분석 기록',
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          if (!_loading && _error == null && _items.isEmpty)
            const AnalysisPanel(
              children: [
                Text('아직 분석 기록이 없어요.'),
                Text('사진으로 첫 체형 분석을 시작해 보세요.'),
              ],
            ),
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AnalysisRunPage(
                        id: item.id,
                        dependencies: widget.dependencies,
                      ),
                    ),
                  );
                  if (mounted) await _load(reset: true);
                },
                child: AnalysisPanel(
                  children: [
                    Text(
                      '${item.createdAt.toLocal().year}.${item.createdAt.toLocal().month.toString().padLeft(2, '0')}.${item.createdAt.toLocal().day.toString().padLeft(2, '0')}',
                      style: ReferenceStyle.text(
                        12,
                        18,
                        color: ReferenceStyle.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      switch (item.status) {
                        AnalysisStatus.done =>
                          item.score == null ? '점수 산출 불가' : '${item.score}점',
                        AnalysisStatus.pending => '분석 중 · 이어서 확인',
                        AnalysisStatus.failed => '분석 실패',
                        AnalysisStatus.unknown => '상태 확인 필요',
                      },
                      style: ReferenceStyle.text(
                        18,
                        26,
                        weight: FontWeight.w500,
                      ),
                    ),
                    if (item.bodyType != null) Text(item.bodyType!),
                  ],
                ),
              ),
            ),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: () => _load(reset: true),
              child: const Text('다시 시도'),
            ),
          ],
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _error == null && _items.length < _total)
            TextButton(onPressed: _load, child: const Text('더 보기')),
        ],
      ),
    ),
  );
}
