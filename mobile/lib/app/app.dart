import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/app_events.dart';
import '../features/me/profile_sync.dart';
import '../features/notifications/push_registration.dart';
import '../l10n/l10n.dart';
import '../theme/collarbell_theme.dart';
import 'app_settings.dart';
import 'live_updates.dart';
import 'router.dart';

/// Turns off Riverpod's automatic retries: screens show the error with a
/// "Try again" button instead.
Duration? noAutomaticRetry(int retryCount, Object error) => null;

/// How the themes load fonts. Tests override it with [plainFontResolver].
final fontResolverProvider = Provider<CbFontResolver>(
  (ref) => platformFontResolver,
);

/// Light (default) and dark themes.
final appThemesProvider = Provider<({ThemeData light, ThemeData dark})>((ref) {
  final fonts = ref.watch(fontResolverProvider);
  return (
    light: CollarbellTheme.light(fonts: fonts),
    dark: CollarbellTheme.dark(fonts: fonts),
  );
});

class CollarbellApp extends ConsumerWidget {
  const CollarbellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final themes = ref.watch(appThemesProvider);
    final router = ref.watch(routerProvider);
    // Keeps the profile sync running for the whole session: it fires after
    // sign-in and on start with a restored session.
    ref.listen(profileSyncProvider, (_, _) {});
    // Pushes: the channels, registering this phone after sign-in, and
    // opening the screen of a tapped push.
    ref.listen(pushStartProvider, (_, _) {});
    ref.listen(pushRegistrationProvider, (_, _) {});
    ref.listen(pushTapsProvider, (_, _) {});
    // The visor: screens, a few actions, errors and crashes go to the
    // server for support, never what the person typed.
    ref.listen(appEventsProvider, (_, _) {});
    // Live updates: while the app is in front, what others in the household
    // change shows at once.
    ref.listen(liveUpdatesProvider, (_, _) {});

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: themes.light,
      darkTheme: themes.dark,
      themeMode: settings.themeMode,
      locale: settings.language.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: CollarbellTheme.systemOverlayStyle(Theme.of(context)),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
