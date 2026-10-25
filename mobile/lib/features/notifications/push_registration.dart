import 'dart:async';

import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/app_settings.dart';
import '../../app/preferences.dart';
import '../../l10n/l10n.dart';
import '../../app/router.dart';
import '../../data/api/api_providers.dart';
import '../account/export_files.dart';
import '../auth/auth_providers.dart';
import '../care/care_repository.dart';
import '../household/current_household.dart';
import '../me/profile_sync.dart';
import '../pets/pet_detail_screen.dart';
import '../today/today_repository.dart';
import '../supplies/supplies_repository.dart';
import '../visits/visits_repository.dart';
import 'notifications_repository.dart';
import 'push_platform.dart';

/// Where pushes stand on this phone, for the notification settings screen.
enum PushState {
  /// Not on this phone: iPhones need Apple's key in Firebase (later).
  unsupported,

  /// The user didn't allow notifications.
  denied,

  /// Not allowed yet, and not asked yet: the app asks when the first
  /// reminder is set up (see [askForPushesOnce]).
  notAsked,

  /// No Firebase address yet (no Google Play services, no network). Tried
  /// again on the next start.
  noToken,

  /// The server knows this phone and sends it the household's reminders.
  registered,

  /// The server couldn't be reached. Tried again on the next start.
  failed,
}

const _deviceIdKey = 'push.deviceId';

/// Set once the app has asked for permission to notify: it asks only once
/// per installation. Later Today, the feeding form and the notification
/// settings screen show that it isn't allowed, with a way to the system
/// settings.
const _permissionAskedKey = 'push.permissionAsked';

/// This installation's id for the server. It stays the same when Firebase
/// gives the phone a new address, so the server keeps one entry per phone.
final deviceIdProvider = Provider<String>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  final saved = preferences.getString(_deviceIdKey);
  if (saved != null) return saved;
  final id = const Uuid().v4();
  unawaited(preferences.setString(_deviceIdKey, id));
  return id;
});

/// Creates the notification channels (named in the app's language) and
/// starts listening for pushes. Again when the language changes.
final pushStartProvider = FutureProvider<void>((ref) async {
  final platform = ref.watch(pushPlatformProvider);
  final language = ref.watch(
    appSettingsProvider.select((settings) => settings.language),
  );
  if (!platform.supported) return;
  final l10n = lookupAppLocalizations(
    Locale(
      effectiveLanguageCode(language, PlatformDispatcher.instance.locales),
    ),
  );
  try {
    await platform.start(
      PushChannelNames(
        feeding: l10n.notificationsKindFeeding,
        feedingUpdates: l10n.notificationsChannelFeedingUpdates,
        care: l10n.notificationsKindCare,
        appointments: l10n.notificationsKindVisits,
        supplies: l10n.notificationsKindSupplies,
        general: l10n.notificationsChannelGeneral,
      ),
    );
  } catch (error) {
    debugPrint('Starting push notifications failed: $error');
  }
});

/// After sign-in, and on every start with a session: when the app may
/// notify, tells the server the phone's Firebase address. When Firebase
/// changes the address, it is sent again. It never asks for the permission
/// itself: right after sign-in, with no pets yet, the question would come
/// out of the blue. [askForPushesOnce] asks when the first reminder is set
/// up. Running it again (Today and the notification settings screen do,
/// when the user comes back from the system settings) only checks.
final pushRegistrationProvider = FutureProvider<PushState>((ref) async {
  final uid = ref.watch(authUserProvider.select((user) => user?.uid));
  final platform = ref.watch(pushPlatformProvider);
  if (uid == null || !platform.supported) return PushState.unsupported;

  // Read before the first await: the provider may be rebuilt (sign-out)
  // while a request is in flight.
  final repository = ref.read(notificationsRepositoryProvider);
  final preferences = ref.read(sharedPreferencesProvider);
  final deviceId = ref.read(deviceIdProvider);
  // The server creates the user on their first request; that is the
  // profile sync, so it goes first.
  await ref.watch(profileSyncProvider.future);

  String? token;
  try {
    if (!await platform.permissionGranted()) {
      return (preferences.getBool(_permissionAskedKey) ?? false)
          ? PushState.denied
          : PushState.notAsked;
    }
    token = await platform.token().timeout(const Duration(seconds: 20));
  } catch (error) {
    debugPrint('No push token: $error');
  }
  if (token == null) return PushState.noToken;
  // Rebuilt meanwhile (signed out, or the screen asked again): the new run
  // does the rest.
  if (!ref.mounted) return PushState.noToken;

  final refreshes = platform.tokenRefreshes.listen((fresh) async {
    try {
      await repository.registerDevice(deviceId, fresh);
    } catch (error) {
      debugPrint('Registering the new push token failed: $error');
    }
  });
  ref.onDispose(refreshes.cancel);

  try {
    await repository.registerDevice(deviceId, token);
    return PushState.registered;
  } catch (error) {
    debugPrint('Registering the phone for pushes failed: $error');
    return PushState.failed;
  }
});

/// Signs out after asking the server to stop pushes to this phone. When
/// the server can't be reached, signing out goes on: the next person who
/// signs in here takes the phone over anyway.
Future<void> signOutOfThisPhone(WidgetRef ref) async {
  final platform = ref.read(pushPlatformProvider);
  final repository = ref.read(notificationsRepositoryProvider);
  final signOut = ref.read(localSignOutProvider);
  if (platform.supported) {
    try {
      await repository
          .forgetDevice(ref.read(deviceIdProvider))
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('Forgetting the phone failed, signing out anyway: $error');
    }
  }
  await signOut();
}

/// What signing out does on the phone itself, without asking the server:
/// the push address goes, then the sign-in, then the offline copies and the
/// copies of a data export. [signOutOfThisPhone] asks the server to forget
/// the phone first; after the account was deleted (`deletedAccountProvider`)
/// the server has forgotten its phones already and would only refuse.
///
/// It never fails: a step that does is logged, and the others are done all
/// the same. Whether the sign-in went, the caller sees in `currentUser`.
final localSignOutProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final platform = ref.read(pushPlatformProvider);
    final auth = ref.read(authRepositoryProvider);
    final offlineCopies = ref.read(offlineCacheStoreProvider);
    final exports = ref.read(exportFilesProvider);
    if (platform.supported) {
      // Whatever the server heard: without its address the phone gets no
      // more pushes of this household.
      try {
        await platform.forgetToken().timeout(const Duration(seconds: 5));
      } catch (error) {
        debugPrint('Dropping the push token failed: $error');
      }
    }
    try {
      await auth.signOut();
    } catch (error) {
      // E.g. the iPhone's keychain while it is locked.
      debugPrint('Signing out failed: $error');
    }
    // The next account on this phone must not see this one's data offline.
    // After the sign-out: answers still on their way aren't kept any more.
    try {
      await offlineCopies.clear().timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('Clearing the offline copies failed: $error');
    }
    // Nor a ZIP of it left in the temporary files (`ExportFiles.clearAll`).
    try {
      await exports.clearAll().timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('Deleting the data export copies failed: $error');
    }
  },
);

/// Where a tapped push leads, by its data: feeding (also "who fed", with
/// `update`) → Today, care → the pet's Health tab, a visit → the visit. Null
/// for pushes that lead nowhere (the test push). The screen is in the push's household (`householdId`):
/// the tap moves the app there first ([pushTapsProvider]).
String? routeForPush(Map<String, String> data) {
  final petId = data['petId'];
  final appointmentId = data['appointmentId'];
  final supplyId = data['supplyId'];
  return switch (data['kind']) {
    'feeding' => AppRoutes.today,
    'care' when petId != null => AppRoutes.pet(petId, tab: PetTab.health),
    'care' => AppRoutes.today,
    'appointment' when appointmentId != null => AppRoutes.visit(appointmentId),
    'appointment' => AppRoutes.today,
    'supply' when supplyId != null => AppRoutes.supply(supplyId),
    // Several to buy: Today lists them.
    'supply' || 'supplies' => AppRoutes.today,
    _ => null,
  };
}

/// Opens the screen of a tapped push, also when the push started the app,
/// and reloads what a push is about when one arrives or is tapped: the data
/// may have changed elsewhere (another phone marked a feeding), and a screen
/// kept in memory would still show it as it was. Kept alive by the app for
/// the whole session.
final pushTapsProvider = Provider<void>((ref) {
  final platform = ref.watch(pushPlatformProvider);
  if (!platform.supported) return;

  void refresh(Map<String, String> data) {
    ref.invalidate(todayProvider);
    ref.invalidate(reminderLogProvider);
    final petId = data['petId'];
    if (petId != null) {
      ref.invalidate(carePlansProvider(petId));
      ref.invalidate(careRecordsProvider(petId));
    }
    final appointmentId = data['appointmentId'];
    if (appointmentId != null) {
      ref.invalidate(visitProvider(appointmentId));
      ref.invalidate(visitsProvider);
    }
    if (data['kind'] == 'supply' || data['kind'] == 'supplies') {
      ref.invalidate(suppliesProvider);
      final supplyId = data['supplyId'];
      if (supplyId != null) ref.invalidate(supplyProvider(supplyId));
    }
  }

  void open(Map<String, String> data) {
    // Signed out: sign-in comes first, the push is forgotten.
    if (ref.read(authUserProvider) == null) return;
    // A push of another household (the user is in two, both feed at 08:00):
    // the app moves there first, every screen starts afresh with its data,
    // and a message says where the app is now.
    final householdId = data['householdId'];
    final moved =
        householdId != null &&
        householdId != ref.read(currentHouseholdProvider)?.id;
    if (moved) {
      final known = ref
          .read(meProvider)
          .value
          ?.households
          .where((household) => household.id == householdId)
          .firstOrNull;
      ref
          .read(currentHouseholdProvider.notifier)
          .switchTo(
            known == null
                ? CurrentHousehold(id: householdId)
                : CurrentHousehold.ofSummary(known),
          );
      ref
          .read(householdNoticeProvider.notifier)
          .report(HouseholdOpened(known?.name, known?.role));
    }
    refresh(data);
    final route = routeForPush(data);
    if (route == null) return;
    final router = ref.read(routerProvider);
    // A screen open inside the Today tab (a form) stays: the push's screen
    // opens on top of it. Otherwise from Today, so Back returns there. A
    // form of the other household doesn't stay. Inside Today means the
    // Today tab on screen: Home pushes Today's screens too (a visit, the
    // visit form) on top of itself.
    final insideToday =
        !moved &&
        shownTab(router) == AppRoutes.todayBranch &&
        router.state.matchedLocation.startsWith('${AppRoutes.today}/');
    if (!insideToday) router.go(AppRoutes.today);
    if (route != AppRoutes.today) router.push(route);
  }

  final taps = platform.taps.listen(open);
  final arrivals = platform.arrivals.listen(refresh);
  ref.onDispose(() {
    taps.cancel();
    arrivals.cancel();
  });
  unawaited(
    platform.launchTap().then((data) {
      if (data != null) open(data);
    }),
  );
});

/// After the first feeding, visit or care plan is saved: its reminders need
/// notifications. Asks once per installation, after a line saying why.
/// "Not now" counts as asked: the refusal then shows on Today and in the
/// feeding form, with the way to the system settings. [explained]: the
/// screen has said why already (the onboarding's notifications step, where
/// the person tapped "Turn on notifications"), so the phone asks at once.
Future<void> askForPushesOnce(
  BuildContext context,
  WidgetRef ref, {
  bool explained = false,
}) async {
  // Everything is read before the first await: the form may close meanwhile.
  final platform = ref.read(pushPlatformProvider);
  final preferences = ref.read(sharedPreferencesProvider);
  final container = ProviderScope.containerOf(context, listen: false);
  // Never a reason to fail the save it follows: problems are only logged.
  try {
    if (!platform.supported) return;
    if (preferences.getBool(_permissionAskedKey) ?? false) return;
    if (await platform.permissionGranted()) {
      // Allowed in the system settings meanwhile: register the phone now.
      if (container.read(pushRegistrationProvider).value ==
          PushState.notAsked) {
        container.invalidate(pushRegistrationProvider);
      }
      return;
    }
    if (!context.mounted) return;
    final l10n = context.l10n;
    final allow = explained
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.pushAskTitle),
              content: Text(l10n.pushAskBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.pushAskLater),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.pushAskAllow),
                ),
              ],
            ),
          );
    await preferences.setBool(_permissionAskedKey, true);
    if (allow ?? false) await platform.requestPermission();
  } catch (error) {
    debugPrint('Asking for notifications failed: $error');
  }
  // Registers the phone if allowed; shows the refusal if not.
  container.invalidate(pushRegistrationProvider);
}
