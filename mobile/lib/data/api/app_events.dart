import 'dart:async';
import 'dart:collection';
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import 'api_exception.dart';
import 'api_providers.dart';
import 'app_session.dart';
import 'generated/export.dart' as dto;

// What the app tells the server about itself for the admin's "визор": the
// screens opened, a few actions, the error messages the person saw, and
// crashes. The server keeps them a week, for support. Never what the person
// typed or anything about their pets: a screen is its route's pattern, an
// action a fixed name, an error its kind and status, a crash its type and
// the lines of the app it went through.

/// What a report is about (the server's `AppEventKind`).
enum AppEventKind { screen, action, error, crash }

/// The actions the visor hears of, each by a fixed name: never which pet,
/// plan or item.
enum AppAction {
  /// A feeding marked "Fed" on Today.
  fed('fed'),

  /// "All fed" for one time of day.
  fedAll('fed-all'),

  /// A care plan's "Done" saved.
  done('done'),

  /// "How did the visit go?" saved: the visit took place.
  visitTookPlace('visit-took-place'),

  /// A purchase of a supply saved.
  bought('bought'),

  /// A pet added or changed.
  petSaved('pet-saved'),

  /// AI asked to read photos: of the passport, a package or a chip number.
  scanStarted('scan-started'),

  /// AI asked to read a note the person wrote or dictated about a pet.
  noteStarted('note-started'),

  /// An invite code made for the group.
  inviteCreated('invite-created'),

  /// A group joined with a code.
  joinedGroup('joined-group'),

  /// Another group picked to show, or a new one made.
  groupSwitched('group-switched');

  const AppAction(this.event);

  /// The name the server gets.
  final String event;
}

/// One report, as it waits to be sent.
@immutable
class AppEvent {
  const AppEvent({
    required this.at,
    required this.kind,
    required this.name,
    this.detail,
  });

  /// When it happened, by the phone's clock.
  final DateTime at;
  final AppEventKind kind;

  /// A screen's pattern (`/pets/:petId`), an action (`fed`), an error's
  /// kind (`network`) or a crash's type (`StateError`).
  final String name;

  /// An error's status, problem type and trace id; the lines of the app a
  /// crash went through.
  final String? detail;

  @override
  String toString() =>
      'AppEvent(${kind.name} $name${detail == null ? '' : ' · $detail'})';
}

/// The visor's side of the app.
abstract interface class AppEvents {
  /// A screen came up: its route's pattern, e.g. `/pets/:petId/edit`.
  void screen(String pattern);

  /// The person did one of the few things the visor hears of.
  void action(AppAction action);

  /// An error message for [error] is on the screen.
  void errorShown(Object error);

  /// The app failed with [error] (see [watchCrashes]).
  void crash(Object error, StackTrace? stack);
}

/// Tells nothing to anyone: where the visor is off ([appEventsOnProvider]).
class NoAppEvents implements AppEvents {
  const NoAppEvents();

  @override
  void screen(String pattern) {}

  @override
  void action(AppAction action) {}

  @override
  void errorShown(Object error) {}

  @override
  void crash(Object error, StackTrace? stack) {}
}

/// Keeps the reports in memory and sends them in batches, so the app makes
/// no request of its own for each screen: every 30 seconds, as soon as 20
/// wait, and when the app goes to the background. Only for a signed-in
/// person ([user]): nothing is kept while nobody is, and what waits is
/// dropped, unsent, when they sign out.
///
/// It may lose reports, but never costs the person a wait: at most 200 are
/// kept (a new one pushes the oldest out), and a batch the server didn't
/// take goes once more with the next one, then is dropped.
class AppEventReporter implements AppEvents {
  AppEventReporter({
    required this.send,
    required this.user,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// At most this many wait; a new one pushes the oldest out.
  static const keep = 200;

  /// This many waiting are sent at once.
  static const sendAt = 20;

  /// What waits is sent this long after the first of it came.
  static const sendAfter = Duration(seconds: 30);

  /// The server takes up to 50 at a time.
  static const perRequest = 50;

  /// The server takes 6 requests a minute from a person: one fewer leaves
  /// room for a slow network. A burst (a crash on every frame) waits.
  static const requestsPerMinute = 5;

  /// What the server keeps of a name and a detail.
  static const maxName = 100;
  static const maxDetail = 500;

  /// Sends one batch (up to [perRequest]); throws when it didn't go
  /// through.
  final Future<void> Function(List<AppEvent> events) send;

  /// The signed-in person's id, or null.
  final String? Function() user;

  final DateTime Function() _clock;

  /// What waits, oldest first, and whether it failed to go once already.
  final _waiting = ListQueue<({AppEvent event, bool failed})>();

  /// Whose reports wait: they go with the person.
  String? _owner;

  /// Moves on when they go, so a batch on its way for the person before
  /// isn't put back.
  var _round = 0;

  /// The screen told last: the router repeats it when only the query
  /// changes.
  String? _screen;

  Timer? _timer;
  var _sending = false;
  var _disposed = false;

  /// When the requests of the last minute went.
  final _requests = ListQueue<DateTime>();

  /// When each crash was told last.
  final _crashes = <String, DateTime>{};

  /// Errors told already: a screen builds its message again on every
  /// rebuild, and each error is told once.
  final _told = Expando<bool>('app events');

  /// What waits now, oldest first.
  List<AppEvent> get waiting => [for (final entry in _waiting) entry.event];

  @override
  void screen(String pattern) {
    if (!_signedIn() || pattern.isEmpty || pattern == _screen) return;
    _screen = pattern;
    _add(AppEventKind.screen, pattern);
  }

  @override
  void action(AppAction action) {
    if (_signedIn()) _add(AppEventKind.action, action.event);
  }

  @override
  void errorShown(Object error) {
    if (!_signedIn() || !_firstTime(error)) return;
    _add(AppEventKind.error, errorName(error), errorDetail(error));
  }

  @override
  void crash(Object error, StackTrace? stack) {
    if (!_signedIn()) return;
    final name = '${error.runtimeType}';
    final detail = appFrames(stack);
    // A broken widget fails on every frame: the same crash is told once a
    // minute.
    final now = _clock();
    _crashes.removeWhere(
      (_, at) => now.difference(at) >= const Duration(minutes: 1),
    );
    final key = '$name $detail';
    if (_crashes.containsKey(key)) return;
    _crashes[key] = now;
    _add(AppEventKind.crash, name, detail);
  }

  /// The person signed in or out: what waits for the one before goes.
  void userChanged() => _signedIn();

  /// Sends what waits now, [perRequest] at a time. While a send is under
  /// way, that one takes what comes meanwhile.
  Future<void> flush() async {
    if (_sending) return;
    _timer?.cancel();
    _timer = null;
    if (!_signedIn()) return;
    _sending = true;
    try {
      while (_waiting.isNotEmpty && !_disposed && _mayRequest()) {
        final round = _round;
        final batch = <({AppEvent event, bool failed})>[];
        while (batch.length < perRequest && _waiting.isNotEmpty) {
          batch.add(_waiting.removeFirst());
        }
        try {
          await send([for (final entry in batch) entry.event]);
        } catch (error) {
          debugPrint('The app events were not sent: $error');
          // Signed out meanwhile: those were the person's before.
          if (round != _round || _disposed) break;
          // Once more with the next send, in front of the newer ones; a
          // second failure drops them.
          for (final entry in batch.reversed) {
            if (!entry.failed) {
              _waiting.addFirst((event: entry.event, failed: true));
            }
          }
          _keepLimit();
          break;
        }
      }
    } finally {
      _sending = false;
      if (_waiting.isNotEmpty && !_disposed) _sendLater();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _waiting.clear();
  }

  /// Whether someone is signed in. When it is someone else than before,
  /// what waits goes.
  bool _signedIn() {
    final now = user();
    if (now != _owner) {
      _owner = now;
      _waiting.clear();
      _round++;
      _screen = null;
      _timer?.cancel();
      _timer = null;
    }
    return now != null && !_disposed;
  }

  void _add(AppEventKind kind, String name, [String? detail]) {
    final named = _cut(name, maxName);
    // The server takes no report without a name.
    if (named.isEmpty) return;
    final more = detail == null ? '' : _cut(detail, maxDetail);
    final event = AppEvent(
      at: _clock(),
      kind: kind,
      name: named,
      detail: more.isEmpty ? null : more,
    );
    _waiting.add((event: event, failed: false));
    _keepLimit();
    if (_waiting.length >= sendAt) {
      // Not right here: this may be a screen's build.
      scheduleMicrotask(() => unawaited(flush()));
    } else {
      _sendLater();
    }
  }

  void _sendLater() => _timer ??= Timer(sendAfter, () => unawaited(flush()));

  void _keepLimit() {
    while (_waiting.length > keep) {
      _waiting.removeFirst();
    }
  }

  /// Whether one more request fits in the minute; counts it when it does.
  bool _mayRequest() {
    final now = _clock();
    while (_requests.isNotEmpty &&
        now.difference(_requests.first) >= const Duration(minutes: 1)) {
      _requests.removeFirst();
    }
    if (_requests.length >= requestsPerMinute) return false;
    _requests.add(now);
    return true;
  }

  /// Whether [error] wasn't told yet. Strings and numbers can't be told
  /// apart from equal ones: they are no failed request and aren't told.
  bool _firstTime(Object error) {
    if (error is String || error is num || error is bool || error is Record) {
      return false;
    }
    if (_told[error] ?? false) return false;
    _told[error] = true;
    return true;
  }

  /// [text] without control characters (the server drops them anyway), at
  /// most [max] long.
  static String _cut(String text, int max) {
    final clean = text.replaceAll(_control, '');
    return clean.length <= max ? clean : clean.substring(0, max);
  }

  static final _control = RegExp(r'[\x00-\x1F\x7F-\x9F]');
}

/// An error's name for the visor: its kind (`network`, `forbidden`...), or
/// `unknown` for anything but a failed request.
String errorName(Object error) =>
    error is ApiException ? error.kind.name : ApiErrorKind.unknown.name;

/// An error's detail for the visor: the status, the problem type and the
/// server's trace id, e.g. `status=403 type=urn:collarbell:problem:role-
/// forbidden traceId=00-4bf9…`. Never the server's words or what the fields
/// held. For anything but a failed request, its type.
String? errorDetail(Object error) {
  if (error is! ApiException) return 'type=${error.runtimeType}';
  final parts = [
    if (error.statusCode case final status?) 'status=$status',
    if (error.problemType case final type?) 'type=$type',
    if (error.traceId case final traceId?) 'traceId=$traceId',
  ];
  return parts.isEmpty ? null : parts.join(' ');
}

/// The lines of the app a crash went through, innermost first, e.g.
/// `features/pets/pets_screen.dart:42 < app/home_shell.dart:117`: up to
/// five, without those of Flutter and the packages. The exception's message
/// stays out: it may hold the person's data.
String? appFrames(StackTrace? stack) {
  if (stack == null) return null;
  final frames = [
    for (final match in _appFrame.allMatches('$stack'))
      '${match[1]}:${match[2]}',
  ];
  return frames.isEmpty ? null : frames.take(5).join(' < ');
}

/// A frame of this app: `package:collarbell/<file>.dart:<line>:<column>`,
/// or `… <line>:<column>` in a short trace.
final _appFrame = RegExp(r'package:collarbell/([\w/.\-]+\.dart)[ :](\d+)');

/// The reporter of this run while the visor is on, for the code that has no
/// `ref`: the error messages ([reportShownError]) and the crash handlers
/// ([watchCrashes]).
AppEventReporter? _running;

/// Tells the visor that an error message for [error] is on the screen (see
/// `errorMessageFor`). It never fails the screen.
void reportShownError(Object error) {
  try {
    _running?.errorShown(error);
  } catch (failure) {
    debugPrint('The visor missed an error: $failure');
  }
}

/// Tells the visor of crashes while it runs: what Flutter caught (a widget
/// that failed to build) and what nobody caught. The handlers that were
/// there keep working: the console, and in tests the test framework, still
/// get every error. `main()` calls it.
void watchCrashes() {
  if (!identical(FlutterError.onError, _onFlutterError)) {
    final before = FlutterError.onError;
    _onFlutterError = (details) {
      // Silent ones are expected, e.g. a photo that didn't load.
      if (!details.silent) _tellCrash(details.exception, details.stack);
      before?.call(details);
    };
    FlutterError.onError = _onFlutterError;
  }
  final dispatcher = PlatformDispatcher.instance;
  if (!identical(dispatcher.onError, _onPlatformError)) {
    final before = dispatcher.onError;
    _onPlatformError = (error, stack) {
      _tellCrash(error, stack);
      return before?.call(error, stack) ?? false;
    };
    dispatcher.onError = _onPlatformError;
  }
}

FlutterExceptionHandler? _onFlutterError;
ErrorCallback? _onPlatformError;

void _tellCrash(Object error, StackTrace? stack) {
  try {
    _running?.crash(error, stack);
  } catch (failure) {
    debugPrint('The visor missed a crash: $failure');
  }
}

/// The `--dart-define` that turns the visor on in a debug build.
const appEventsKey = 'CB_APP_EVENTS';

/// Whether this build tells the server about itself: profile and release
/// builds do; debug builds, and so the tests, only when built with
/// `--dart-define=CB_APP_EVENTS=true`. The visor's own tests turn it on.
final appEventsOnProvider = Provider<bool>(
  (ref) => !kDebugMode || const bool.fromEnvironment(appEventsKey),
);

/// Sends one batch of reports (`POST /api/v1/events`) with this launch's id
/// and the app's version. Tests replace it.
final sendAppEventsProvider =
    Provider<Future<void> Function(List<AppEvent> events)>(
      (ref) =>
          (events) => ref
              .read(apiClientProvider)
              .send(
                (api) => api.events.reportAppEvents(
                  body: dto.AppEventsRequest(
                    session: appSession,
                    appVersion: appVersion,
                    events: [
                      for (final event in events)
                        dto.AppEventRequest(
                          // One number, whatever the phone's time zone.
                          atUnixMs: event.at.millisecondsSinceEpoch,
                          kind: switch (event.kind) {
                            AppEventKind.screen => dto.AppEventKind.screen,
                            AppEventKind.action => dto.AppEventKind.action,
                            AppEventKind.error => dto.AppEventKind.error,
                            AppEventKind.crash => dto.AppEventKind.crash,
                          },
                          name: event.name,
                          detail: event.detail,
                        ),
                    ],
                  ),
                ),
              ),
    );

/// The visor of this run of the app: an [AppEventReporter], or
/// [NoAppEvents] where it is off. The app starts it (`CollarbellApp`); the
/// router tells it the screens, the screens a few actions, and the error
/// messages and the crash handlers what went wrong.
final appEventsProvider = Provider<AppEvents>((ref) {
  if (!ref.watch(appEventsOnProvider)) return const NoAppEvents();
  final reporter = AppEventReporter(
    send: ref.watch(sendAppEventsProvider),
    user: () => ref.read(authUserProvider)?.uid,
  );
  // Signed out, or in as someone else: what waits goes at once.
  ref.listen(authUserProvider, (_, _) => reporter.userChanged());
  // Into the background: what waits goes now, the app may not come back.
  final lifecycle = AppLifecycleListener(
    onPause: () => unawaited(reporter.flush()),
  );
  _running = reporter;
  ref.onDispose(() {
    lifecycle.dispose();
    reporter.dispose();
    if (identical(_running, reporter)) _running = null;
  });
  return reporter;
});
