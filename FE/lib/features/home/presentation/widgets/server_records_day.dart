import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../data/home_server_repository.dart';
import '../../data/models/server_home_data.dart';

class ServerRecordsDay extends StatefulWidget {
  const ServerRecordsDay({
    super.key,
    required this.repository,
    required this.date,
  });
  final HomeServerRepository repository;
  final DateTime date;
  @override
  State<ServerRecordsDay> createState() => _ServerRecordsDayState();
}

class _ServerRecordsDayState extends State<ServerRecordsDay> {
  final _records = <ServerWorkoutRecord>[];
  ServerWorkoutPage? _summary;
  bool _loading = false;
  String? _error;
  int _page = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.records(
        widget.date,
        widget.date,
        page: _page + 1,
        status: 'completed',
      );
      if (!mounted) return;
      setState(() {
        _summary = data;
        _page = data.page;
        _records.addAll(
          data.items.where((e) => !_records.any((old) => old.id == e.id)),
        );
      });
    } catch (_) {
      if (mounted) setState(() => _error = '서버 기록을 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '서버에 저장된 기록',
        style: ReferenceStyle.text(14, 21, weight: FontWeight.w500),
      ),
      const SizedBox(height: 12),
      if (_summary != null)
        Text(
          '${_summary!.count}개 완료 기록 · ${_summary!.sets}세트 · 총 볼륨 ${_summary!.volume.toStringAsFixed(0)}kg',
          style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
        ),
      if (!_loading && _error == null && _records.isEmpty)
        const Text('완료한 운동 기록이 없어요.'),
      for (final record in _records)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: ReferenceStyle.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.name,
                style: ReferenceStyle.text(16, 24, weight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                '${record.sets}세트 · 총 볼륨 ${record.volume.toStringAsFixed(0)}kg',
                style: ReferenceStyle.text(13, 20),
              ),
            ],
          ),
        ),
      if (_loading) const Center(child: CircularProgressIndicator()),
      if (_error != null) ...[
        Text(_error!, style: const TextStyle(color: Colors.red)),
        TextButton(onPressed: _load, child: const Text('다시 시도')),
      ],
      if (!_loading &&
          _error == null &&
          _summary != null &&
          _records.length < _summary!.total)
        TextButton(onPressed: _load, child: const Text('기록 더 보기')),
    ],
  );
}
