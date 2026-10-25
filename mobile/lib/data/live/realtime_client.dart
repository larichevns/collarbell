import 'package:flutter/foundation.dart';

/// The kinds of things a household's screens show, as live updates name
/// them (the server's `LiveTopics`). The app knows which of its screens show
/// each one (`app/live_updates.dart`); a topic it doesn't know means
/// anything may have changed.
abstract final class LiveTopics {
  /// The pets: added, changed, paused, deleted, their photos.
  static const pets = 'pets';

  /// The fields of a pet's digital passport.
  static const passport = 'passport';

  /// Care plans and records: vaccinations, treatments, check-ups (and the
  /// weight a vet noted at one).
  static const care = 'care';

  /// A pet's weighings. The weights of care records come as [care].
  static const weight = 'weight';

  /// Feeding schedules and their marks.
  static const feeding = 'feeding';

  /// Vet visits.
  static const visits = 'visits';

  /// Supplies and their stock.
  static const supplies = 'supplies';

  /// A pet's documents.
  static const documents = 'documents';

  /// AI scans of a passport: being read, ready to check, saved or thrown
  /// away.
  static const imports = 'imports';

  /// The household itself: its name and time zone, its people and their
  /// roles, the invites.
  static const household = 'household';

  /// The household's plan: Free or Premium.
  static const plan = 'plan';
}

/// Something changed in the household (the server's `LiveChange`). It
/// carries no data: the screens that show it read it again.
@immutable
class LiveChange {
  const LiveChange(this.topics, {this.origin});

  /// What changed ([LiveTopics]). Empty when the message couldn't be read:
  /// then anything may have changed.
  final List<String> topics;

  /// The `X-Client` of the request that made the change: this app's own id
  /// (`liveClientId`) when it made it, and then it shows the change already.
  /// Null when the server changed something by itself.
  final String? origin;

  @override
  String toString() => 'LiveChange($topics, $origin)';
}

/// Where a [RealtimeClient]'s connection stands.
enum RealtimeState {
  /// Not open: not yet, or closed (by [RealtimeClient.close], the network
  /// or the server). A client doesn't open again.
  disconnected,

  /// Opening, until the server hears the household for it.
  connecting,

  /// Open: the server tells it what changes in the household.
  connected,
}

/// The server refused the connection and asks not to try again soon: the
/// household it names isn't the user's (they left, or were removed), or the
/// person has too many connections open. The app tries again only when
/// another household is on screen or the app comes back to the front.
class RealtimeRefused implements Exception {
  const RealtimeRefused(this.reason);

  /// The server's words, e.g. "You aren't in this household.".
  final String reason;

  @override
  String toString() => 'RealtimeRefused($reason)';
}

/// One live connection to the changes of a household (system-design 3.4).
///
/// The rest of the app knows only this interface. `SignalRRealtimeClient`
/// is the one over the signalr_netcore package; if the package fails us,
/// another (a fork of it, Server-Sent Events) takes its place without
/// touching the screens.
///
/// A client opens one connection. The app makes a new client for every
/// connection, with the headers of that moment: a Firebase sign-in token
/// lasts an hour.
abstract interface class RealtimeClient {
  /// Opens the connection to [url], with [headers] on the request that
  /// opens it, and completes once the server hears the household they name:
  /// what changes after that comes on [changes]. Throws [RealtimeRefused]
  /// when the server refused the connection, any other error when it failed
  /// (no network, the server away, a sign-in it didn't take).
  Future<void> connect(Uri url, Map<String, String> headers);

  /// What the server says changed, while the connection is open. Ends when
  /// the connection closes: by [close], or because the network or the
  /// server dropped it.
  Stream<LiveChange> get changes;

  /// Where the connection stands now.
  RealtimeState get state;

  /// Closes the connection, also one still opening. Nothing more comes on
  /// [changes].
  Future<void> close();
}

/// Makes a [RealtimeClient] for each connection.
typedef RealtimeClientFactory = RealtimeClient Function();
