import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../app/app_settings.dart';
import '../../data/api/api_providers.dart';
import '../auth/auth_providers.dart';
import '../household/current_household.dart';
import 'me_repository.dart';

/// Reads the device's IANA time zone, e.g. `Europe/Berlin`.
final deviceTimeZoneProvider = Provider<Future<String> Function()>(
  (ref) =>
      () async => (await FlutterTimezone.getLocalTimezone()).identifier,
);

/// After sign-in, and on start with a restored session, sends the device
/// time zone and the UI language to `PUT /api/v1/me`.
///
/// Failures are logged and ignored; the next sign-in or app start retries.
/// Data providers wait for it, so the API creates the user and household on
/// one request instead of several racing ones.
///
/// That makes it the way to reload every screen: when the server answers
/// again after it didn't (the Mac woke up, the phone came home), the screens
/// may show offline copies, so the sync runs again and every data provider
/// with it. The same when the app moves to another household.
final profileSyncProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(authUserProvider.select((user) => user?.uid));
  if (uid == null) return;
  ref.listen(serverReachabilityProvider, (previous, next) {
    if (next.reachable && previous != null && !previous.reachable) {
      ref.invalidateSelf();
    }
  });

  // The household the screens are about to load: the one the requests
  // name, or, until the answer says which, the server's choice.
  final asked = ref.read(currentHouseholdProvider)?.id;
  var shown = asked;
  // Another household (picked, or the user isn't in this one any more):
  // every screen reloads.
  ref.listen(currentHouseholdProvider.select((household) => household?.id), (
    _,
    next,
  ) {
    if (next != shown) ref.invalidateSelf();
  });

  // Read everything before the first await: the provider may be rebuilt
  // (sign-out) while a request is in flight.
  final me = ref.read(meRepositoryProvider);
  final readTimeZone = ref.read(deviceTimeZoneProvider);
  final locale = effectiveLanguageCode(
    ref.read(appSettingsProvider).language,
    PlatformDispatcher.instance.locales,
  );

  String? timeZone;
  try {
    timeZone = await readTimeZone();
  } catch (error) {
    debugPrint('Profile sync: no device time zone ($error)');
  }
  try {
    final profile = await me.updateMe(locale: locale, timeZone: timeZone);
    // Before the screens load: their requests name this household from the
    // start, and the role is known before any button shows.
    if (ref.mounted) {
      shown = profile.household.id;
      ref
          .read(currentHouseholdProvider.notifier)
          .remember(profile.household, asked: asked);
    }
  } catch (error) {
    debugPrint('Profile sync failed, ignored: $error');
  }
});

/// The signed-in user and every household they are in (`GET /api/v1/me`),
/// for More and the list to switch households. Loads after the profile
/// sync, so it reloads with every screen, and again on a role check
/// (`roleCheckProvider`); its answer keeps the name of the household on
/// screen and the user's role there up to date. The app shell keeps it
/// loaded while the user is signed in.
final meProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final repository = ref.watch(meRepositoryProvider);
  ref.watch(roleCheckProvider);
  await ref.watch(profileSyncProvider.future);
  final asked = ref.read(currentHouseholdProvider)?.id;
  final me = await repository.getMe();
  if (ref.mounted) {
    ref
        .read(currentHouseholdProvider.notifier)
        .remember(me.household, asked: asked);
  }
  return me;
});
