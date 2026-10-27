import '../../../../ui/core/widgets/app_icon.dart';
import '../widgets/account_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';
import '../../../../ui/core/widgets/management_page.dart';
import '../../../photos/data/models/selected_photo.dart';
import '../../data/profile_avatar_store.dart';

class ProfileIdentityResult {
  const ProfileIdentityResult(this.nickname, this.avatar);
  final String nickname;
  final Uint8List? avatar;
}

class ProfileIdentityPage extends StatefulWidget {
  const ProfileIdentityPage({
    super.key,
    required this.nickname,
    required this.avatar,
    required this.store,
    required this.picker,
    required this.rename,
    this.localNickname = false,
  });
  final String nickname;
  final Uint8List? avatar;
  final ProfileAvatarStore store;
  final ProfileAvatarPicker picker;
  final Future<String> Function(String) rename;
  final bool localNickname;
  @override
  State<ProfileIdentityPage> createState() => _ProfileIdentityPageState();
}

class _ProfileIdentityPageState extends State<ProfileIdentityPage> {
  late final _name = TextEditingController(text: widget.nickname);
  late String _savedName = widget.nickname;
  late Uint8List? _avatar = widget.avatar;
  bool _busy = false, _saved = false;
  String? _error;
  bool get _dirty =>
      _name.text.trim() != _savedName || !listEquals(_avatar, widget.avatar);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _back() async {
    if (_busy) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('수정을 그만할까요?'),
          content: const Text('저장하지 않은 변경은 사라져요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('계속 수정'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('나가기'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) {
      setState(() => _saved = true);
      Navigator.pop(context);
    }
  }

  Future<void> _photo() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const AppIcon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(c, 'gallery'),
            ),
            ListTile(
              leading: const AppIcon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(c, 'camera'),
            ),
            if (_avatar != null)
              ListTile(
                leading: const AppIcon(Icons.delete_outline_rounded),
                title: const Text('사진 삭제'),
                onTap: () => Navigator.pop(c, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      setState(() => _avatar = null);
      return;
    }
    setState(() => _busy = true);
    try {
      final photo = await widget.picker.pick(
        choice == 'camera' ? PhotoSource.camera : PhotoSource.gallery,
      );
      if (photo != null && mounted) setState(() => _avatar = photo);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : '사진을 가져오지 못했어요. 사진 권한과 파일을 확인해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    if (name.runes.length < 2 || name.runes.length > 20) {
      setState(() => _error = '닉네임은 2~20자로 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    var renamed = false;
    try {
      if (name != _savedName) {
        _savedName = await widget.rename(name);
        renamed = true;
      }
      if (!mounted) return;
      _name.text = _savedName;
      if (!listEquals(widget.avatar, _avatar)) await widget.store.save(_avatar);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _busy = false;
      });
      Navigator.pop(context, ProfileIdentityResult(_savedName, _avatar));
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = renamed
              ? '닉네임은 변경됐지만 사진을 저장하지 못했어요. 다시 저장해 주세요.'
              : e is StateError
              ? e.message.toString()
              : '프로필을 저장하지 못했어요. 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _saved || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: ManagementPage(
      title: '프로필 수정',
      onBack: _back,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: '프로필 사진 변경',
              child: InkWell(
                key: const Key('profile-avatar-change'),
                borderRadius: BorderRadius.circular(52),
                onTap: _busy ? null : _photo,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    children: [
                      ProfilePortrait(size: 88, bytes: _avatar),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ReferenceStyle.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const AppIcon(
                            Icons.camera_alt_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _busy ? null : _photo,
              child: const Text('사진 변경'),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('profile-nickname'),
            controller: _name,
            enabled: !_busy,
            maxLength: 20,
            onChanged: (_) => setState(() => _error = null),
            decoration: const InputDecoration(
              labelText: '닉네임',
              hintText: '닉네임을 입력해 주세요',
            ),
          ),
          Text(
            widget.localNickname
                ? '현재 기기에 등록된 계정의 닉네임과 중복을 확인해요.'
                : '다른 회원이 사용 중인 닉네임은 저장할 수 없어요.',
            style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
          ),
          const SizedBox(height: 8),
          Text(
            '프로필 사진은 이 기기에 저장돼요.',
            style: ReferenceStyle.text(12, 18, color: ReferenceStyle.muted),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: ReferenceStyle.text(12, 18, color: Colors.red),
              ),
            ),
          const SizedBox(height: 24),
          ReferenceButton('저장', busy: _busy, onPressed: _save),
        ],
      ),
    ),
  );
}
