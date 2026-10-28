import '../../../../ui/core/theme/app_colors.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../data/profile_avatar_store.dart';
import '../../../../ui/core/widgets/design_reference_page.dart';

/// 같은 계정의 사진 변경을 구독해 모든 표시 위치를 갱신한다.
class AccountAvatar extends StatefulWidget {
  const AccountAvatar({
    super.key,
    required this.owner,
    required this.size,
    required this.fallback,
    this.store,
  });
  final String owner;
  final double size;
  final Widget fallback;
  final ProfileAvatarStore? store;
  @override
  State<AccountAvatar> createState() => _AccountAvatarState();
}

class _AccountAvatarState extends State<AccountAvatar> {
  StreamSubscription<String>? _subscription;
  Uint8List? _bytes;
  int _revision = 0;
  late ProfileAvatarStore _store;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _store = widget.store ?? ProfileAvatarStore(widget.owner);
    _subscription = ProfileAvatarStore.changes.listen((key) {
      if (key == _store.key) _load();
    });
    _load();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    Uint8List? bytes;
    try {
      bytes = await _store.load();
    } catch (_) {
      /* 기본 프로필 유지 */
    }
    if (mounted && revision == _revision) setState(() => _bytes = bytes);
  }

  @override
  void didUpdateWidget(covariant AccountAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner || oldWidget.store != widget.store) {
      _subscription?.cancel();
      _bytes = null;
      _bind();
    }
  }

  @override
  void dispose() {
    _revision++;
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: _bytes == null
        ? widget.fallback
        : ProfileOutline(
            child: ClipOval(
              child: Image.memory(
                _bytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => widget.fallback,
              ),
            ),
          ),
  );
}

/// 사진 미선택 상태는 이름과 관계없이 동일한 기본 프로필로 표시한다.
class ProfilePortrait extends StatelessWidget {
  const ProfilePortrait({super.key, required this.size, this.bytes});
  final double size;
  final Uint8List? bytes;
  @override
  Widget build(BuildContext context) => ProfileOutline(
    child: CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.avatarSurface,
      foregroundColor: ReferenceStyle.blue,
      backgroundImage: bytes == null ? null : MemoryImage(bytes!),
      child: bytes == null
          ? SvgPicture.asset(
              'assets/icons/profile.svg',
              width: size * .5,
              height: size * .5,
              colorFilter: const ColorFilter.mode(
                ReferenceStyle.blue,
                BlendMode.srcIn,
              ),
            )
          : null,
    ),
  );
}

/// 크기를 바꾸지 않고 사진과 기본 프로필 위에 같은 얇은 선을 그린다.
class ProfileOutline extends StatelessWidget {
  const ProfileOutline({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.border, width: .75),
    ),
    child: child,
  );
}
