import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/preferences.dart';
import '../auth/auth_providers.dart';
import '../household/current_household.dart';
import '../notifications/push_registration.dart';

/// The account is deleted: here ("Delete account"), or on another phone,
/// which this one learns from the server's answer (401 account-deleted,
/// `AccountDeletedInterceptor`). Either way the app signs out of it on this
/// phone, and the sign-in screen says why: the state is true until someone
/// signs in.
final deletedAccountProvider = NotifierProvider<DeletedAccountNotifier, bool>(
  DeletedAccountNotifier.new,
);

class DeletedAccountNotifier extends Notifier<bool> {
  /// The account being signed out, and that sign-out: the answers to its
  /// other requests join it rather than start another.
  String? _uid;
  Future<bool>? _signingOut;

  @override
  bool build() {
    ref.listen(authUserProvider, (previous, user) {
      // Someone signed in: the message is read. The same account again (a
      // developer's e-mail) can hear of its deletion once more.
      if (previous == null && user != null) {
        _uid = null;
        _signingOut = null;
        state = false;
      }
    });
    return false;
  }

  /// Signs [uid] out of this phone, its account being gone; true when this
  /// phone is signed out of it now. Once, however many requests heard it.
  /// Not when someone else is signed in: the answer to an account's last
  /// request may come after the next person signed in. With nobody signed
  /// in it still cleans up: Firebase signs a deleted account out by itself
  /// when it can't renew its token.
  ///
  /// The server isn't asked anything: it has forgotten the account and its
  /// phones and would only refuse. The phone forgets them all the same, so
  /// the next person to sign in here starts clean.
  Future<bool> signOut(String uid) {
    if (uid == _uid) return _signingOut ?? Future.value(true);
    final current = ref.read(authUserProvider)?.uid;
    if (current != null && current != uid) return Future.value(false);
    _uid = uid;
    state = true;
    return _signingOut = _signOut(uid);
  }

  Future<bool> _signOut(String uid) async {
    final signOut = ref.read(localSignOutProvider);
    final auth = ref.read(authRepositoryProvider);
    final preferences = ref.read(sharedPreferencesProvider);
    await signOut();
    if (auth.currentUser?.uid == uid) {
      // Still signed in (the sign-in couldn't be dropped): forgotten, so
      // the next answer that the account is gone tries again.
      _uid = null;
      _signingOut = null;
      return false;
    }
    // The household this account showed last: nobody opens it again.
    try {
      await preferences.remove(CurrentHouseholdNotifier.keyFor(uid));
    } catch (error) {
      debugPrint('Forgetting the household on screen failed: $error');
    }
    return true;
  }
}
