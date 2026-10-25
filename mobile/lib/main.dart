import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'app/preferences.dart';
import 'data/api/app_events.dart';
import 'firebase_options.dart';

Future<void> main() => runCollarbell();

/// Starts the app. Integration tests pass [overrides] to replace parts of
/// it, e.g. a fake media picker instead of the camera.
Future<void> runCollarbell({List<Override> overrides = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts ship with the app (assets/google_fonts); their licences go to
  // the licences screen.
  LicenseRegistry.addLicense(_fontLicenses);

  // CB_API_BASE_URL and CB_AUTH_MODE come from --dart-define (see README).
  final config = AppConfig.fromEnvironment();
  // Firebase signs users in (firebase mode) and delivers pushes, which work
  // on Android only for now: there it starts in dev mode too.
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (config.authMode == AuthMode.firebase || android) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error) {
      // Without Firebase in dev mode the app runs, only without pushes.
      if (config.authMode == AuthMode.firebase) rethrow;
      debugPrint('Firebase did not start, no pushes: $error');
    }
  }
  final preferences = await SharedPreferences.getInstance();

  // Crashes go to the visor too, while it runs (data/api/app_events.dart).
  watchCrashes();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(preferences),
        ...overrides,
      ],
      retry: noAutomaticRetry,
      child: const CollarbellApp(),
    ),
  );
}

/// The OFL licences of the bundled fonts, shown on the licences screen.
Stream<LicenseEntry> _fontLicenses() async* {
  for (final (font, package) in const [
    ('arimo', 'Arimo'),
    ('jetbrainsmono', 'JetBrains Mono'),
  ]) {
    final text = await rootBundle.loadString(
      'assets/google_fonts/OFL-$font.txt',
    );
    yield LicenseEntryWithLineBreaks([package], text);
  }
}
