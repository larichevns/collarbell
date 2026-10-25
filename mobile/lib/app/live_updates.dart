import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../data/api/api_client.dart';
import '../data/api/app_session.dart';
import '../data/api/household_header.dart';
import '../data/live/realtime_client.dart';
import '../data/live/signalr_realtime_client.dart';
import '../features/account/account_repository.dart';
import '../features/ai/ai_repository.dart';
import '../features/auth/auth_providers.dart';
import '../features/billing/billing_repository.dart';
import '../features/care/care_repository.dart';
import '../features/documents/documents_repository.dart';
import '../features/feeding/feeding_repository.dart';
import '../features/household/current_household.dart';
import '../features/household/household_repository.dart';
import '../features/me/profile_sync.dart';
import '../features/notifications/notifications_repository.dart';
import '../features/passport/passport_repository.dart';
import '../features/pets/pets_repository.dart';
import '../features/supplies/supplies_repository.dart';
import '../features/today/today_repository.dart';
import '../features/visits/visits_repository.dart';
import '../features/weight/weight_repository.dart';
import 'app_config.dart';

/// Where live updates stand.
enum LiveStatus {
  /// Not wanted: signed out, the profile not synced yet, or the app away
  /// from the front for over 30 seconds.
  off,

  /// Wanted, but not connected: opening a connection, waiting to try again
  /// (no network, the server away) or for the household to be known.
  connecting,

  /// Connected: what others change shows at once.
  live,

  /// The server refused the connection. Tried again only when another
  /// household is on screen or the app comes back to the front.
  refused,
}

/// Live updates (system-design 3.4): while the app is in front, a
/// connection to the server tells it what someone else in the household
/// changed, and the screens that show it read it again.
///
/// This class decides when to connect and when to read again; the
/// callbacks do the reading (`liveUpdatesProvider`).
/// - It is connected only while a user is signed in and synced, a
///   household is on screen and the app is in front ([update]). A moment
///   away (the camera, the photo picker, the share sheet, a permission
///   dialog) keeps the connection: only after 30 seconds away does it close.
/// - Every connection is a new client with fresh headers: the sign-in token
///   in them expires after an hour. After a failure or a drop it tries
///   again after 1, 2, 5, 10 and 30 seconds, then every 30 seconds. A
///   refusal isn't tried again until another household is on screen or the
///   app comes back to the front.
/// - It skips the changes the app made itself, and collects the others for
///   300 ms before reading them.
/// - Connected again after a time without a connection, it reads the
///   household's screens again: the server keeps no changes.
/// - While it has no connection, Today is read again every 30 seconds.
class LiveUpdates {
  LiveUpdates({
    required this.newClient,
    required this.url,
    required this.authHeaders,
    required this.onChanged,
    required this.onReconnected,
    required this.pollToday,
    String? clientId,
  }) : clientId = clientId ?? liveClientId;

  /// The pauses before the next try after a failure or a drop; the last one
  /// repeats.
  static const retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  /// How long opening a connection may take: without it, a phone on a
  /// network that answers nothing would wait minutes.
  static const connectTimeout = Duration(seconds: 15);

  /// A connection that held this long counts as good: after it drops, the
  /// pauses start again from the first. One that drops sooner goes on to
  /// the longer pauses, so a connection that keeps closing doesn't read
  /// every screen again every second.
  static const steadyAfter = Duration(seconds: 30);

  /// The changes heard within this time are read in one go.
  static const collectFor = Duration(milliseconds: 300);

  /// Without a connection, Today is read again this often (spec 8.3).
  static const pollEvery = Duration(seconds: 30);

  /// How long the connection stays after the app leaves the front. Back from
  /// the camera, the photo picker, the share sheet or a permission dialog
  /// within it, the app finds the connection open, and nothing is read
  /// again: those take a few seconds, and this app takes many photos.
  static const awayGrace = Duration(seconds: 30);

  /// A topic no screen knows, for "anything may have changed": a change
  /// that couldn't be read, or a connection that was away.
  static const anything = '*';

  final RealtimeClientFactory newClient;
  final Uri url;
  final AuthHeadersCallback authHeaders;

  /// Someone else changed [topics] ([LiveTopics]): read again what shows
  /// them. A topic the app doesn't know means anything.
  final void Function(Set<String> topics) onChanged;

  /// Connected again after a time without a connection: read the
  /// household's screens again. [backInApp]: the app has just come back to
  /// the front, and its screens read Today and the role again by themselves.
  final void Function({required bool backInApp}) onReconnected;

  /// No connection: read Today again.
  final void Function() pollToday;

  /// This launch's id: a change that comes back with it is the app's own.
  final String clientId;

  /// What the app is now ([update]).
  String? _user;
  String? _household;
  var _inFront = true;

  /// Runs while the app is away from the front: when it fires, after
  /// [awayGrace], the connection closes ([_gone]).
  Timer? _away;

  var _status = LiveStatus.off;

  /// The client of the connection open or opening; the changes it hears.
  RealtimeClient? _client;
  StreamSubscription<LiveChange>? _subscription;

  /// The tries that failed in a row: the next pause.
  var _attempt = 0;
  Timer? _retry;
  Timer? _steady;
  Timer? _poll;

  /// The topics heard and not read yet.
  final _topics = <String>{};
  Timer? _collecting;

  /// The screens may have missed changes: read them again once connected.
  var _missed = false;

  /// The app has just come back to the front: Today and the role are being
  /// read again already.
  var _backInApp = false;
  var _disposed = false;

  LiveStatus get status => _status;

  /// In front, or away for less than [awayGrace].
  bool get _present => _inFront || _away != null;

  bool get _wanted => !_disposed && _user != null && _present;

  bool get _canConnect => _wanted && _household != null;

  /// Tells it what the app is now: the [user] signed in, once the profile
  /// sync has created them on the server (null otherwise), the [household]
  /// on screen (null until known) and whether the app is [inFront].
  void update({
    required String? user,
    required String? household,
    required bool inFront,
  }) {
    if (_disposed) return;
    final session = user != _user || household != _household;
    final away = _inFront && !inFront;
    final back = !_inFront && inFront;
    // Back before the connection closed: nothing was missed.
    final stayed = back && _away != null;
    _user = user;
    _household = household;
    _inFront = inFront;
    if (back) {
      _away?.cancel();
      _away = null;
    }
    if (session) {
      // Another person or household: every screen loads afresh anyway (the
      // profile sync), so there is nothing to catch up on.
      _missed = false;
      _backInApp = false;
      _restart();
    } else if (away) {
      // Not yet: the app may be back in a moment.
      _away = Timer(awayGrace, _gone);
    } else if (back && !stayed) {
      // The connection closed meanwhile: the screens are read again once
      // connected.
      _backInApp = true;
      _restart();
    }
  }

  void dispose() {
    _disposed = true;
    _away?.cancel();
    _away = null;
    _disconnect();
    _poll?.cancel();
    _poll = null;
    _collecting?.cancel();
    _collecting = null;
    _status = LiveStatus.off;
  }

  /// Away for [awayGrace]: the connection closes. Nothing is heard in the
  /// background, so back in front the screens are read again once
  /// connected.
  void _gone() {
    _away = null;
    if (_status != LiveStatus.off) _missed = true;
    _restart();
  }

  /// Starts over: closes the connection and opens a new one if wanted.
  void _restart() {
    _disconnect();
    _attempt = 0;
    if (_canConnect) {
      unawaited(_connect());
    } else {
      _status = _wanted ? LiveStatus.connecting : LiveStatus.off;
    }
    _schedulePoll();
  }

  Future<void> _connect() async {
    final client = newClient();
    final household = _household!;
    _client = client;
    _status = LiveStatus.connecting;
    // Before connecting: a change can come before Ready answers.
    _subscription = client.changes.listen(
      _heard,
      onDone: () => _closed(client),
    );
    try {
      final headers = {
        // Asked for every connection: a Firebase token lasts an hour.
        ...await authHeaders(),
        householdHeader: household,
        liveClientHeader: clientId,
      };
      // Stopped while the sign-in token was renewed.
      if (!identical(client, _client)) return;
      await client.connect(url, headers).timeout(connectTimeout);
    } on RealtimeRefused catch (refusal) {
      if (identical(client, _client)) _refused(refusal);
      return;
    } catch (error) {
      if (identical(client, _client)) _failed('no connection ($error)');
      return;
    }
    if (!identical(client, _client)) return;
    // It closed again before this ran.
    if (client.state != RealtimeState.connected) {
      _failed('dropped at once');
      return;
    }
    _status = LiveStatus.live;
    _schedulePoll();
    _steady = Timer(steadyAfter, () => _attempt = 0);
    debugPrint('Live updates: connected');
    if (_missed) {
      _missed = false;
      onReconnected(backInApp: _backInApp);
    }
    _backInApp = false;
  }

  /// The connection of [client] closed: when it was the live one, it
  /// dropped. (The ones closed here aren't [_client] any more.)
  void _closed(RealtimeClient client) {
    if (identical(client, _client) && _status == LiveStatus.live) {
      _failed('dropped');
    }
  }

  /// Opening failed or the connection dropped: again after a pause.
  void _failed(String why) {
    _disconnect();
    // Nothing is heard meanwhile; the screens' own reload on coming back
    // is behind too.
    _missed = true;
    _backInApp = false;
    final delay = retryDelays[math.min(_attempt, retryDelays.length - 1)];
    _attempt++;
    debugPrint('Live updates: $why, again in ${delay.inSeconds} s');
    _status = LiveStatus.connecting;
    _retry = Timer(delay, () {
      _retry = null;
      if (_canConnect) unawaited(_connect());
    });
    _schedulePoll();
  }

  /// The server refused: no more tries until [update] brings another
  /// household or the app back to the front.
  void _refused(RealtimeRefused refusal) {
    _disconnect();
    _missed = true;
    _backInApp = false;
    _status = LiveStatus.refused;
    debugPrint('Live updates: refused (${refusal.reason})');
    _schedulePoll();
  }

  /// Closes the connection and calls off a try that waits.
  void _disconnect() {
    _retry?.cancel();
    _retry = null;
    _steady?.cancel();
    _steady = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    final client = _client;
    _client = null;
    if (client != null) unawaited(_close(client));
  }

  static Future<void> _close(RealtimeClient client) async {
    try {
      await client.close();
    } catch (error) {
      debugPrint('Live updates: closing failed: $error');
    }
  }

  void _heard(LiveChange change) {
    // The app made it: its screens show it already.
    if (change.origin == clientId) return;
    // A change that couldn't be read: anything may have changed.
    _topics.addAll(change.topics.isEmpty ? const [anything] : change.topics);
    _collecting ??= Timer(collectFor, _readHeard);
  }

  void _readHeard() {
    _collecting = null;
    final topics = {..._topics};
    _topics.clear();
    if (topics.isNotEmpty && !_disposed) onChanged(topics);
  }

  /// Reads Today again every 30 seconds while a connection is wanted and
  /// there is none: connecting, waiting to try again or refused.
  void _schedulePoll() {
    if (_wanted && _status != LiveStatus.live) {
      _poll ??= Timer.periodic(pollEvery, (_) => pollToday());
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }
}

// --- What each topic reads again --------------------------------------------

final _care = <ProviderOrFamily>[
  carePlansProvider,
  carePlanProvider,
  careRecordsProvider,
  careRecordProvider,
  passportRecordsProvider,
  // The weight a vet noted at a check-up is in the pet's weight log.
  weightLogProvider,
];
final _feeding = <ProviderOrFamily>[
  feedingSchedulesProvider,
  feedingScheduleProvider,
];
final _visits = <ProviderOrFamily>[visitsProvider, visitProvider];
final _supplies = <ProviderOrFamily>[
  suppliesProvider,
  supplyProvider,
  stockProvider,
];

/// What shows each topic: the providers read again when it changes. A
/// family stands for all of its members (every pet's plans): a change says
/// what changed, not for which pet. Today (and Home, made of Today's data
/// and the pets) shows pets, care, feeding, visits and supplies; the weight
/// log shows weighings and the weights of check-up records (care, and
/// visits that took place).
final Map<String, List<ProviderOrFamily>> liveTopicProviders = {
  // Their names and photos are on Today and the visits; a paused or
  // deleted pet's feedings use no food and get no reminders. Deleting the
  // account says how many pets a group would lose.
  LiveTopics.pets: [
    petsProvider,
    petProvider,
    todayProvider,
    ..._visits,
    suppliesProvider,
    supplyProvider,
    reminderLogProvider,
    scanReviewDataProvider,
    deletionPreviewProvider,
  ],
  LiveTopics.passport: [passportProvider, scanReviewDataProvider],
  LiveTopics.care: [
    ..._care,
    todayProvider,
    reminderLogProvider,
    scanReviewDataProvider,
  ],
  // A weighing added, changed or deleted: the Weight tab and the weight on
  // the Overview.
  LiveTopics.weight: [weightLogProvider],
  // A mark or a schedule. The supplies' estimates follow the schedules
  // only, and a schedule changed also sends `supplies`.
  LiveTopics.feeding: [..._feeding, todayProvider, reminderLogProvider],
  // A visit that took place adds care records and moves plans.
  LiveTopics.visits: [..._visits, todayProvider, reminderLogProvider, ..._care],
  // Today lists what to buy; the schedules show the food's name.
  LiveTopics.supplies: [
    ..._supplies,
    todayProvider,
    reminderLogProvider,
    ..._feeding,
  ],
  LiveTopics.documents: [petDocumentsProvider, documentProvider],
  // The scans waiting on the Passport tab and the notes on the Health tab.
  // A scan also uses AI photos of the month: the plan screen and More → AI
  // count them (and a note's requests).
  LiveTopics.imports: [
    petScansProvider,
    petNotesProvider,
    householdPlanProvider,
    aiStatusProvider,
  ],
  // Its people, their roles, the invites, its name and its time zone (what
  // "today" is). /me again re-checks the user's role, like
  // roleCheckProvider; a removed user's next request moves the app to
  // another household (HouseholdHeaderInterceptor). Who is in it decides
  // what deleting the account does to it.
  LiveTopics.household: [
    householdDetailsProvider,
    meProvider,
    todayProvider,
    reminderLogProvider,
    deletionPreviewProvider,
  ],
  // Free or Premium, and the AI photos of the month that a chip or package
  // scan or the AI connection test used (More → AI counts them too).
  LiveTopics.plan: [householdPlanProvider, aiStatusProvider],
};

/// Reads again what shows [topics] ([liveTopicProviders]); a topic the app
/// doesn't know ([LiveUpdates.anything], or a newer server's) reads
/// everything again. Only what a screen on view watches loads again at once;
/// the rest forgets its answer and loads when shown.
///
/// [backInApp] leaves Today and /me out: the screens that show Today (Home
/// and Today, `TodayReload`) and HomeShell read them again when the app
/// comes back to the front.
void readLiveTopics(Ref ref, Set<String> topics, {bool backInApp = false}) {
  final everything = topics.any(
    (topic) => !liveTopicProviders.containsKey(topic),
  );
  final providers = {
    for (final topic in everything ? liveTopicProviders.keys : topics)
      ...?liveTopicProviders[topic],
  };
  if (backInApp) providers.removeAll([todayProvider, meProvider]);
  for (final provider in providers) {
    ref.invalidate(provider);
  }
}

// --- Providers --------------------------------------------------------------

/// The hub's address: at the API's origin, not under `/api/v1`.
Uri liveUpdatesUrl(String apiBaseUrl) =>
    Uri.parse('$apiBaseUrl/hubs/household');

/// Makes the client of each live connection. Tests replace it with fakes.
final realtimeClientFactoryProvider = Provider<RealtimeClientFactory>(
  (ref) => SignalRRealtimeClient.new,
);

/// Live updates for the session ([LiveUpdates]), kept running by the app
/// (`CollarbellApp`). It follows the signed-in user and their profile sync,
/// the household on screen and whether the app is in front, and reads
/// again what others change.
final liveUpdatesProvider = Provider<LiveUpdates>((ref) {
  final live = LiveUpdates(
    newClient: ref.watch(realtimeClientFactoryProvider),
    url: liveUpdatesUrl(ref.watch(appConfigProvider).apiBaseUrl),
    authHeaders: ref.watch(authRepositoryProvider).authHeaders,
    onChanged: (topics) => readLiveTopics(ref, topics),
    // The server keeps no changes: the household's screens are read again.
    onReconnected: ({required backInApp}) =>
        readLiveTopics(ref, const {LiveUpdates.anything}, backInApp: backInApp),
    // Only a Today on view loads again (spec 8.3): HomeScreen and
    // TodayScreen are its watchers, go_router puts the tabs not shown under
    // TickerMode(enabled: false), and flutter_riverpod pauses the
    // subscriptions there until the tab is shown.
    pollToday: () => ref.invalidate(todayProvider),
  );
  ref.onDispose(live.dispose);

  // The user whose profile sync has finished: the server knows them then
  // (the first request creates the user and their household).
  String? synced;
  var inFront = switch (WidgetsBinding.instance.lifecycleState) {
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
    _ => true,
  };
  void update() {
    final user = ref.read(authUserProvider)?.uid;
    live.update(
      user: user != null && user == synced ? user : null,
      household: ref.read(currentHouseholdProvider)?.id,
      inFront: inFront,
    );
  }

  void front(bool value) {
    inFront = value;
    update();
  }

  ref.listen(authUserProvider.select((user) => user?.uid), (_, _) {
    // Signed out, or in as someone else: wait for their sync.
    synced = null;
    update();
  });
  ref.listen(profileSyncProvider, (_, sync) {
    if (sync.isLoading) return;
    synced = ref.read(authUserProvider)?.uid;
    update();
  }, fireImmediately: true);
  ref.listen(
    currentHouseholdProvider.select((household) => household?.id),
    (_, _) => update(),
  );
  // Away from the front for long (LiveUpdates.awayGrace), the connection
  // closes and the phone hears pushes instead.
  final lifecycle = AppLifecycleListener(
    onHide: () => front(false),
    onPause: () => front(false),
    onShow: () => front(true),
    onResume: () => front(true),
  );
  ref.onDispose(lifecycle.dispose);
  return live;
});
