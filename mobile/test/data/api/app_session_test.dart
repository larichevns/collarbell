// Every request names the launch of the app (a random id, the same until
// the app is closed) and the app's version, for the server's request log
// that the admin's "визор" reads.
import 'dart:io';

import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/data/api/app_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_client_test.dart' show FakeAdapter, json, petJson;

void main() {
  test('every request names the launch and the version', () async {
    final adapter = FakeAdapter((_) async => json([petJson()], 200));
    ApiClient client() => ApiClient(
      baseUrl: 'http://api.test',
      authHeaders: () async => {'X-Dev-User': 'dev-1'},
      httpClientAdapter: adapter,
    );

    // Two clients, as after a change of the app's settings: one launch.
    await client().send((api) => api.pets.listPets());
    await client().send((api) => api.pets.listPets());

    expect(
      [for (final r in adapter.requests) r.headers[appSessionHeader]],
      [appSession, appSession],
    );
    expect(
      [for (final r in adapter.requests) r.headers[appVersionHeader]],
      ['0.1.0', '0.1.0'],
    );
    // A random id (UUID v4) of this launch: nothing about the person.
    expect(
      appSession,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test("the version is pubspec.yaml's, without the build number", () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^\s+]+)',
      multiLine: true,
    ).firstMatch(pubspec)?[1];

    expect(appVersion, version);
  });
}
