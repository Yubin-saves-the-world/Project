import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../body_analysis/data/models/body_analysis.dart';
import '../../../body_analysis/presentation/pages/analysis_run_page.dart'
    show AnalysisPanel;
import '../../../photos/data/models/selected_photo.dart';
import '../../../photos/presentation/widgets/photo_input_field.dart';
import '../../data/models/goal_body.dart';
import '../goal_dependencies.dart';
import '../goal_view_model.dart';

class GoalSelection {
  const GoalSelection(this.goal);
  final GoalBody? goal;
}

class GoalBodyPage extends StatefulWidget {
  const GoalBodyPage({
    super.key,
    required this.dependencies,
    this.chooseForAnalysis = false,
  });
  final GoalDependencies dependencies;
  final bool chooseForAnalysis;
  @override
  State<GoalBodyPage> createState() => _GoalBodyPageState();
}

class _GoalBodyPageState extends State<GoalBodyPage>
    with WidgetsBindingObserver {
  late final model = GoalViewModel(widget.dependencies);
  final _description = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model.addListener(_syncDescription);
    model.load();
  }

  void _syncDescription() {
    if (_description.text != model.description) {
      _description.value = TextEditingValue(
        text: model.description,
        selection: TextSelection.collapsed(offset: model.description.length),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      model.resume();
    } else {
      model.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    model.removeListener(_syncDescription);
    model.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null && mounted) await model.pick(source);
  }

  Future<bool> _confirm({required bool delete}) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(delete ? '목표 체형을 삭제할까요?' : '목표 체형을 변경할까요?'),
          content: Text(
            delete
                ? '처리 중인 목표가 있다면 함께 취소돼요. 지난 분석의 비교 결과는 유지돼요.'
                : '등록된 목표를 새 내용으로 변경해요. 지난 분석 결과는 유지되며, 새 목표와 비교하려면 분석을 다시 시작해야 해요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(delete ? '삭제' : '변경'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (model.goal != null && !await _confirm(delete: false)) return;
    if (!mounted) return;
    await model.save();
  }

  Future<void> _delete() async {
    if (!await _confirm(delete: true) || !mounted) return;
    await model.delete();
  }

  Widget _status() {
    final goal = model.goal!;
    return AnalysisPanel(
      children: [
        Text(switch (goal.status) {
          AnalysisStatus.pending =>
            model.timedOut ? '목표를 처리하고 있어요' : '목표 사진을 분석하고 있어요',
          AnalysisStatus.done => '등록한 목표 체형',
          AnalysisStatus.failed => '목표 사진을 분석하지 못했어요',
          AnalysisStatus.unknown => '목표 상태를 확인해 주세요',
        }, style: ReferenceStyle.text(16, 24, weight: FontWeight.w500)),
        const SizedBox(height: 8),
        if (goal.status == AnalysisStatus.pending) ...[
          const Text('사진에서 특징을 추출하고 있어요. 화면을 나가도 나중에 다시 확인할 수 있어요.'),
          if (model.checking)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (model.timedOut) const Text('잠시 후 다시 확인해 주세요.'),
        ],
        if (goal.summary != null) Text(goal.summary!),
        if (goal.description != null) Text(goal.description!),
        if (goal.status == AnalysisStatus.failed)
          Text(goal.errorMessage ?? '다른 사진을 선택하거나 설명만으로 다시 저장해 주세요.'),
        if (goal.status == AnalysisStatus.unknown)
          const Text('현재 상태를 인식하지 못했어요. 다시 불러와 주세요.'),
        if (!model.checking &&
            (model.processing || goal.status == AnalysisStatus.unknown))
          TextButton(
            onPressed: model.busy ? null : model.load,
            child: const Text('다시 확인'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => PopScope(
      canPop: !model.busy,
      child: ManagementPage(
        title: '목표 체형',
        onBack: model.busy ? () {} : () => Navigator.maybePop(context),
        actions: [
          if (model.goal != null)
            IconButton(
              tooltip: '목표 삭제',
              onPressed: model.busy || model.loading || !model.loaded
                  ? null
                  : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (model.loading)
                      const Center(child: CircularProgressIndicator()),
                    if (model.goal != null) ...[
                      _status(),
                      const SizedBox(height: 20),
                    ],
                    if (!model.loading &&
                        model.loaded &&
                        model.goal == null) ...[
                      Text(
                        '어떤 체형을 목표로 하나요?',
                        style: ReferenceStyle.text(
                          20,
                          28,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('사진 또는 설명으로 목표를 정할 수 있어요.'),
                      const SizedBox(height: 20),
                    ],
                    if (widget.dependencies.localPreview) ...[
                      const Text(
                        '미리보기에서는 설명만 현재 앱 세션에 저장돼요. 사진 분석은 서버 연결 후 이용할 수 있어요.',
                        style: TextStyle(color: ReferenceStyle.muted),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!widget.dependencies.localPreview &&
                        (!model.processing || model.photo != null)) ...[
                      PhotoInputField(
                        label: model.goal == null ? '목표 사진' : '새 목표 사진',
                        photo: model.photo,
                        enabled: model.canEdit,
                        onSelect: _pick,
                        onRemove: model.removePhoto,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '목표 사진은 특징 추출 후 원본이 삭제돼요. 저장 후에는 사진 대신 요약과 설명을 보여드려요.',
                        style: ReferenceStyle.text(
                          12,
                          18,
                          color: ReferenceStyle.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      '목표 설명',
                      style: ReferenceStyle.text(
                        14,
                        21,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('goal-description'),
                      controller: _description,
                      enabled: model.canEdit,
                      maxLength: 200,
                      minLines: 3,
                      maxLines: 5,
                      onChanged: model.setDescription,
                      decoration: const InputDecoration(
                        hintText: '예: 어깨와 등 근육을 키우고 싶어요.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '목표를 변경해도 지난 분석은 그대로예요. 새 목표로 비교하려면 분석을 다시 시작해 주세요.',
                      style: ReferenceStyle.text(
                        12,
                        18,
                        color: ReferenceStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (model.validationError != null || model.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        model.validationError ?? model.error!,
                        style: ReferenceStyle.text(12, 18, color: Colors.red),
                      ),
                    ),
                  if (!model.loaded && !model.loading)
                    TextButton(
                      onPressed: model.busy ? null : model.load,
                      child: const Text('다시 불러오기'),
                    ),
                  if ((model.accessCode == 'CONSENT_REQUIRED' ||
                          model.accessCode == 'ONBOARDING_REQUIRED') &&
                      widget.dependencies.onAccessRequired != null)
                    TextButton(
                      onPressed: widget.dependencies.onAccessRequired,
                      child: const Text('동의·신체정보 확인'),
                    ),
                  if (widget.chooseForAnalysis && model.canSelect)
                    ReferenceButton(
                      '이 목표로 비교',
                      onPressed: () =>
                          Navigator.pop(context, GoalSelection(model.goal)),
                    )
                  else if (!model.processing)
                    ReferenceButton(
                      model.goal == null ? '목표 저장' : '변경 저장',
                      onPressed: model.canEdit ? _save : null,
                      busy: model.busy,
                    ),
                  if (widget.chooseForAnalysis)
                    TextButton(
                      onPressed: model.busy
                          ? null
                          : () => Navigator.pop(
                              context,
                              const GoalSelection(null),
                            ),
                      child: const Text('목표 없이 분석'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
