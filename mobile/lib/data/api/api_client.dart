import 'dart:async';
import 'dart:io' show HttpException, SocketException;

import 'package:dio/dio.dart';

import 'account_deleted.dart';
import 'api_exception.dart';
import 'app_session.dart';
import 'generated/collarbell_api.dart';
import 'household_header.dart';
import 'local_network.dart';
import 'offline_cache.dart';

/// Returns the headers that authenticate a request (see AuthRepository).
typedef AuthHeadersCallback = Future<Map<String, String>> Function();

/// HTTP access to the Collarbell API (`/api/v1`).
///
/// The request methods are generated from `contracts/openapi.json` into
/// `generated/` (see the README there). This class owns the one [Dio] they
/// all share, with the auth-header interceptor, the launch, live-client and
/// household headers, the check for a deleted account and, when given, the
/// offline copy of answers.
/// Repositories call the API through [send] (files through [download]), so
/// every failure reaches them as an [ApiException].
class ApiClient {
  /// [household] gives the id of the household on screen, sent with every
  /// request; [onNotAMember] hears when the server says the user isn't in
  /// the household a request named any more, and [onRoleRefused] when their
  /// role there can't do what it asked. [onAccountDeleted] hears that the
  /// account of a request is deleted, with its uid ([user] when it was
  /// sent).
  ApiClient({
    required String baseUrl,
    required AuthHeadersCallback authHeaders,
    String? Function()? household,
    void Function(String householdId)? onNotAMember,
    void Function()? onRoleRefused,
    String? Function()? user,
    void Function(String uid)? onAccountDeleted,
    HttpClientAdapter? httpClientAdapter,
    OfflineCacheInterceptor? offlineCache,
  }) : _offlineCache = offlineCache,
       _accountDeleted = AccountDeletedInterceptor(
         user: user ?? () => null,
         onAccountDeleted: onAccountDeleted ?? (_) {},
       ),
       _health = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: connectTimeoutFor(baseUrl),
           receiveTimeout: const Duration(seconds: 5),
         ),
       ),
       dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: connectTimeoutFor(baseUrl),
           sendTimeout: const Duration(seconds: 20),
           receiveTimeout: const Duration(seconds: 20),
           headers: {'Accept': 'application/json'},
           contentType: Headers.jsonContentType,
           responseType: ResponseType.json,
         ),
       ) {
    if (httpClientAdapter != null) {
      dio.httpClientAdapter = httpClientAdapter;
      _health.httpClientAdapter = httpClientAdapter;
    }
    dio.interceptors
      ..add(CancelTokenInterceptor())
      // Whose request it is, taken before its sign-in headers: should the
      // account change meanwhile, the request is never taken for the newer
      // one's, and a deleted account signs out only itself.
      ..add(_accountDeleted)
      ..add(AuthHeadersInterceptor(authHeaders))
      // Before the offline copy: copies are kept per household.
      ..add(
        HouseholdHeaderInterceptor(
          household: household ?? () => null,
          onNotAMember: onNotAMember ?? (_) {},
          onRoleRefused: onRoleRefused ?? () {},
        ),
      )
      // For the server's request log: which launch of the app, which version.
      ..add(AppSessionInterceptor(session: appSession, version: appVersion))
      ..add(UploadTimeoutInterceptor())
      ..add(AiTestTimeoutInterceptor())
      ..add(LiveClientInterceptor(liveClientId));
    if (offlineCache != null) {
      dio.interceptors.add(offlineCache);
      offlineCache.probe = checkServer;
    }
  }

  final OfflineCacheInterceptor? _offlineCache;
  final AccountDeletedInterceptor _accountDeleted;

  /// Asks nothing of the API but whether it is up: `GET /health`, which
  /// needs no sign-in and is never answered from a copy.
  final Dio _health;

  /// Whether the server answers now. An answer tells the app it is
  /// reachable again, which reloads every screen.
  Future<bool> checkServer() async {
    try {
      final response = await _health.get<Object?>('/health');
      if (response.statusCode != 200) return false;
      _offlineCache?.onReachability(const ServerReachability.reachable());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// How long to wait for a connection. A server in the local network (the
  /// API on a developer's computer) answers within milliseconds when it is
  /// up, so a longer wait would only delay the error and the offline copy.
  static Duration connectTimeoutFor(String baseUrl) =>
      isLocalNetworkHost(Uri.tryParse(baseUrl)?.host ?? '')
      ? const Duration(seconds: 3)
      : const Duration(seconds: 10);

  final Dio dio;

  /// The generated clients: `api.pets`, `api.files`, `api.documents`...
  late final api = CollarbellApi(dio);

  /// Runs one request of a generated client, e.g.
  /// `send((api) => api.pets.listPets())`. Cancelling [cancelToken] calls the
  /// request off: it fails as [ApiErrorKind.cancelled], and the server stops
  /// what it was doing for it. [household] sends it to that household
  /// rather than the one on screen (see [inHousehold]).
  ///
  /// This is the only place that turns failures into [ApiException]: dio
  /// errors (network, HTTP status, RFC 7807 body) and bodies that don't
  /// match the contract, which make the generated `fromJson` code throw a
  /// [TypeError] or a [FormatException].
  Future<T> send<T>(
    Future<T> Function(CollarbellApi api) request, {
    CancelToken? cancelToken,
    String? household,
  }) async {
    try {
      return await inHousehold(
        household,
        () => cancelToken == null
            ? request(api)
            : runZoned(
                () => request(api),
                zoneValues: {CancelTokenInterceptor.zoneKey: cancelToken},
              ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    } on TypeError catch (error) {
      throw _invalidResponse(error);
    } on FormatException catch (error) {
      throw _invalidResponse(error);
    }
  }

  /// How long a download waits for the next piece of the file. The export
  /// is made while it is sent: between two pieces the server reads and
  /// packs a photo or a scan.
  static const downloadReceiveTimeout = Duration(minutes: 1);

  /// Downloads [path] (a GET with the usual headers) into the file [saveTo]
  /// names, piece by piece: a big file is never in memory whole. [saveTo]
  /// gets the answer's headers, e.g. the file name the server suggests.
  /// [onReceived] hears the bytes so far (the total may be unknown);
  /// cancelling [cancelToken] stops it. A failure deletes what came and is
  /// an [ApiException], as with [send].
  Future<void> download(
    String path,
    FutureOr<String> Function(Headers headers) saveTo, {
    void Function(int received)? onReceived,
    CancelToken? cancelToken,
  }) async {
    try {
      await dio.download(
        path,
        saveTo,
        onReceiveProgress: onReceived == null
            ? null
            : (received, _) => onReceived(received),
        cancelToken: cancelToken,
        options: Options(receiveTimeout: downloadReceiveTimeout),
      );
    } on DioException catch (error) {
      // The interceptors saw the error's body unread; dio has read it now,
      // and its type may say the account is gone.
      _accountDeleted.heard(error);
      // The connection lost halfway (the phone left the Wi-Fi) is no
      // connection, not an unknown failure.
      final cut =
          error.type == DioExceptionType.unknown &&
          (error.error is SocketException || error.error is HttpException);
      throw ApiException.fromDioException(
        cut ? error.copyWith(type: DioExceptionType.connectionError) : error,
      );
    }
  }

  void close() {
    dio.close(force: true);
    _health.close(force: true);
  }

  static ApiException _invalidResponse(Object error) => ApiException(
    ApiErrorKind.invalidResponse,
    message: '$error',
    cause: error,
  );
}

/// Gives a request the cancel token its [ApiClient.send] was given. The
/// generated clients take none, so it comes along in the zone the request
/// runs in.
class CancelTokenInterceptor extends Interceptor {
  static final zoneKey = Object();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.cancelToken ??= Zone.current[zoneKey] as CancelToken?;
    handler.next(options);
  }
}

/// Adds the current auth headers to every request.
class AuthHeadersInterceptor extends Interceptor {
  AuthHeadersInterceptor(this._authHeaders);

  final AuthHeadersCallback _authHeaders;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      options.headers.addAll(await _authHeaders());
      handler.next(options);
    } catch (error, stackTrace) {
      // The rest of the interceptors see the error too: without a network
      // (the sign-in token couldn't be renewed) the offline copy can answer.
      handler.reject(
        DioException(
          requestOptions: options,
          type: error is NetworkUnavailable
              ? DioExceptionType.connectionError
              : DioExceptionType.unknown,
          error: error,
          stackTrace: stackTrace,
          message: 'Could not get the auth headers: $error',
        ),
        true,
      );
    }
  }
}

/// Gives file uploads more time than JSON requests: a 15 MB PDF on a slow
/// mobile connection needs longer than the 20 seconds a JSON request gets.
class UploadTimeoutInterceptor extends Interceptor {
  static const uploadSendTimeout = Duration(minutes: 3);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.data is FormData) options.sendTimeout = uploadSendTimeout;
    handler.next(options);
  }
}

/// Gives the AI requests that wait for the answer more time than others
/// (the connection test, reading a package or a chip number): the server
/// asks the AI models in turn until one answers, which takes minutes when
/// they are busy.
class AiTestTimeoutInterceptor extends Interceptor {
  static const testReceiveTimeout = Duration(minutes: 3);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.endsWith('/ai/test') ||
        options.path.endsWith('/products/scan') ||
        options.path.endsWith('/pets/identifiers/scan')) {
      options.receiveTimeout = testReceiveTimeout;
    }
    handler.next(options);
  }
}

/// Names this launch of the app in every request ([liveClientHeader]), so
/// the live updates the request causes come back to it marked as its own.
class LiveClientInterceptor extends Interceptor {
  LiveClientInterceptor(this.clientId);

  final String clientId;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[liveClientHeader] = clientId;
    handler.next(options);
  }
}
