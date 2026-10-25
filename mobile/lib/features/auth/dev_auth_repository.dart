import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_repository.dart';

/// Local development sign-in without Firebase.
///
/// The developer account is identified by an email; its uid is derived from
/// the email, so the same email maps to the same API user on every device
/// and emulator. Passwords are not checked. API requests carry
/// `X-Dev-User: <uid>` and `X-Dev-Email: <email>`; the API accepts them only
/// when it runs in the Development environment.
class DevAuthRepository implements AuthRepository {
  DevAuthRepository(this._prefs) : _current = _restore(_prefs);

  static const defaultEmail = 'dev@collarbell.local';
  static const uidKey = 'auth.dev.uid';
  static const emailKey = 'auth.dev.email';
  static const lastEmailKey = 'auth.dev.lastEmail';

  final SharedPreferences _prefs;
  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  /// The email to prefill: the last developer email used on this device.
  String get lastEmail => _prefs.getString(lastEmailKey) ?? defaultEmail;

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() {
    late final StreamController<AuthUser?> controller;
    StreamSubscription<AuthUser?>? subscription;
    controller = StreamController<AuthUser?>(
      onListen: () {
        controller.add(_current);
        subscription = _changes.stream.listen(controller.add);
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  /// Signs in as the developer account for [email].
  Future<AuthUser> signInAsDeveloper(String email) async {
    final normalized = normalizeEmail(email);
    if (!isValidDeveloperEmail(normalized)) {
      throw const AuthException(AuthFailure.invalidEmail);
    }
    final user = AuthUser(uid: uidForEmail(normalized), email: normalized);
    await _prefs.setString(uidKey, user.uid);
    await _prefs.setString(emailKey, normalized);
    await _prefs.setString(lastEmailKey, normalized);
    _emit(user);
    return user;
  }

  /// Any password signs in as the developer account for [email].
  @override
  Future<AuthUser> signIn(String email, String password) =>
      signInAsDeveloper(email);

  /// Same as [signIn]: the API creates the user on the first request.
  @override
  Future<AuthUser> signUp(String email, String password) =>
      signInAsDeveloper(email);

  /// Dev users have no passwords.
  @override
  Future<void> sendPasswordReset(String email, {String? languageCode}) =>
      Future.error(const AuthException(AuthFailure.notAllowed));

  /// Dev users have no passwords: the API takes every request of theirs as
  /// signed in just now.
  @override
  Future<void> reauthenticate(String password) async {}

  @override
  Future<void> signOut() async {
    await _prefs.remove(uidKey);
    await _prefs.remove(emailKey);
    _emit(null);
  }

  @override
  Future<Map<String, String>> authHeaders() async {
    final user = _current;
    if (user == null) return const {};
    final email = user.email;
    return {
      'X-Dev-User': user.uid,
      if (email != null && email.isNotEmpty) 'X-Dev-Email': email,
    };
  }

  Future<void> dispose() => _changes.close();

  void _emit(AuthUser? user) {
    _current = user;
    _changes.add(user);
  }

  static AuthUser? _restore(SharedPreferences prefs) {
    final uid = prefs.getString(uidKey);
    if (uid == null || uid.isEmpty) return null;
    return AuthUser(uid: uid, email: prefs.getString(emailKey));
  }

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  /// A plausible email that is plain ASCII, because it travels in a header.
  static bool isValidDeveloperEmail(String email) =>
      looksLikeEmail(email) && email.codeUnits.every((unit) => unit < 128);

  /// The stable uid of a developer email: `dev-` and the 64-bit FNV-1a hash
  /// of the normalised (trimmed, lower-case) UTF-8 email in hex.
  static String uidForEmail(String email) {
    // FNV-1a 64; int arithmetic wraps modulo 2^64 on the Dart VM.
    var hash = -0x340d631b7bdddcdb; // offset basis 0xcbf29ce484222325
    const prime = 0x100000001b3;
    for (final byte in utf8.encode(normalizeEmail(email))) {
      hash = (hash ^ byte) * prime;
    }
    String half(int value) =>
        (value & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return 'dev-${half(hash >> 32)}${half(hash)}';
  }
}
