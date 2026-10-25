import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/ihub_protocol.dart' show MessageHeaders;
import 'package:signalr_netcore/iretry_policy.dart';
import 'package:signalr_netcore/signalr_client.dart';

import 'realtime_client.dart';

/// [RealtimeClient] over the signalr_netcore package: one SignalR
/// connection to the server's `HouseholdHub`.
///
/// WebSockets only and without the negotiate request, as the server takes
/// them. The headers go on the request that opens the socket: on iOS and
/// Android the package hands them to dart:io's `WebSocket.connect`, so the
/// sign-in token travels in a header, never in the address (addresses end
/// up in server logs).
class SignalRRealtimeClient implements RealtimeClient {
  /// What the hub calls with a change (the server's
  /// `IHouseholdClient.Changed`).
  static const changedMethod = 'Changed';

  /// What the app asks once the socket is open (the server's
  /// `HouseholdHub.Ready`).
  static const readyMethod = 'Ready';

  final _changes = StreamController<LiveChange>.broadcast();
  HubConnection? _hub;
  var _state = RealtimeState.disconnected;

  /// Why the connection closed, when the package said.
  Exception? _closeError;

  @override
  RealtimeState get state => _state;

  @override
  Stream<LiveChange> get changes => _changes.stream;

  @override
  Future<void> connect(Uri url, Map<String, String> headers) async {
    if (_hub != null || _changes.isClosed) {
      throw StateError('A RealtimeClient connects once.');
    }
    final opening = MessageHeaders();
    headers.forEach(opening.setHeaderValue);
    final hub = _hub = HubConnectionBuilder()
        .withUrl(
          '$url',
          options: HttpConnectionOptions(
            transport: HttpTransportType.WebSockets,
            skipNegotiation: true,
            headers: opening,
          ),
        )
        // Without a policy that says no, the package reconnects by itself
        // even when not asked to: four more tries over 42 seconds, with
        // these headers (the sign-in token in them expires), and nobody
        // hears that the connection dropped meanwhile. The app reconnects
        // itself, with fresh headers (LiveUpdates).
        .withAutomaticReconnect(reconnectPolicy: _NeverReconnect())
        .build();
    hub.on(changedMethod, _onChanged);
    hub.onclose(({error}) => _onClose(error));
    _state = RealtimeState.connecting;
    try {
      await hub.start();
      // The server checks the household once the socket is open: Ready
      // answers when this connection hears it. A refusal closes the
      // connection instead, which fails the call.
      await hub.invoke(readyMethod);
    } catch (error) {
      _finish();
      unawaited(_stop(hub));
      final refusal = refusalIn(_closeError) ?? refusalIn(error);
      if (refusal != null) throw refusal;
      rethrow;
    }
    // Closed meanwhile, by close() or the server.
    if (_state != RealtimeState.connecting) {
      throw StateError('The connection closed while it opened.');
    }
    _state = RealtimeState.connected;
  }

  @override
  Future<void> close() async {
    final hub = _hub;
    _finish();
    if (hub != null) await _stop(hub);
  }

  void _onChanged(List<Object?>? arguments) {
    // Also before Ready answers: the connection hears the household from
    // the moment the server adds it. A handler that throws makes the
    // package close the connection, so nothing here throws: what can't be
    // read still counts as a change.
    if (!_changes.isClosed) _changes.add(liveChangeFrom(arguments));
  }

  void _onClose(Exception? error) {
    _closeError = error;
    if (_state == RealtimeState.connected) {
      debugPrint(
        'Live updates: the connection closed (${error ?? 'no reason'})',
      );
    }
    _finish();
  }

  void _finish() {
    _state = RealtimeState.disconnected;
    if (!_changes.isClosed) unawaited(_changes.close());
  }

  static Future<void> _stop(HubConnection hub) async {
    try {
      await hub.stop();
    } catch (error) {
      debugPrint('Live updates: closing the connection failed: $error');
    }
  }
}

/// Tells signalr_netcore not to reconnect by itself.
class _NeverReconnect implements IRetryPolicy {
  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) => null;
}

/// Why the server closes a connection for good (its `HouseholdHub.NotAMember`
/// and `LiveChanges.TooManyConnections`). It also asks the app not to
/// reconnect, which the package doesn't pass on, so the words tell.
const refusalReasons = [
  "You aren't in this household.",
  'Too many open connections.',
];

/// The refusal [error] tells of, if any: the package reports the server's
/// close message as an error with its words ("Server returned an error on
/// close: Connection closed with an error. HubException: …").
@visibleForTesting
RealtimeRefused? refusalIn(Object? error) {
  if (error == null) return null;
  final text = '$error';
  for (final reason in refusalReasons) {
    if (text.contains(reason)) return RealtimeRefused(reason);
  }
  return null;
}

/// The change in the hub's `Changed` call: one argument,
/// `{"topics": [...], "origin": "..."}`. What can't be read becomes a change
/// without topics, after which the app reads everything again.
@visibleForTesting
LiveChange liveChangeFrom(List<Object?>? arguments) {
  final change = arguments == null || arguments.isEmpty
      ? null
      : arguments.first;
  if (change is! Map) return const LiveChange([]);
  final topics = change['topics'];
  final origin = change['origin'];
  return LiveChange([
    if (topics is List)
      for (final topic in topics)
        if (topic is String) topic,
  ], origin: origin is String ? origin : null);
}
