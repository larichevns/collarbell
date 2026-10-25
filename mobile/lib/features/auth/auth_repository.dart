import 'package:flutter/foundation.dart';

/// The signed-in account as the app sees it.
@immutable
class AuthUser {
  const AuthUser({required this.uid, this.email});

  /// Firebase UID, or the derived developer id in dev mode.
  final String uid;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);

  @override
  String toString() => 'AuthUser($uid, $email)';
}

/// Why signing in or signing up failed. The UI maps it to a message.
enum AuthFailure {
  invalidCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  userDisabled,
  tooManyRequests,
  network,
  notAllowed,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.failure, [this.cause]);

  final AuthFailure failure;
  final Object? cause;

  @override
  String toString() => 'AuthException(${failure.name}, $cause)';
}

/// Sign-in and the credentials for API calls.
///
/// Implementations: FirebaseAuthRepository (production) and
/// DevAuthRepository (local development without Firebase).
abstract interface class AuthRepository {
  /// The signed-in user, or null. Emits the current value first.
  Stream<AuthUser?> authStateChanges();

  /// The signed-in user right now, or null.
  AuthUser? get currentUser;

  /// Throws [AuthException] on failure.
  Future<AuthUser> signIn(String email, String password);

  /// Creates the account and signs in. Throws [AuthException] on failure.
  Future<AuthUser> signUp(String email, String password);

  Future<void> signOut();

  /// Sends a letter with a link to set a new password, in [languageCode]
  /// ("ru", "en"). Says nothing about whether the account exists. Throws
  /// [AuthException] on failure.
  Future<void> sendPasswordReset(String email, {String? languageCode});

  /// Asks for the signed-in account's password again, before something only
  /// its owner may do: deleting the account, which the server allows within
  /// 5 minutes of the password. Throws [AuthException] on failure, e.g. a
  /// wrong password.
  Future<void> reauthenticate(String password);

  /// Headers that authenticate an API request as the current user; empty
  /// when signed out.
  Future<Map<String, String>> authHeaders();
}

/// Minimal shape check before a request goes out; the server validates fully.
bool looksLikeEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

/// Minimum length for new passwords (Firebase itself requires 6).
const minPasswordLength = 8;
