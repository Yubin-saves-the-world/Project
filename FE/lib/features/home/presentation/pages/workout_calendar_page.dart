import '../../data/home_server_repository.dart';
import '../widgets/server_records_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../home_view_model.dart';

/// 홈과 같은 기록을 조회하지만 날짜 선택은 이 페이지 안에서만 유지합니다.
class WorkoutCalendarPage extends StatefulWidget {
  const WorkoutCalendarPage({
    super.key,
    required this.model,
    this.serverRepository,
  });
  final HomeViewModel model;
  final HomeServerRepository? serverRepository;

  @override
  State<WorkoutCalendarPage> createState() => _WorkoutCalendarPageState();
}

class _WorkoutCalendarPageState extends State<WorkoutCalendarPage> {
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.model.selectedDate;
  }

  TextStyle _text(double size, {bool bold = false, bool muted = false}) =>
      ReferenceStyle.text(
        size,
        size * 1.5,
        weight: bold ? FontWeight.w500 : FontWeight.w400,
        color: muted ? ReferenceStyle.muted : ReferenceStyle.ink,
      );

  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    locale: const Locale('ko', 'KR'),
    delegates: GlobalMaterialLocalizations.delegates,
    child: AnimatedBuilder(
      animation: widget.model,
      builder: (context, _) {
        final model = widget.model;
        final records = model.completed
            .where((record) => sameDate(record.date, selectedDate))
            .toList();
        var firstDate = DateTime(model.today.year - 1);
        for (final record in model.completed) {
          if (record.date.isBefore(firstDate)) firstDate = record.date;
        }
        if (selectedDate.isBefore(firstDate)) firstDate = selectedDate;
        var lastDate = model.monday.add(const Duration(days: 6));
        if (selectedDate.isAfter(lastDate)) lastDate = selectedDate;
        final sets = records.fold(0, (sum, record) => sum + record.sets);
        final volume = records.fold(0.0, (sum, record) => sum + record.volume);
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text('운동 기록', style: _text(20, bold: true)),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DatePickerTheme(
                        data: const DatePickerThemeData(
                          dayStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            height: 1,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: selectedDate,
                          currentDate: model.today,
                          firstDate: firstDate,
                          lastDate: lastDate,
                          onDateChanged: (date) =>
                              setState(() => selectedDate = date),
                        ),
                      ),
                      const Divider(color: ReferenceStyle.border),
                      const SizedBox(height: 16),
                      Text(
                        '${selectedDate.month}월 ${selectedDate.day}일 운동 기록',
                        style: _text(18, bold: true),
                      ),
                      const SizedBox(height: 12),
                      if (widget.serverRepository != null) ...[
                        ServerRecordsDay(
                          key: ValueKey(HomeViewModel.dateKey(selectedDate)),
                          repository: widget.serverRepository!,
                          date: selectedDate,
                        ),
                        const SizedBox(height: 20),
                        if (records.isNotEmpty)
                          Text('기기에 저장된 기록', style: _text(14, bold: true)),
                      ],
                      if (widget.serverRepository != null && records.isEmpty)
                        const SizedBox.shrink()
                      else if (model.loading)
                        const Center(child: CircularProgressIndicator())
                      else if (!model.loaded) ...[
                        Text('기록을 불러오지 못했어요.', style: _text(14, muted: true)),
                        TextButton(
                          onPressed: model.initialize,
                          child: const Text('다시 불러오기'),
                        ),
                      ] else if (records.isEmpty)
                        Text('완료한 운동 기록이 없어요.', style: _text(14, muted: true))
                      else ...[
                        Text(
                          '${records.map((record) => record.exercise).toSet().length}종목 · $sets세트 · 총 볼륨 ${volume.toStringAsFixed(0)}kg',
                          style: _text(12, muted: true),
                        ),
                        const SizedBox(height: 16),
                        for (final record in records)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: ReferenceStyle.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  HomeViewModel.exercises[record.exercise].name,
                                  style: _text(16, bold: true),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${record.weight}kg · ${record.reps}회 · ${record.sets}세트',
                                  style: _text(14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '총 볼륨 ${record.volume.toStringAsFixed(0)}kg',
                                  style: _text(12, muted: true),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
