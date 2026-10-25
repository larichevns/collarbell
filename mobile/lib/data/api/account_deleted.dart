import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Hears the server say that the account of a request is deleted: 401 with
/// [ProblemTypes.accountDeleted]. The account's sign-in token works for up
/// to an hour after it went (on another phone, or a moment ago on this
/// one), and every request with it gets this answer. After that hour the
/// token can't be renewed: Firebase doesn't know the account
/// ([SignInAccountGone]), which means the same.
///
/// Each request remembers whose it was: the answers to an account's last
/// requests may come after it signed out, or after someone else signed in,
/// and must not sign that person out.
class AccountDeletedInterceptor extends Interceptor {
  AccountDeletedInterceptor({
    required this.user,
    required this.onAccountDeleted,
  });

  /// The uid of the signed-in account, or null.
  final String? Function() user;

  /// Called with the uid of the account whose request heard it.
  final void Function(String uid) onAccountDeleted;

  static const _userKey = 'accountOfRequest';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_userKey] = user();
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    heard(err);
    handler.next(err);
  }

  /// Tells [onAccountDeleted] when [error] says the account is gone. The
  /// API client calls it once more for a download: there the error's body
  /// passes the interceptors unread (it was to be the file).
  void heard(DioException error) {
    final response = error.response;
    final gone =
        error.error is SignInAccountGone ||
        (response?.statusCode == 401 &&
            ProblemDetails.tryParse(response?.data)?.type ==
                ProblemTypes.accountDeleted);
    if (!gone) return;
    final uid = error.requestOptions.extra[_userKey];
    if (uid is String) onAccountDeleted(uid);
  }
}
