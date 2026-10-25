import 'package:firebase_auth/firebase_auth.dart';

import '../../data/api/api_exception.dart';
import 'auth_repository.dart';

/// Email and password sign-in through Firebase Auth. API requests carry
/// `Authorization: Bearer <Firebase ID token>`.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAuthUser);

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Future<AuthUser> signIn(String email, String password) {
    return _guard(
      () => _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  @override
  Future<AuthUser> signUp(String email, String password) {
    return _guard(
      () => _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      ),
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordReset(String email, {String? languageCode}) async {
    try {
      if (languageCode != null) await _auth.setLanguageCode(languageCode);
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Whether an account exists is nobody's business: an unknown address
      // gets the same answer as a known one.
      if (error.code == 'user-not-found') return;
      throw AuthException(failureForCode(error.code), error);
    }
  }

  @override
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException(AuthFailure.unknown);
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      // A new ID token says when the password was typed (auth_time), which
      // the server checks; the cached one says the time of the sign-in.
      await user.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw AuthException(failureForCode(error.code), error);
    }
  }

  @override
  Future<Map<String, String>> authHeaders() async {
    final user = _auth.currentUser;
    if (user == null) return const {};
    // Cached by the SDK and refreshed automatically shortly before expiry.
    final String? token;
    try {
      token = await user.getIdToken();
    } on FirebaseAuthException catch (error) {
      // The token is due for renewal and there is no network: the request
      // fails as a network error, so the offline copy can answer it.
      if (error.code == 'network-request-failed') {
        throw NetworkUnavailable(error);
      }
      // Firebase doesn't know the account any more: it was deleted. Not
      // 'user-token-expired', which is a password changed elsewhere.
      if (error.code == 'user-not-found') throw SignInAccountGone(error);
      rethrow;
    }
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<AuthUser> _guard(Future<UserCredential> Function() call) async {
    try {
      final user = _toAuthUser((await call()).user);
      if (user == null) throw const AuthException(AuthFailure.unknown);
      return user;
    } on FirebaseAuthException catch (error) {
      throw AuthException(failureForCode(error.code), error);
    }
  }

  /// Maps Firebase Auth error codes to [AuthFailure].
  static AuthFailure failureForCode(String code) {
    return switch (code) {
      'invalid-credential' ||
      'invalid-login-credentials' ||
      'INVALID_LOGIN_CREDENTIALS' ||
      'wrong-password' ||
      'user-not-found' => AuthFailure.invalidCredentials,
      'email-already-in-use' => AuthFailure.emailInUse,
      'weak-password' ||
      'password-does-not-meet-requirements' => AuthFailure.weakPassword,
      'invalid-email' => AuthFailure.invalidEmail,
      'user-disabled' => AuthFailure.userDisabled,
      'too-many-requests' => AuthFailure.tooManyRequests,
      'network-request-failed' => AuthFailure.network,
      'operation-not-allowed' => AuthFailure.notAllowed,
      _ => AuthFailure.unknown,
    };
  }

  static AuthUser? _toAuthUser(User? user) =>
      user == null ? null : AuthUser(uid: user.uid, email: user.email);
}
