import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fe/features/auth/data/token_store.dart';

// Run only on a disposable QA simulator: Flutter's integration runner removes
// the installed app on completion. Never target the user's normal simulator.
const isolatedQa = bool.fromEnvironment('ISOLATED_STORAGE_QA');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native secure storage migrates, persists and clears a QA token',
    (tester) async {
      final legacy = PreferencesTokenStore();
      final store = SecureTokenStore(legacy: legacy);
      await store.clear();
      try {
        await legacy.write('isolated-qa-value-not-a-jwt');
        expect(await store.read(), 'isolated-qa-value-not-a-jwt');
        expect(await legacy.read(), isNull);
        expect(await SecureTokenStore().read(), 'isolated-qa-value-not-a-jwt');
        await store.clear();
        expect(await SecureTokenStore().read(), isNull);
      } finally {
        await store.clear();
      }
    },
    skip: !isolatedQa,
  );
}
