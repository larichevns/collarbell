import 'package:collarbell/app/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('defaults to the local API and dev auth in debug builds', () {
      // flutter test runs a debug build without --dart-define values.
      final config = AppConfig.fromEnvironment();

      expect(config.apiBaseUrl, 'http://localhost:5080');
      expect(config.authMode, AuthMode.dev);
    });

    test('defaults to Firebase auth in release builds', () {
      final config = AppConfig.resolve(debugBuild: false);

      expect(config.apiBaseUrl, AppConfig.defaultApiBaseUrl);
      expect(config.authMode, AuthMode.firebase);
    });

    test('treats empty dart-define values as not set', () {
      final config = AppConfig.resolve(
        apiBaseUrl: '',
        authMode: '',
        debugBuild: true,
      );

      expect(
        config,
        const AppConfig(
          apiBaseUrl: 'http://localhost:5080',
          authMode: AuthMode.dev,
        ),
      );
    });

    test('explicit values win over the build-type default', () {
      final release = AppConfig.resolve(
        apiBaseUrl: 'http://10.0.2.2:5080/',
        authMode: 'dev',
        debugBuild: false,
      );
      expect(release.apiBaseUrl, 'http://10.0.2.2:5080');
      expect(release.authMode, AuthMode.dev);

      final debug = AppConfig.resolve(authMode: 'Firebase', debugBuild: true);
      expect(debug.authMode, AuthMode.firebase);
    });

    test('rejects an unknown auth mode and a relative URL', () {
      expect(
        () => AppConfig.resolve(authMode: 'magic', debugBuild: true),
        throwsArgumentError,
      );
      expect(
        () => AppConfig.resolve(apiBaseUrl: 'localhost:5080', debugBuild: true),
        throwsArgumentError,
      );
    });
  });
}
