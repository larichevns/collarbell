// The signalr_netcore side of live updates
// (data/live/signalr_realtime_client.dart): how a change from the hub is
// read, how the server's refusals are told from other failures (also one
// that comes after Ready, as the server sends it), and how the connection
// is made: straight to the hub, signed in by a header, never by the
// address. The last tests talk to a fake hub on the loopback address:
// nothing leaves the computer.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collarbell/app/live_updates.dart';
import 'package:collarbell/data/live/realtime_client.dart';
import 'package:collarbell/data/live/signalr_realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_netcore/errors.dart';

void main() {
  test("a change is read from the hub's one argument", () {
    // Only the phone that made the change gets its id back.
    final change = liveChangeFrom([
      {
        'topics': ['feeding', 'care'],
        'origin': 'this-phone',
      },
    ]);

    expect(change.topics, ['feeding', 'care']);
    expect(change.origin, 'this-phone');
    // Made on another phone, or by the server itself.
    expect(
      liveChangeFrom([
        {
          'topics': ['plan'],
          'origin': null,
        },
      ]).origin,
      isNull,
    );
  });

  test("what can't be read is a change without topics: then everything is "
      'read again', () {
    for (final arguments in <List<Object?>?>[
      null,
      [],
      ['pets'],
      [
        {'topics': 'pets'},
      ],
      [
        {'origin': 'anna-phone'},
      ],
    ]) {
      expect(liveChangeFrom(arguments).topics, isEmpty, reason: '$arguments');
    }
    expect(
      liveChangeFrom([
        {
          'topics': ['pets', 3, null],
        },
      ]).topics,
      ['pets'],
    );
  });

  test("the server's two refusals are told by their words; other failures "
      'are no refusal', () {
    RealtimeRefused? closedWith(String reason) => refusalIn(
      GeneralError(
        'Server returned an error on close: Connection closed with an '
        'error. HubException: $reason',
      ),
    );

    expect(
      closedWith("You aren't in this household.")?.reason,
      "You aren't in this household.",
    );
    expect(
      closedWith('Too many open connections.')?.reason,
      'Too many open connections.',
    );
    // Not created yet: it will be, so trying again makes sense.
    expect(closedWith('Unknown user: sign in to the app first.'), isNull);
    expect(
      refusalIn(
        Exception(
          "WebSocketException: Connection to 'http://localhost:5080/hubs/"
          "household#' was not upgraded to websocket",
        ),
      ),
      isNull,
    );
    expect(refusalIn(null), isNull);
  });

  group('against a hub on this computer', () {
    late _FakeHub hub;

    setUp(() async => hub = await _FakeHub.start());
    tearDown(() => hub.close());

    test('the socket opens straight to the hub, signed in by a header and '
        'never by the address; changes come through; a drop ends the '
        'client, and the package does not reconnect by itself', () async {
      final client = SignalRRealtimeClient();
      final heard = <LiveChange>[];
      final done = Completer<void>();
      client.changes.listen(heard.add, onDone: done.complete);

      await client.connect(hub.url, {
        'Authorization': 'Bearer token-1',
        'X-Household': 'h1',
        'X-Client': 'this-phone',
      });

      expect(client.state, RealtimeState.connected);
      final opening = hub.openings.single;
      expect(opening.uri.path, '/hubs/household');
      expect(opening.uri.query, isEmpty);
      expect(opening.headers['authorization'], 'Bearer token-1');
      expect(opening.headers['x-household'], 'h1');
      expect(opening.headers['x-client'], 'this-phone');
      expect(hub.readyAsked, 1);

      hub.change({
        'topics': ['feeding'],
        'origin': null,
      });
      await _until(() => heard.isNotEmpty);
      expect(heard.single.topics, ['feeding']);
      expect(heard.single.origin, isNull);

      await hub.drop();
      await done.future.timeout(const Duration(seconds: 5));
      expect(client.state, RealtimeState.disconnected);
      // By default the package would open again at once, with these headers.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(hub.openings, hasLength(1));
    });

    test("the hub's refusal after Ready, as the server sends it, is a "
        'RealtimeRefused', () async {
      hub.refuseOnReady = "You aren't in this household.";
      final client = SignalRRealtimeClient();

      await expectLater(
        client.connect(hub.url, const {'X-Household': 'h2'}),
        throwsA(
          isA<RealtimeRefused>().having(
            (refusal) => refusal.reason,
            'reason',
            "You aren't in this household.",
          ),
        ),
      );
      // The socket opened and the client asked Ready before it was refused.
      expect(hub.readyAsked, 1);
      expect(client.state, RealtimeState.disconnected);
      // A client opens once: the next connection is a new client.
      await expectLater(client.connect(hub.url, const {}), throwsStateError);
    });

    test('a refusal right after the handshake, before Ready went out, is a '
        'RealtimeRefused too', () async {
      hub.refuseAfterHandshake = 'Too many open connections.';
      final client = SignalRRealtimeClient();

      await expectLater(
        client.connect(hub.url, const {'X-Household': 'h1'}),
        throwsA(
          isA<RealtimeRefused>().having(
            (refusal) => refusal.reason,
            'reason',
            'Too many open connections.',
          ),
        ),
      );
      expect(client.state, RealtimeState.disconnected);
    });

    test('refused after Ready over a real connection, live updates stop and '
        'do not try again', () async {
      hub.refuseOnReady = "You aren't in this household.";
      final live = LiveUpdates(
        newClient: SignalRRealtimeClient.new,
        url: hub.url,
        authHeaders: () async => {'Authorization': 'Bearer token-1'},
        onChanged: (_) {},
        onReconnected: ({required backInApp}) {},
        pollToday: () {},
        clientId: 'this-phone',
      )..update(user: 'u1', household: 'h1', inFront: true);

      await _until(() => live.status == LiveStatus.refused);
      // A failure would be tried again after a second.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(live.status, LiveStatus.refused);
      expect(hub.openings, hasLength(1));
      expect(hub.readyAsked, 1);
      live.dispose();
    });

    test('close() closes the socket', () async {
      final client = SignalRRealtimeClient();
      await client.connect(hub.url, const {});

      await client.close();

      expect(client.state, RealtimeState.disconnected);
      await _until(() => hub.closed == 1);
    });
  });
}

/// Waits until [condition] holds, for up to 5 seconds.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 500 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

/// A SignalR hub on the loopback address, speaking just enough of the JSON
/// protocol (records end with 0x1E): the handshake, Ready, Changed and the
/// close message of a refusal.
class _FakeHub {
  _FakeHub._(this._server) {
    _server.listen(_open);
  }

  static Future<_FakeHub> start() async =>
      _FakeHub._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;
  final _sockets = <WebSocket>[];

  /// The requests that opened a socket: their address and headers.
  final openings = <({Uri uri, Map<String, String> headers})>[];
  var readyAsked = 0;

  /// The sockets that closed, from either side.
  var closed = 0;

  /// When set, the hub answers Ready by closing the connection with these
  /// words, as the server does when the household isn't the user's: it
  /// checks the household once the socket is open, and Ready waits for that.
  String? refuseOnReady;

  /// When set, the hub closes the connection with these words right after
  /// the handshake, before the client could ask Ready.
  String? refuseAfterHandshake;

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/hubs/household');

  Future<void> _open(HttpRequest request) async {
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));
    openings.add((uri: request.uri, headers: headers));
    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    socket.listen((data) {
      for (final record in '$data'.split('\x1e')) {
        if (record.isEmpty) continue;
        final message = jsonDecode(record) as Map<String, Object?>;
        if (message.containsKey('protocol')) {
          socket.add('{}\x1e');
          if (refuseAfterHandshake case final reason?) _refuse(socket, reason);
        } else if (message['type'] == 1 && message['target'] == 'Ready') {
          readyAsked++;
          if (refuseOnReady case final reason?) {
            _refuse(socket, reason);
          } else {
            _send(socket, {'type': 3, 'invocationId': message['invocationId']});
          }
        }
      }
    }, onDone: () => closed++);
  }

  static void _send(WebSocket socket, Map<String, Object?> message) =>
      socket.add('${jsonEncode(message)}\x1e');

  /// The close message of a refusal, as ASP.NET Core SignalR words it when
  /// OnConnectedAsync throws a HubException, then the socket closes.
  static void _refuse(WebSocket socket, String reason) {
    _send(socket, {
      'type': 7,
      'error': 'Connection closed with an error. HubException: $reason',
      'allowReconnect': false,
    });
    unawaited(socket.close());
  }

  /// Tells every open connection that something changed.
  void change(Map<String, Object?> change) {
    for (final socket in _sockets) {
      _send(socket, {
        'type': 1,
        'target': 'Changed',
        'arguments': [change],
      });
    }
  }

  /// The server goes away: every socket closes.
  Future<void> drop() async {
    for (final socket in _sockets) {
      await socket.close();
    }
  }

  Future<void> close() async {
    await drop();
    await _server.close(force: true);
  }
}
