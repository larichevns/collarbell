import 'package:collarbell/features/auth/auth_repository.dart';
import 'package:collarbell/features/auth/dev_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DevAuthRepository.uidForEmail', () {
    test('is stable and ignores case and surrounding spaces', () {
      final uid = DevAuthRepository.uidForEmail('anna@example.com');

      expect(uid, matches(RegExp(r'^dev-[0-9a-f]{16}$')));
      expect(DevAuthRepository.uidForEmail('  Anna@Example.COM '), uid);
      expect(DevAuthRepository.uidForEmail('ivan@example.com'), isNot(uid));
    });

    test('is the 64-bit FNV-1a hash of the email', () {
      // Reference vector: FNV-1a-64("a") = 0xaf63dc4c8601ec8c.
      expect(DevAuthRepository.uidForEmail('a'), 'dev-af63dc4c8601ec8c');
    });
  });

  test('signs in, sends dev headers, restores and signs out', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = DevAuthRepository(prefs);
    expect(repository.currentUser, isNull);
    expect(await repository.authHeaders(), isEmpty);

    final user = await repository.signInAsDeveloper(' Anna@Example.com');

    expect(user.email, 'anna@example.com');
    expect(user.uid, DevAuthRepository.uidForEmail('anna@example.com'));
    expect(await repository.authHeaders(), {
      'X-Dev-User': user.uid,
      'X-Dev-Email': 'anna@example.com',
    });
    expect(DevAuthRepository(prefs).currentUser, user);

    await repository.signOut();

    expect(repository.currentUser, isNull);
    expect(DevAuthRepository(prefs).currentUser, isNull);
    expect(DevAuthRepository(prefs).lastEmail, 'anna@example.com');
  });

  test('authStateChanges emits the current user first, then changes', () async {
    final repository = DevAuthRepository(await SharedPreferences.getInstance());
    final events = <AuthUser?>[];
    final subscription = repository.authStateChanges().listen(events.add);
    await pumpEventQueue();

    final user = await repository.signIn('dev@collarbell.local', 'ignored');
    await repository.signOut();
    await pumpEventQueue();

    expect(events, [null, user, null]);
    await subscription.cancel();
  });

  test('rejects emails that cannot travel in a header', () async {
    final repository = DevAuthRepository(await SharedPreferences.getInstance());

    expect(
      () => repository.signInAsDeveloper('not-an-email'),
      throwsA(isA<AuthException>()),
    );
    expect(
      () => repository.signInAsDeveloper('аня@пример.рф'),
      throwsA(isA<AuthException>()),
    );
  });
}
