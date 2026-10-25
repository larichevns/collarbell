import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// The headers that name the launch of the app a request came from and the
/// app's version (the server's `RequestLogMiddleware.SessionHeader` and
/// `AppVersionHeader`). The admin's "визор" groups a visit by them.
const appSessionHeader = 'X-App-Session';
const appVersionHeader = 'X-App-Version';

/// The app's version: the one in pubspec.yaml, without the build number. A
/// test keeps the two the same.
const appVersion = '0.1.0';

/// A random id of this launch of the app: the same in every request and
/// report until the app is closed, and never kept on the phone.
final appSession = const Uuid().v4();

/// The header that names this launch of the app in every request and on
/// the live connection (the server's `LiveChanges.ClientHeader`). The server
/// hands it back with the live updates a request causes.
const liveClientHeader = 'X-Client';

/// This launch's id for live updates: random, the same until the app is
/// closed, and never kept on the phone. Letters, digits and dashes only, at
/// most 64 of them: the server passes on nothing else. A change the app
/// makes comes back to it with this id, and it skips it: it shows the
/// change already. Not [appSession]: every phone of the household hears
/// this id.
final liveClientId = const Uuid().v4();

/// Names the launch and the version in every request.
class AppSessionInterceptor extends Interceptor {
  AppSessionInterceptor({required this.session, required this.version});

  final String session;
  final String version;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[appSessionHeader] = session;
    options.headers[appVersionHeader] = version;
    handler.next(options);
  }
}
