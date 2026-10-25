import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exception.dart';
import 'household_header.dart';

/// Whether the server answered the last request, as the app saw it.
@immutable
class ServerReachability {
  const ServerReachability.reachable() : reachable = true, dataAt = null;

  const ServerReachability.unreachable({this.dataAt}) : reachable = false;

  final bool reachable;

  /// When the copy now on screen was received from the server; null when no
  /// copy was used.
  final DateTime? dataAt;

  @override
  bool operator ==(Object other) =>
      other is ServerReachability &&
      other.reachable == reachable &&
      other.dataAt == dataAt;

  @override
  int get hashCode => Object.hash(reachable, dataAt);
}

/// One kept answer: the decoded JSON body and when it came.
@immutable
class CachedAnswer {
  const CachedAnswer(this.body, this.at);

  final Object? body;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'body': body,
  };

  static CachedAnswer? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['at']}');
    return at == null ? null : CachedAnswer(json['body'], at.toLocal());
  }
}

/// Where the kept answers live.
abstract interface class OfflineCacheStore {
  Future<CachedAnswer?> read(String key);

  Future<void> write(String key, CachedAnswer answer);

  /// Forgets everything: on sign-out, so the next account on this phone
  /// never sees the last one's data.
  Future<void> clear();

  /// Forgets the answers whose key passes [test], e.g. those of a household
  /// the user left.
  Future<void> clearWhere(bool Function(String key) test);
}

/// Keeps the answers in memory only: for tests.
class MemoryOfflineCacheStore implements OfflineCacheStore {
  final entries = <String, CachedAnswer>{};

  @override
  Future<CachedAnswer?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, CachedAnswer answer) async =>
      entries[key] = answer;

  @override
  Future<void> clear() async => entries.clear();

  @override
  Future<void> clearWhere(bool Function(String key) test) async =>
      entries.removeWhere((key, _) => test(key));
}

/// One JSON file per answer in a folder of the app's own storage (Android
/// leaves it out of backups: `android:allowBackup="false"`). The file keeps
/// its key too, so the answers of one household can be found and dropped.
class FileOfflineCacheStore implements OfflineCacheStore {
  FileOfflineCacheStore(this._folder);

  final Future<Directory> Function() _folder;
  var _drafts = 0;
  Future<Directory>? _ready;

  /// Marks a folder whose copies have the household in their key.
  static const _markerName = '.per-household';

  /// The folder, once without the copies kept before the key had the
  /// household in it: they would never be read again, so they only took
  /// space (until the next sign-out).
  Future<Directory> _cleanFolder() => _ready ??= () async {
    final folder = await _folder();
    final marker = File('${folder.path}/$_markerName');
    if (!await marker.exists()) {
      if (await folder.exists()) await folder.delete(recursive: true);
      await folder.create(recursive: true);
      await marker.writeAsString('');
    }
    return folder;
  }();

  Future<File> _file(String key) async =>
      File('${(await _cleanFolder()).path}/${_hash(key)}.json');

  @override
  Future<CachedAnswer?> read(String key) async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    return CachedAnswer.fromJson(jsonDecode(await file.readAsString()));
  }

  @override
  Future<void> write(String key, CachedAnswer answer) async {
    final file = await _file(key);
    await file.parent.create(recursive: true);
    // Written aside, then renamed over the copy: one cut off midway (the
    // app killed) never replaces a whole one. Every write has its own draft,
    // so two answers to the same request can't mix; the last rename wins.
    final draft = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.${_drafts++}.tmp',
    );
    await draft.writeAsString(
      jsonEncode({...answer.toJson(), 'key': key}),
      flush: true,
    );
    await draft.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final folder = await _folder();
    _ready = null;
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  @override
  Future<void> clearWhere(bool Function(String key) test) async {
    final folder = await _cleanFolder();
    await for (final entry in folder.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(await entry.readAsString());
        final key = json is Map ? json['key'] : null;
        if (key is String && test(key)) await entry.delete();
      } on Object catch (error) {
        debugPrint('Offline copy not checked: $error');
      }
    }
  }

  /// FNV-1a, 64 bit: a short file name for a long key.
  static String _hash(String key) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(key)) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16);
  }
}

/// The read-only cache of spec 3: keeps the last answer of each GET the
/// screens read from, and gives it back when the server can't be reached
/// (the Mac asleep, the phone away from home). A live answer always wins:
/// the copy is used only after a network error or timeout, and
/// [onReachability] tells the app it is showing one.
///
/// Changes are never made on top of copies: while the server doesn't answer,
/// a change isn't sent (it could mark yesterday's feeding from yesterday's
/// Today). It asks [probe] whether the server is back first; if so, the app
/// reloads every screen and the user does it again on live data.
class OfflineCacheInterceptor extends Interceptor {
  OfflineCacheInterceptor({
    required this.store,
    required this.userKey,
    required this.onReachability,
    required this.isReachable,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final OfflineCacheStore store;

  /// The signed-in user, or null: copies are kept per user, and per
  /// household (the one the request names, see [keyFor]).
  final String? Function() userKey;
  final void Function(ServerReachability status) onReachability;

  /// What the app last saw: false while screens may show copies.
  final bool Function() isReachable;

  /// Whether the server answers now; set by the API client.
  Future<bool> Function()? probe;

  final DateTime Function() _clock;

  /// When the last change went through.
  DateTime? _lastChange;

  /// Right after a change the screens reload to show it. Older copies would
  /// hide it, as if it never happened, and invite doing it again; for this
  /// long the screens show their error instead.
  static const changeShowsFor = Duration(minutes: 1);

  /// Not kept: AI scans and files change on their own and are useless
  /// offline, product lookups go to outside databases, notification
  /// settings only matter with a connection, the data export is a file, and
  /// what deleting the account would do must be the server's answer now.
  static const _notKept = [
    '/api/v1/ai/',
    '/api/v1/ai-imports/',
    '/api/v1/files/',
    '/api/v1/products/',
    '/api/v1/notifications/',
    '/api/v1/me/export/',
    '/api/v1/me/deletion/',
  ];

  static const _keyExtra = 'offlineCopyKey';

  static bool _isRead(RequestOptions options) =>
      options.method.toUpperCase() == 'GET';

  /// The app's reports about itself (`POST /api/v1/events`, see
  /// app_events.dart) pass by unseen: they go in the background and change
  /// nothing on the screens, so they are no change to hold back, and
  /// whether they get through is nothing to show.
  static bool _passesBy(RequestOptions options) =>
      options.uri.path.endsWith('/api/v1/events');

  /// How the keys of [user]'s answers about [household] start.
  static String householdKeyPrefix(String user, String household) =>
      '$user $household ';

  /// The key of [options]' answer, or null when it isn't kept.
  String? keyFor(RequestOptions options) {
    if (!_isRead(options)) return null;
    final user = userKey();
    if (user == null) return null;
    // One household's copies never show in another. A request that names
    // none (the app doesn't know its household yet) keeps none: which
    // household the server picks for it can change.
    final household = options.headers[householdHeader];
    if (household is! String) return null;
    final uri = options.uri;
    final path = uri.path;
    if (!path.startsWith('/api/v1/')) return null;
    if (_notKept.any((prefix) => '$path/'.startsWith(prefix))) return null;
    // A pet's AI scans, too.
    if (path.contains('/ai-imports')) return null;
    // Today's date moves on, and yesterday's Today is still the best copy
    // there is: the banner says how old it is.
    final query = path == '/api/v1/today' ? '' : uri.query;
    return '${householdKeyPrefix(user, household)}$path?$query';
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isRead(options)) {
      // Taken now: the answer belongs to whoever asked, even if the user
      // signs out before it comes.
      options.extra[_keyExtra] = keyFor(options);
      handler.next(options);
      return;
    }
    if (isReachable() || _passesBy(options)) {
      handler.next(options);
      return;
    }
    final back = await (probe?.call() ?? Future.value(false));
    handler.reject(
      DioException(
        requestOptions: options,
        error: back ? const ScreensRefreshed() : const ChangeWhileOffline(),
        message: back
            ? 'Not sent: the server is back, the screens reload first'
            : 'Not sent: no answer from the server, screens may show copies',
      ),
      true,
    );
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_passesBy(response.requestOptions)) {
      handler.next(response);
      return;
    }
    onReachability(const ServerReachability.reachable());
    final options = response.requestOptions;
    if (!_isRead(options)) _lastChange = _clock();
    final key = options.extra[_keyExtra] as String?;
    // The user signed out or in meanwhile: not theirs to keep.
    final sameUser = key != null && key.startsWith('${userKey()} ');
    if (sameUser && response.statusCode == 200) {
      unawaited(
        store
            .write(key, CachedAnswer(response.data, _clock()))
            .catchError(
              (Object error) => debugPrint('Offline copy not kept: $error'),
            ),
      );
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // This interceptor's own refusal of a change: already reported. The
    // app's reports pass by.
    if (err.error is ChangeWhileOffline ||
        err.error is ScreensRefreshed ||
        _passesBy(err.requestOptions)) {
      handler.next(err);
      return;
    }
    if (!isUnreachable(err)) {
      // An error status is an answer: the server is there.
      if (err.response != null) {
        onReachability(const ServerReachability.reachable());
      }
      handler.next(err);
      return;
    }
    final key = err.requestOptions.extra[_keyExtra] as String?;
    CachedAnswer? copy;
    if (key != null) {
      try {
        copy = await store.read(key);
      } catch (error) {
        debugPrint('Offline copy unreadable: $error');
      }
    }
    final lastChange = _lastChange;
    if (copy != null &&
        lastChange != null &&
        copy.at.isBefore(lastChange) &&
        _clock().difference(lastChange) < changeShowsFor) {
      copy = null;
    }
    if (copy == null) {
      onReachability(const ServerReachability.unreachable());
      handler.next(err);
      return;
    }
    onReachability(ServerReachability.unreachable(dataAt: copy.at));
    handler.resolve(
      Response<dynamic>(
        requestOptions: err.requestOptions,
        data: copy.body,
        statusCode: 200,
        extra: {cachedAtKey: copy.at},
      ),
    );
  }

  /// Marks an answer that came from the copy: `response.extra[cachedAtKey]`
  /// is when the server sent it.
  static const cachedAtKey = 'offlineCopyAt';

  /// No answer from the server at all: no connection, or none in time. A
  /// sign-in that couldn't be renewed for lack of internet counts too.
  static bool isUnreachable(DioException error) =>
      error.error is NetworkUnavailable ||
      switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.connectionError ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => true,
        _ => false,
      };
}
