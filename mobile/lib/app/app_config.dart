import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How the app signs users in and authenticates API calls.
enum AuthMode {
  /// Firebase Auth; requests carry `Authorization: Bearer <ID token>`.
  firebase,

  /// Local development without Firebase; requests carry `X-Dev-User` and
  /// `X-Dev-Email`. The API accepts these headers only in Development.
  dev,
}

/// Build-time configuration from `--dart-define` values:
///
/// * `CB_API_BASE_URL`: API origin, default `http://localhost:5080`;
/// * `CB_AUTH_MODE`: `firebase` or `dev`; default `dev` in debug builds and
///   `firebase` in profile and release builds.
@immutable
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.authMode});

  /// Reads the `--dart-define` values of this build.
  factory AppConfig.fromEnvironment() {
    return AppConfig.resolve(
      apiBaseUrl: const String.fromEnvironment(apiBaseUrlKey),
      authMode: const String.fromEnvironment(authModeKey),
      debugBuild: kDebugMode,
    );
  }

  /// Applies the defaults and validates the values. Empty strings count as
  /// "not set", which is what `String.fromEnvironment` returns.
  factory AppConfig.resolve({
    String? apiBaseUrl,
    String? authMode,
    required bool debugBuild,
  }) {
    final rawUrl = (apiBaseUrl ?? '').trim();
    final url = rawUrl.isEmpty ? defaultApiBaseUrl : rawUrl;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      throw ArgumentError.value(
        apiBaseUrl,
        apiBaseUrlKey,
        'must be an absolute http(s) URL, e.g. $defaultApiBaseUrl',
      );
    }

    final rawMode = (authMode ?? '').trim().toLowerCase();
    final AuthMode mode;
    if (rawMode.isEmpty) {
      mode = debugBuild ? AuthMode.dev : AuthMode.firebase;
    } else {
      mode = AuthMode.values.firstWhere(
        (m) => m.name == rawMode,
        orElse: () => throw ArgumentError.value(
          authMode,
          authModeKey,
          'must be "firebase" or "dev"',
        ),
      );
    }

    return AppConfig(
      apiBaseUrl: url.endsWith('/') ? url.substring(0, url.length - 1) : url,
      authMode: mode,
    );
  }

  static const apiBaseUrlKey = 'CB_API_BASE_URL';
  static const authModeKey = 'CB_AUTH_MODE';
  static const defaultApiBaseUrl = 'http://localhost:5080';

  /// API origin without a trailing slash, e.g. `http://localhost:5080`.
  final String apiBaseUrl;

  final AuthMode authMode;

  @override
  bool operator ==(Object other) =>
      other is AppConfig &&
      other.apiBaseUrl == apiBaseUrl &&
      other.authMode == authMode;

  @override
  int get hashCode => Object.hash(apiBaseUrl, authMode);

  @override
  String toString() => 'AppConfig($apiBaseUrl, ${authMode.name})';
}

/// The configuration of this build. `main()` overrides it with the value it
/// has already read, so the app and its bootstrap agree.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
