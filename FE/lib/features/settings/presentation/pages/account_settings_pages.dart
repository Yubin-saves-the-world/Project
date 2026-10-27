import '../../../photos/data/models/body_photo.dart';
import 'package:flutter/material.dart';
import '../../../../core/media/image_picker_service.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../photos/data/photo_repository.dart';
import '../../../photos/presentation/pages/photo_management_page.dart';
import '../account_settings_dependencies.dart';
import '../account_settings_view_model.dart';

class _AccountView extends StatefulWidget {
  const _AccountView({
    required this.dependencies,
    required this.title,
    required this.builder,
    this.model,
  });
  final AccountSettingsDependencies dependencies;
  final AccountSettingsViewModel? model;
  final String title;
  final Widget Function(BuildContext, AccountSettingsViewModel) builder;
  @override
  State<_AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<_AccountView> {
  late final model =
      widget.model ?? (AccountSettingsViewModel(widget.dependencies)..load());
  @override
  void dispose() {
    if (widget.model == null) model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => PopScope(
      canPop: !model.busy,
      child: ManagementPage(
        title: widget.title,
        onBack: model.busy ? () {} : () => Navigator.maybePop(context),
        body: model.user == null
            ? Center(
                child: model.loading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(model.error ?? '계정 정보를 확인해 주세요.'),
                          TextButton(
                            onPressed: model.load,
                            child: const Text('다시 확인'),
                          ),
                        ],
                      ),
              )
            : widget.builder(context, model),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.model);
  final AccountSettingsViewModel model;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (model.error != null) ...[
        Text(
          model.error!,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: ReferenceStyle.text(12, 18, color: Colors.red),
        ),
        if (!model.serverDeleted)
          TextButton(
            onPressed: model.busy || model.loading ? null : model.load,
            child: const Text('계정 정보 다시 확인'),
          ),
      ],
      if (model.loading) const LinearProgressIndicator(),
    ],
  );
}

class AccountInfoPage extends StatelessWidget {
  const AccountInfoPage({super.key, required this.dependencies, this.model});
  final AccountSettingsDependencies dependencies;
  final AccountSettingsViewModel? model;
  @override
  Widget build(BuildContext context) => _AccountView(
    dependencies: dependencies,
    model: model,
    title: '내 계정 정보',
    builder: (c, m) => _NicknameForm(model: m),
  );
}

class _NicknameForm extends StatefulWidget {
  const _NicknameForm({required this.model});
  final AccountSettingsViewModel model;
  @override
  State<_NicknameForm> createState() => _NicknameFormState();
}

class _NicknameFormState extends State<_NicknameForm> {
  late final nickname = TextEditingController(
    text: widget.model.user!.nickname,
  );
  @override
  void dispose() {
    nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '이메일',
                style: ReferenceStyle.text(14, 21, color: ReferenceStyle.muted),
              ),
              const SizedBox(height: 8),
              Text(m.user!.email ?? '이메일이 제공되지 않은 계정이에요.'),
              const SizedBox(height: 24),
              TextField(
                key: const Key('account-nickname'),
                controller: nickname,
                enabled: m.canWrite,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: '닉네임',
                  helperText: '2~20자로 입력해 주세요.',
                  errorText: m.nicknameError,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '가입일 ${m.user!.createdAt.toUtc().add(const Duration(hours: 9)).toString().substring(0, 10)}',
                style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Notice(m),
              ReferenceButton(
                '닉네임 저장',
                busy: m.busy,
                onPressed: m.canWrite
                    ? () async {
                        FocusScope.of(context).unfocus();
                        if (await m.rename(nickname.text) && context.mounted) {
                          nickname.text = m.user!.nickname;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.fromLTRB(24, 0, 24, 86),
                              content: Text('닉네임을 저장했어요.'),
                            ),
                          );
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({
    super.key,
    required this.dependencies,
    required this.photos,
    required this.picker,
    this.model,
  });
  final AccountSettingsDependencies dependencies;
  final AccountSettingsViewModel? model;
  final PhotoRepository photos;
  final PhotoPicker picker;
  Future<void> change(
    BuildContext context,
    AccountSettingsViewModel m, {
    bool? photo,
    bool? ai,
  }) async {
    final withdrawing = photo == false || ai == false;
    if (withdrawing) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: Text(photo == false ? '사진 이용 동의를 철회할까요?' : 'AI 처리 동의를 철회할까요?'),
          content: Text(
            photo == false
                ? '새 사진을 업로드할 수 없어요. 이미 저장된 사진은 자동 삭제되지 않아요. 사진 데이터 관리에서 직접 삭제할 수 있어요.'
                : '진행 중인 분석이 취소돼요. 새로운 AI 분석·루틴 생성은 제한되며, 이미 만들어진 기록과 결과는 계속 볼 수 있어요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('철회'),
            ),
          ],
        ),
      );
      if (yes != true || !context.mounted) return;
    }
    await m.consent(photo: photo, ai: ai);
  }

  @override
  Widget build(BuildContext context) => _AccountView(
    dependencies: dependencies,
    model: model,
    title: '사진·AI 동의 관리',
    builder: (c, m) => Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('동의를 철회해도 저장된 운동 기록과 분석 결과는 확인할 수 있어요.'),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('신체 사진 이용'),
                subtitle: const Text('새 사진 업로드에 사용해요.'),
                value: m.user!.bodyPhotoAgreed,
                onChanged: m.canWrite ? (v) => change(c, m, photo: v) : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('AI 처리'),
                subtitle: const Text('체형 분석과 맞춤 루틴 생성에 사용해요.'),
                value: m.user!.aiProcessingAgreed,
                onChanged: m.canWrite ? (v) => change(c, m, ai: v) : null,
              ),
              const SizedBox(height: 20),
              const Text(
                '사진 삭제는 별도예요.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                '사진 이용 동의를 철회해도 저장된 사진은 남아 있어요. 사진 데이터 관리에서 확인하고 삭제해 주세요.',
              ),
              TextButton(
                onPressed: m.busy
                    ? null
                    : () => Navigator.push(
                        c,
                        MaterialPageRoute<void>(
                          builder: (_) => PhotoManagementPage(
                            repository: photos,
                            picker: picker,
                            onConsentRequired: () => Navigator.maybePop(c),
                          ),
                        ),
                      ),
                child: const Text('사진 데이터 관리'),
              ),
              TextButton(
                onPressed: m.busy
                    ? null
                    : () => Navigator.push(
                        c,
                        MaterialPageRoute<void>(
                          builder: (_) => PhotoManagementPage(
                            repository: photos,
                            picker: picker,
                            type: BodyPhotoType.goal,
                          ),
                        ),
                      ),
                child: const Text('목표 사진 관리'),
              ),
              const SizedBox(height: 24),
              const Text(
                '이용약관·개인정보 처리 동의는 회원 탈퇴로 철회할 수 있어요.',
                style: TextStyle(color: ReferenceStyle.muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _Notice(m),
        ),
      ],
    ),
  );
}

class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key, required this.dependencies, this.model});
  final AccountSettingsDependencies dependencies;
  final AccountSettingsViewModel? model;
  @override
  Widget build(BuildContext context) => _AccountView(
    dependencies: dependencies,
    model: model,
    title: '회원 탈퇴',
    builder: (c, m) => _DeleteForm(model: m),
  );
}

class _DeleteForm extends StatefulWidget {
  const _DeleteForm({required this.model});
  final AccountSettingsViewModel model;
  @override
  State<_DeleteForm> createState() => _DeleteFormState();
}

class _DeleteFormState extends State<_DeleteForm> {
  bool checked = false;
  Future<void> remove() async {
    final m = widget.model;
    if (!m.serverDeleted) {
      final yes = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          scrollable: true,
          title: const Text('정말 탈퇴할까요?'),
          content: const Text('계정과 개인정보·사진·분석·운동 기록이 삭제되며 되돌릴 수 없어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('탈퇴하기'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    await m.removeAccount();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                m.serverDeleted ? '계정이 삭제되었어요' : '탈퇴 전 확인',
                style: ReferenceStyle.text(24, 32, weight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Text(
                m.serverDeleted
                    ? '기기에 남은 해당 계정의 정보를 정리하고 로그인 화면으로 이동해요. 오류가 나면 아래에서 다시 시도해 주세요.'
                    : '계정·신체정보·사진·분석 결과·운동 기록이 삭제되고 즉시 로그인이 불가능해져요. 같은 이메일로 다시 가입할 수 있지만 이전 기록은 복구할 수 없어요.',
              ),
              const SizedBox(height: 24),
              if (!m.serverDeleted)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  onChanged: m.busy
                      ? null
                      : (v) => setState(() => checked = v ?? false),
                  title: const Text('삭제되는 내용을 확인했어요.'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Notice(m),
              ReferenceButton(
                m.serverDeleted ? '기기 정보 정리 다시 시도' : '회원 탈퇴',
                key: const Key('account-delete-submit'),
                busy: m.busy,
                onPressed: !m.busy && (m.serverDeleted || checked && m.canWrite)
                    ? remove
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
