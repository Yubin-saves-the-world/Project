import '../../../../ui/core/widgets/app_icon.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/media/image_picker_service.dart';
import '../../../../ui/core/theme/app_colors.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../data/models/body_photo.dart';
import '../../data/models/selected_photo.dart';
import '../../data/photo_preparer.dart';
import '../../data/photo_repository.dart';
import '../photo_management_view_model.dart';
import '../widgets/photo_input_field.dart';

class PhotoManagementPage extends StatefulWidget {
  const PhotoManagementPage({
    super.key,
    required this.repository,
    required this.picker,
    this.preparer,
    this.onConsentRequired,
    this.type = BodyPhotoType.current,
  });
  final PhotoRepository repository;
  final BodyPhotoType type;
  final PhotoPicker picker;
  final PhotoPreparer? preparer;
  final VoidCallback? onConsentRequired;
  @override
  State<PhotoManagementPage> createState() => _PhotoManagementPageState();
}

class _PhotoManagementPageState extends State<PhotoManagementPage>
    with WidgetsBindingObserver {
  late final model = PhotoManagementViewModel(
    repository: widget.repository,
    type: widget.type,
    picker: widget.picker,
    preparer: widget.preparer ?? FilePhotoPreparer(),
  );
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
    _refresh = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!model.busy &&
          model.items.any(
            (p) =>
                p.previewBytes == null &&
                !p.urlExpiresAt.isAfter(
                  DateTime.now().add(const Duration(minutes: 1)),
                ),
          )) {
        unawaited(model.load());
      }
    });
  }

  Future<void> _initialize() async {
    await model.load();
    if (mounted) await model.recover();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !model.busy) {
      unawaited(model.load());
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    model.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('삭제'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _add() async {
    if (!model.canAdd) return;
    final selection = await showModalBottomSheet<(PhotoSource, BodyPhotoSide)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '사진 추가',
                  style: ReferenceStyle.text(20, 28, weight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                for (final side in [
                  BodyPhotoSide.front,
                  BodyPhotoSide.side,
                ]) ...[
                  Text(
                    side == BodyPhotoSide.front ? '정면' : '측면',
                    style: ReferenceStyle.text(14, 21, color: AppColors.muted),
                  ),
                  ListTile(
                    leading: const AppIcon(Icons.camera_alt_outlined),
                    title: const Text('촬영하기'),
                    onTap: () =>
                        Navigator.pop(context, (PhotoSource.camera, side)),
                  ),
                  ListTile(
                    leading: const AppIcon(Icons.photo_library_outlined),
                    title: const Text('앨범에서 선택'),
                    onTap: () =>
                        Navigator.pop(context, (PhotoSource.gallery, side)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (selection != null && mounted) {
      await model.add(selection.$1, selection.$2);
    }
  }

  Widget _photo(BodyPhoto photo) => AspectRatio(
    aspectRatio: 3 / 4,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppColors.soft,
            child: photo.previewBytes != null
                ? Image.memory(
                    photo.previewBytes!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => _imageError(),
                  )
                : Image.network(
                    photo.url,
                    key: ValueKey(photo.url),
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) => _imageError(),
                  ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(photo.sideLabel, style: ReferenceStyle.text(11, 16)),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: '${photo.sideLabel} 사진 삭제',
              onPressed: model.busy || !model.hasLoaded
                  ? null
                  : () async {
                      if (await _confirm(
                            '사진을 삭제할까요?',
                            '사진을 삭제해도 기존 분석 결과는 남아 있어요.',
                          ) &&
                          mounted) {
                        await model.remove(photo);
                      }
                    },
              style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              icon: const AppIcon(Icons.close_rounded, size: 18),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _imageError() => Center(
    child: IconButton(
      tooltip: '사진 주소 새로고침',
      onPressed: model.busy ? null : model.load,
      icon: const AppIcon(Icons.refresh_rounded, color: AppColors.muted),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => PopScope(
      canPop: !model.writing,
      child: ManagementPage(
        title: widget.type == BodyPhotoType.goal ? '목표 사진 관리' : '사진 데이터 관리',
        onBack: model.writing ? () {} : () => Navigator.pop(context),
        body: RefreshIndicator(
          onRefresh: model.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      model.hasLoaded ? '올린 사진 ${model.total} / 20장' : '사진 목록',
                      style: ReferenceStyle.text(
                        17,
                        24,
                        weight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      onPressed:
                          model.busy || !model.hasLoaded || model.total == 0
                          ? null
                          : () async {
                              if (await _confirm(
                                    '사진을 모두 삭제할까요?',
                                    '현재 체형 사진을 모두 삭제해요. 기존 분석 결과는 남아 있어요.',
                                  ) &&
                                  mounted) {
                                await model.removeAll();
                              }
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('전체 삭제'),
                    ),
                  ],
                ),
              ),
              if (model.busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
              if (model.error != null &&
                  model.accessCode == 'CONSENT_REQUIRED' &&
                  widget.onConsentRequired != null)
                TextButton(
                  onPressed: widget.onConsentRequired,
                  child: const Text('동의 관리'),
                ),
              if (model.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        model.error!,
                        style: ReferenceStyle.text(
                          13,
                          20,
                          color: AppColors.error,
                        ),
                      ),
                      if (!model.hasLoaded)
                        TextButton(
                          onPressed: model.busy ? null : model.load,
                          child: const Text('목록 다시 불러오기'),
                        ),
                    ],
                  ),
                ),
              if (model.notice != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    model.notice!,
                    style: ReferenceStyle.text(
                      13,
                      20,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              if (model.pending != null) ...[
                PhotoInputField(
                  label: model.pendingSide == BodyPhotoSide.side ? '측면' : '정면',
                  photo: model.pending,
                  onSelect: _add,
                  onRemove: model.discardPending,
                  enabled: !model.busy,
                ),
                const SizedBox(height: 12),
                ReferenceButton(
                  '사진 올리기',
                  onPressed: model.busy || !model.hasLoaded
                      ? null
                      : model.retryUpload,
                ),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 3 / 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final photo in model.items) _photo(photo),
                  if (widget.type == BodyPhotoType.current &&
                      model.hasLoaded &&
                      model.total < 20)
                    Material(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: InkWell(
                        onTap: model.canAdd ? _add : null,
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AppIcon(
                              Icons.add_rounded,
                              color: AppColors.primary,
                            ),
                            Flexible(
                              child: Text(
                                '추가',
                                style: ReferenceStyle.text(
                                  13,
                                  20,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '사진을 삭제해도 기존 분석 결과는 남아 있어요. 머리부터 발끝까지 보이는 밝은 사진을 선택해 주세요.',
                style: ReferenceStyle.text(12, 19, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
