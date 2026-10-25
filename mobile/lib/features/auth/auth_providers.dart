import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_config.dart';
import '../../app/preferences.dart';
import 'auth_repository.dart';
import 'dev_auth_repository.dart';
import 'firebase_auth_repository.dart';

/// Firebase or dev sign-in, depending on `CB_AUTH_MODE`. Firebase is touched
/// only in firebase mode, because `main()` initialises it only then.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  switch (ref.watch(appConfigProvider).authMode) {
    case AuthMode.firebase:
      return FirebaseAuthRepository(FirebaseAuth.instance);
    case AuthMode.dev:
      final repository = DevAuthRepository(
        ref.watch(sharedPreferencesProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
  }
});

/// The signed-in user, or null. Starts from the repository's current user,
/// so a restored session never flashes the sign-in screen.
final authUserProvider = NotifierProvider<AuthUserNotifier, AuthUser?>(
  AuthUserNotifier.new,
);

class AuthUserNotifier extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    final repository = ref.watch(authRepositoryProvider);
    final subscription = repository.authStateChanges().listen(
      (user) => state = user,
    );
    ref.onDispose(subscription.cancel);
    return repository.currentUser;
  }
}
