// The account's endpoints as the server answers them: what deleting would do
// (each group's fate; one this app doesn't know is told as the gravest),
// DELETE /me, and the export downloaded into a file piece by piece, named as
// the server says; its 429, a deleted account and a lost connection.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/account/account.dart';
import 'package:collarbell/features/account/account_labels.dart';
import 'package:collarbell/features/account/account_repository.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/l10n/app_localizations_en.dart';
import 'package:collarbell/l10n/app_localizations_ru.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/api/api_client_test.dart' show FakeAdapter, json, problem;

const accountDeleted = {
  'type': ProblemTypes.accountDeleted,
  'title': 'This account has been deleted.',
  'status': 401,
};

void main() {
  late List<String> heard;
  late Directory folder;

  ApiClient client(FakeAdapter adapter) => ApiClient(
    baseUrl: 'http://api.test',
    authHeaders: () async => {'X-Dev-User': 'dev-1'},
    user: () => 'dev-1',
    onAccountDeleted: heard.add,
    httpClientAdapter: adapter,
  );

  setUp(() async {
    heard = [];
    folder = await Directory.systemTemp.createTemp('collarbell_export_test');
  });
  tearDown(() => folder.delete(recursive: true));

  /// A ZIP as the server streams it: no length, a suggested name.
  ResponseBody zip(Stream<Uint8List> pieces) => ResponseBody(
    pieces,
    200,
    headers: {
      Headers.contentTypeHeader: ['application/zip'],
      'content-disposition': [
        'attachment; filename=collarbell-export-2026-10-05.zip; '
            "filename*=UTF-8''collarbell-export-2026-10-05.zip",
      ],
    },
  );

  Future<Object?> failure(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      return error;
    }
    return null;
  }

  test('what deleting would do: each group, its fate, the new owner, and '
      'the plan of it', () async {
    final adapter = FakeAdapter(
      (_) async => json({
        'households': [
          {
            'id': 'h1',
            'name': 'Home',
            'role': 'Owner',
            'fate': 'Deleted',
            'pets': 2,
            'others': 1,
            'newOwner': null,
          },
          {
            'id': 'h2',
            'name': 'Office',
            'role': 'Member',
            'fate': 'Kept',
            'pets': 1,
            'others': 3,
            'newOwner': null,
          },
          {
            'id': 'h3',
            'name': 'Dacha',
            'role': 'Owner',
            'fate': 'HandedOver',
            'pets': 0,
            'others': 2,
            'newOwner': 'Boris',
          },
          // A newer server's fate.
          {
            'id': 'h4',
            'name': 'Shelter',
            'role': 'Helper',
            'fate': 'Archived',
            'pets': 0,
            'others': 1,
            'newOwner': null,
          },
        ],
        'plan': 'a1b2c3',
      }, 200),
    );

    final preview = await ApiAccountRepository(
      client(adapter),
    ).getDeletionPreview();
    final groups = preview.households;

    expect(adapter.requests.single.uri.path, '/api/v1/me/deletion');
    expect(preview.plan, 'a1b2c3');
    expect(
      [for (final group in groups) group.fate],
      [
        HouseholdFate.deleted,
        HouseholdFate.kept,
        HouseholdFate.handedOver,
        // Better to warn of a deletion that won't happen than to miss one.
        HouseholdFate.deleted,
      ],
    );
    expect(groups.first.role, HouseholdRole.owner);
    expect(groups.first.pets, 2);
    expect(groups.first.others, 1);
    expect(groups[1].role, HouseholdRole.member);
    expect(groups[2].newOwner, 'Boris');
  });

  test('deleting is DELETE /me with the plan shown; "type the password '
      'again" and "the groups changed" are told apart', () async {
    final adapter = FakeAdapter((_) async => ResponseBody.fromString('', 204));
    await ApiAccountRepository(client(adapter)).deleteAccount('a1b2c3');
    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.uri.path, '/api/v1/me');
    expect(request.uri.queryParameters, {'plan': 'a1b2c3'});

    Future<Object?> refused(Map<String, Object?> problemBody) => failure(
      () => ApiAccountRepository(
        client(
          FakeAdapter(
            (_) async => problem(problemBody['status']! as int, problemBody),
          ),
        ),
      ).deleteAccount('a1b2c3'),
    );
    final again = await refused({
      'type': ProblemTypes.recentSignInRequired,
      'title': 'Type your password again to delete the account.',
      'status': 403,
    });
    expect(isRecentSignInRequired(again!), isTrue);
    expect(isDeletionPlanChanged(again), isFalse);

    final changed = await refused({
      'type': ProblemTypes.deletionPlanChanged,
      'title': 'Your households changed: look again at what happens to them.',
      'status': 409,
    });
    expect(isDeletionPlanChanged(changed!), isTrue);
    expect(
      deleteAccountErrorMessage(changed, AppLocalizationsEn()),
      'Something changed in your groups. Check again what happens to them, '
      'then delete.',
    );
    expect(
      deleteAccountErrorMessage(changed, AppLocalizationsRu()),
      'В ваших группах что-то изменилось. Посмотрите ещё раз, что с ними '
      'будет, и удалите снова.',
    );
    expect(heard, isEmpty);
  });

  test('the export comes into a file piece by piece, named as the server '
      'says', () async {
    final adapter = FakeAdapter(
      (_) async => zip(
        Stream.fromIterable([
          Uint8List.fromList([80, 75, 3]),
          Uint8List.fromList([4, 5, 6]),
        ]),
      ),
    );
    final received = <int>[];

    final file = await ApiAccountRepository(
      client(adapter),
    ).downloadExport(folder, onReceived: received.add);

    final request = adapter.requests.single;
    expect(request.uri.path, '/api/v1/me/export');
    expect(request.headers['X-Dev-User'], 'dev-1');
    expect(file.name, 'collarbell-export-2026-10-05.zip');
    expect(file.path, '${folder.path}/collarbell-export-2026-10-05.zip');
    expect(file.bytes, 6);
    expect(File(file.path).readAsBytesSync(), [80, 75, 3, 4, 5, 6]);
    expect(received, [3, 6]);
  });

  test('too many this hour: 429 with how long to wait, and no file', () async {
    final adapter = FakeAdapter(
      (_) async => ResponseBody.fromString(
        '',
        429,
        headers: {
          'retry-after': ['690'],
        },
      ),
    );

    final error = await failure(
      () => ApiAccountRepository(client(adapter)).downloadExport(folder),
    );

    final refused = error! as ApiException;
    expect(refused.kind, ApiErrorKind.tooManyRequests);
    expect(refused.retryAfter, const Duration(seconds: 690));
    expect(folder.listSync(), isEmpty);
  });

  test('the account is gone: a download hears it too, once', () async {
    final adapter = FakeAdapter((_) async => problem(401, accountDeleted));

    final error = await failure(
      () => ApiAccountRepository(client(adapter)).downloadExport(folder),
    );

    expect((error! as ApiException).problemType, ProblemTypes.accountDeleted);
    expect(heard, ['dev-1']);
    expect(folder.listSync(), isEmpty);
  });

  test(
    'a connection lost halfway is no connection, and what came goes',
    () async {
      final pieces = StreamController<Uint8List>();
      final adapter = FakeAdapter((_) async => zip(pieces.stream));

      final download = failure(
        () => ApiAccountRepository(client(adapter)).downloadExport(folder),
      );
      pieces.add(Uint8List.fromList([80, 75, 3]));
      await Future<void>.delayed(Duration.zero);
      pieces.addError(const SocketException('Connection reset by peer'));
      final error = await download;
      await pieces.close();

      expect((error! as ApiException).kind, ApiErrorKind.network);
      expect(folder.listSync(), isEmpty);
    },
  );

  test("the file name: the server's when it is a plain one, else today's", () {
    final today = DateTime(2026, 10, 6);

    expect(
      exportFileName(
        "attachment; filename*=UTF-8''collarbell-export-2026-10-05.zip",
        today,
      ),
      'collarbell-export-2026-10-05.zip',
    );
    expect(
      exportFileName(
        'attachment; filename="collarbell-export-2026-10-05.zip"',
        today,
      ),
      'collarbell-export-2026-10-05.zip',
    );
    expect(exportFileName(null, today), 'collarbell-export-2026-10-06.zip');
    // Nothing that leads out of the folder, nothing but a ZIP.
    for (final odd in [
      'attachment; filename="../../secrets.zip"',
      "attachment; filename*=UTF-8''%2E%2E%2Fsecrets.zip",
      'attachment; filename=notes.txt',
    ]) {
      expect(exportFileName(odd, today), 'collarbell-export-2026-10-06.zip');
    }
  });
}
