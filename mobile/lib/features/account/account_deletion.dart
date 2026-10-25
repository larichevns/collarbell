import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_exception.dart';
import '../../shared/error_messages.dart';
import '../auth/auth_providers.dart';
import 'account_labels.dart';
import 'account_repository.dart';
import 'deleted_account.dart';

/// The account is deleted, but this phone couldn't sign out of it, twice.
/// It will on the next start: the server then answers "account deleted".
class SignOutAfterDeletionFailed implements Exception {
  const SignOutAfterDeletionFailed();
}

/// Where deleting the account stands. It lives outside the screen: the
/// screen may be built anew while the request runs (the app moved to
/// another household, which rebuilds every tab) and still shows the outcome.
@immutable
class AccountDeletionState {
  const AccountDeletionState({
    this.busy = false,
    this.error,
    this.outcomeUnknown = false,
  });

  /// Checking the password, deleting, or signing out after it.
  final bool busy;

  /// Why the last try failed; null before one, and when a new one starts.
  final Object? error;

  /// The last deletion may have gone through though no answer said so (no
  /// connection, a server error): the next try asks the server first.
  final bool outcomeUnknown;
}

/// The deletion of the delete screen. Kept while a try runs, also when the
/// screen is gone for a moment; forgotten with the screen.
final accountDeletionProvider =
    NotifierProvider.autoDispose<AccountDeletionNotifier, AccountDeletionState>(
      AccountDeletionNotifier.new,
    );

class AccountDeletionNotifier extends Notifier<AccountDeletionState> {
  @override
  AccountDeletionState build() => const AccountDeletionState();

  /// A new try: the last one's message goes.
  void start() {
    if (state.busy) return;
    state = AccountDeletionState(outcomeUnknown: state.outcomeUnknown);
  }

  /// After a deletion whose answer was lost, asks the server what deleting
  /// would do now; true when the account is still there, so nothing was
  /// deleted. If it was, the server answers "account deleted" and the app
  /// signs out: Firebase would only call the right password wrong, since
  /// the sign-in went with the account.
  Future<bool> recheck() async {
    final deleted = ref.read(deletedAccountProvider.notifier);
    final uid = ref.read(authUserProvider)?.uid;
    final keep = ref.keepAlive();
    state = const AccountDeletionState(busy: true, outcomeUnknown: true);
    try {
      ref.invalidate(deletionPreviewProvider);
      await ref.read(deletionPreviewProvider.future);
      state = const AccountDeletionState();
      return true;
    } catch (error) {
      if (isAccountDeleted(error) && uid != null) {
        await _signOut(deleted, uid);
      } else {
        state = AccountDeletionState(error: error, outcomeUnknown: true);
      }
      return false;
    } finally {
      keep.close();
    }
  }

  /// Deletes the account while its groups' fates are still [plan], after
  /// the [password] again (Firebase). Then the app signs out here.
  Future<void> delete({required String plan, String? password}) async {
    if (state.busy) return;
    // Everything is read before the first await: at the end the app signs
    // out, and the screen goes with it.
    final auth = ref.read(authRepositoryProvider);
    final repository = ref.read(accountRepositoryProvider);
    final deleted = ref.read(deletedAccountProvider.notifier);
    final uid = ref.read(authUserProvider)?.uid;
    if (uid == null) return;
    final keep = ref.keepAlive();
    state = const AccountDeletionState(busy: true);
    try {
      // The server deletes only within 5 minutes of the password, and only
      // while the groups' fates are still those shown: the plan.
      if (password != null) await auth.reauthenticate(password);
      await repository.deleteAccount(plan);
    } catch (error) {
      debugPrint('Deleting the account failed: $error');
      state = AccountDeletionState(
        error: error,
        outcomeUnknown: _mayHaveGoneThrough(error),
      );
      // Not the password: what the server says about the groups now. After
      // "the groups changed" (409) they show anew.
      if (error is ApiException && !isRecentSignInRequired(error)) {
        ref.invalidate(deletionPreviewProvider);
      }
      keep.close();
      return;
    }
    await _signOut(deleted, uid);
    keep.close();
  }

  /// Gone on the server: the app signs out here, once more if the first try
  /// fails (a locked keychain). Still signed in after that: the screen says
  /// so, and the next answer that the account is gone tries again.
  Future<void> _signOut(DeletedAccountNotifier deleted, String uid) async {
    if (await deleted.signOut(uid) || await deleted.signOut(uid)) return;
    state = const AccountDeletionState(
      error: SignOutAfterDeletionFailed(),
      outcomeUnknown: true,
    );
  }
}

/// Whether a failed deletion may have gone through all the same: the
/// request may have reached the server, but no usable answer came back.
bool _mayHaveGoneThrough(Object error) =>
    error is ApiException &&
    switch (error.kind) {
      ApiErrorKind.network ||
      ApiErrorKind.timeout ||
      ApiErrorKind.server ||
      ApiErrorKind.invalidResponse ||
      ApiErrorKind.unknown => true,
      _ => false,
    };
