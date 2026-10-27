import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fe/features/profile/data/profile_avatar_store.dart';
import 'package:fe/features/profile/presentation/widgets/account_avatar.dart';
import 'profile_identity_test.dart' show avatarFixture, IdentityPreferences;

void main() {
  testWidgets(
    'same account updates all avatars; other accounts stay isolated',
    (t) async {
      final prefs = IdentityPreferences();
      final first = ProfileAvatarStore('first@example.com', preferences: prefs);
      final second = ProfileAvatarStore(
        'second@example.com',
        preferences: prefs,
      );
      Widget view(String owner, ProfileAvatarStore store) => MaterialApp(
        home: Row(
          children: [
            AccountAvatar(
              key: const Key('home'),
              owner: owner,
              size: 22,
              store: store,
              fallback: const Text('home'),
            ),
            AccountAvatar(
              key: const Key('community'),
              owner: owner,
              size: 36,
              store: store,
              fallback: const Text('community'),
            ),
            AccountAvatar(
              owner: 'second@example.com',
              size: 26,
              store: second,
              fallback: const Text('other'),
            ),
          ],
        ),
      );
      await t.pumpWidget(view('first@example.com', first));
      await t.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      await first.save(avatarFixture());
      await t.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.text('other'), findsOneWidget);
      // Account switch cannot retain the previous account's photograph.
      await t.pumpWidget(view('second@example.com', second));
      await t.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      await t.pumpWidget(view('first@example.com', first));
      await t.pumpAndSettle();
      expect(find.byType(Image), findsNWidgets(2));
      await first.save(null);
      await t.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(find.text('community'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
