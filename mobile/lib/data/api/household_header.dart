import 'dart:async';

import 'package:dio/dio.dart';

import 'api_exception.dart';

/// The header that names the household of a request (the server's
/// `CurrentUserAccessor.HouseholdHeader`). Without it the server answers for
/// the user's first household.
const householdHeader = 'X-Household';

/// Runs [body] with its requests naming [householdId] rather than the
/// household on screen: a form, a dialog or a screen of one household sends
/// its changes there, even if the app has moved to another meanwhile. There
/// a stale change fails (403 or 404) instead of landing in the other
/// household. Null: the household on screen.
Future<T> inHousehold<T>(String? householdId, Future<T> Function() body) =>
    householdId == null
    ? body()
    : runZoned(
        body,
        zoneValues: {HouseholdHeaderInterceptor.pinKey: householdId},
      );

/// Names the household of every request: the one [inHousehold] (or
/// `ApiClient.send`'s `household`) pinned it to, else the one on screen. It
/// also tells the app when the server refuses a request: the user isn't in
/// the household it named any more (they left it on another phone, or an
/// owner removed them), or their role there can't do it.
class HouseholdHeaderInterceptor extends Interceptor {
  HouseholdHeaderInterceptor({
    required this.household,
    required this.onNotAMember,
    required this.onRoleRefused,
  });

  /// The zone value of [inHousehold]: the household a request is pinned to.
  static final pinKey = Object();

  /// The id of the household on screen; null until the app knows it.
  final String? Function() household;

  /// Called with the id the refused request named.
  final void Function(String householdId) onNotAMember;

  /// Called when the user's role can't do what a request asked: an owner
  /// may have changed it on another phone.
  final void Function() onRoleRefused;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final pinned = Zone.current[pinKey];
    final id = pinned is String ? pinned : household();
    if (id != null) options.headers.putIfAbsent(householdHeader, () => id);
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (response?.statusCode == 403) {
      final named = err.requestOptions.headers[householdHeader];
      switch (ProblemDetails.tryParse(response?.data)?.type) {
        case ProblemTypes.notAHouseholdMember when named is String:
          onNotAMember(named);
        case ProblemTypes.roleForbidden:
          onRoleRefused();
      }
    }
    handler.next(err);
  }
}
