import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/app_config.dart';
import '../../features/account/deleted_account.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/household/current_household.dart';
import 'api_client.dart';
import 'offline_cache.dart';

/// The API client for the configured base URL and auth mode, with the
/// household on screen and the offline copy of answers. An answer that the
/// account is deleted signs it out of this phone (`deletedAccountProvider`).
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final auth = ref.watch(authRepositoryProvider);
  final client = ApiClient(
    baseUrl: config.apiBaseUrl,
    authHeaders: auth.authHeaders,
    household: () => ref.read(currentHouseholdProvider)?.id,
    onNotAMember: (householdId) =>
        ref.read(currentHouseholdProvider.notifier).lost(householdId),
    onRoleRefused: () => ref.read(roleCheckProvider.notifier).again(),
    user: () => ref.read(authUserProvider)?.uid,
    onAccountDeleted: (uid) =>
        unawaited(ref.read(deletedAccountProvider.notifier).signOut(uid)),
    offlineCache: OfflineCacheInterceptor(
      store: ref.watch(offlineCacheStoreProvider),
      userKey: () => ref.read(authUserProvider)?.uid,
      onReachability: ref.read(serverReachabilityProvider.notifier).report,
      isReachable: () => ref.read(serverReachabilityProvider).reachable,
    ),
  );
  ref.onDispose(client.close);
  return client;
});

/// Drops the offline copies of [householdId] kept for the signed-in user:
/// they left it or aren't in it any more, so they would only take space.
Future<void> forgetOfflineCopies(WidgetRef ref, String householdId) async {
  final user = ref.read(authUserProvider)?.uid;
  if (user == null) return;
  final prefix = OfflineCacheInterceptor.householdKeyPrefix(user, householdId);
  try {
    await ref
        .read(offlineCacheStoreProvider)
        .clearWhere((key) => key.startsWith(prefix));
  } catch (error) {
    debugPrint('Dropping the offline copies of a household failed: $error');
  }
}

/// Where the offline copies of answers are kept: a folder in the app's own
/// storage. Sign-out clears it.
final offlineCacheStoreProvider = Provider<OfflineCacheStore>((ref) {
  Future<Directory>? folder;
  return FileOfflineCacheStore(
    () => folder ??= getApplicationSupportDirectory().then(
      (support) => Directory('${support.path}/offline_cache'),
    ),
  );
});

/// Whether the server answered the last request. The app shows a banner
/// while it doesn't, with the time of the oldest copy on screen; when it
/// answers again, every screen reloads (see `profileSyncProvider`).
final serverReachabilityProvider =
    NotifierProvider<ServerReachabilityNotifier, ServerReachability>(
      ServerReachabilityNotifier.new,
    );

class ServerReachabilityNotifier extends Notifier<ServerReachability> {
  @override
  ServerReachability build() => const ServerReachability.reachable();

  void report(ServerReachability status) {
    var next = status;
    // Still no answer: the banner keeps the oldest copy's time, whichever
    // request failed last, and a failure without a copy doesn't erase it.
    if (!status.reachable && !state.reachable) {
      final before = state.dataAt;
      final now = status.dataAt;
      next = ServerReachability.unreachable(
        dataAt: before == null || (now != null && now.isBefore(before))
            ? now
            : before,
      );
    }
    if (next != state) state = next;
  }
}
