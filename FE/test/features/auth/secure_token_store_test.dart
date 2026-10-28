import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fe/features/auth/data/token_store.dart';

class FailingSecureStorage extends FlutterSecureStorage {
  bool fail = true;
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (fail) throw StateError('keychain unavailable');
    await super.write(key: key, value: value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('보안 저장 실패 시 옛 토큰을 보존하고 복구 후 이전을 재시도한다', () async {
    final old = MemoryTokenStore();
    await old.write('old-token');
    final storage = FailingSecureStorage();
    final store = SecureTokenStore(legacy: old, storage: storage);
    await expectLater(store.read(), throwsStateError);
    expect(await old.read(), 'old-token');
    storage.fail = false;
    expect(await store.read(), 'old-token');
    expect(await old.read(), isNull);
  });
  test('기존 토큰은 보안 저장을 확인한 뒤 이전 저장소에서 제거한다', () async {
    final old = MemoryTokenStore();
    await old.write('old-token');
    final store = SecureTokenStore(legacy: old);
    expect(await store.read(), 'old-token');
    expect(await old.read(), isNull);
    expect(
      await const FlutterSecureStorage().read(key: SecureTokenStore.storageKey),
      'old-token',
    );
  });
  test('동시 첫 요청들도 토큰 이전 도중 빈 토큰을 읽지 않는다', () async {
    final old = MemoryTokenStore();
    await old.write('old-token');
    final store = SecureTokenStore(legacy: old);
    expect(
      await Future.wait(List.generate(10, (_) => store.read())),
      everyElement('old-token'),
    );
  });
  test('보안 저장소의 새 토큰이 옛 토큰보다 우선하며 로그아웃 시 모두 지운다', () async {
    final old = MemoryTokenStore();
    await old.write('stale-token');
    FlutterSecureStorage.setMockInitialValues({
      SecureTokenStore.storageKey: 'new-token',
    });
    final store = SecureTokenStore(legacy: old);
    expect(await store.read(), 'new-token');
    expect(await old.read(), isNull);
    await store.clear();
    expect(await store.read(), isNull);
  });
  test('진행 중인 이전 뒤 로그아웃을 요청해도 토큰이 되살아나지 않는다', () async {
    final old = MemoryTokenStore();
    await old.write('old-token');
    final store = SecureTokenStore(legacy: old);
    final read = store.read();
    final clear = store.clear();
    expect(await read, 'old-token');
    await clear;
    expect(await store.read(), isNull);
    await store.write('next-session');
    expect(await store.read(), 'next-session');
  });
}
