// The AI repository against a fake HTTP layer: what a scan's draft becomes
// in the app (calendar dates, doubts, values a newer server may send), and
// what starting and saving a scan send (dates as dates, the request id).
import 'dart:convert';
import 'dart:typed_data';

import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/ai_repository.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [respond] and records the requests.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(Object? body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
  },
);

Map<String, Object?> fileJson(String id) => {
  'id': id,
  'contentType': 'image/jpeg',
  'sizeBytes': 1000,
  'width': 800,
  'height': 1000,
  'url': 'https://files.test/$id',
  'thumbnailUrl': 'https://files.test/$id-thumb',
  'expiresAt': '2026-10-02T10:00:00+00:00',
};

Map<String, Object?> scanJson({
  String status = 'Ready',
  String? error,
  Map<String, Object?>? draft,
  Map<String, Object?>? result,
}) => {
  'id': 'scan-1',
  'petId': 'p1',
  'source': 'PassportPages',
  'status': status,
  'pages': [fileJson('page-1'), fileJson('page-2')],
  'draft': draft,
  'error': error,
  'model': 'gemini-3.8-flash',
  'createdAt': '2026-10-02T09:30:00.123+00:00',
  'completedAt': '2026-10-02T09:30:41+00:00',
  'appliedAt': null,
  'result': result,
};

/// A draft as the server sends it, with values this app doesn't know: a
/// new vaccine target, a new kind of doubt, a new kind of care and a new
/// type of identifier.
Map<String, Object?> draftJson() => {
  'records': [
    {
      'key': 0,
      'kind': 'Vaccination',
      'title': 'Rabies vaccination',
      'performedOn': '2025-03-12',
      'performedTime': null,
      'product': 'Nobivac Rabies',
      'manufacturer': 'MSD',
      'batchNumber': 'A123B45',
      'validFrom': null,
      'validUntil': '2028-03-11',
      'targets': ['Rabies', 'Hantavirus'],
      'veterinarian': 'Dr. Weber',
      'clinic': null,
      'evidence': 'Nobivac Rabies 12/03/2025',
      'page': 1,
      'warnings': [
        {'field': 'performedOn', 'issue': 'Ambiguous'},
        {'field': 'batchNumber', 'issue': 'Smudged'},
      ],
      'duplicateOf': null,
      'planId': 'plan-rabies',
      'selected': true,
    },
    {
      'key': 1,
      'kind': 'Acupuncture',
      'title': 'Acupuncture',
      'performedOn': null,
      'performedTime': '14:30:00',
      'product': null,
      'manufacturer': null,
      'batchNumber': null,
      'validFrom': null,
      'validUntil': null,
      'targets': <String>[],
      'veterinarian': null,
      'clinic': null,
      'evidence': null,
      'page': 2,
      'warnings': [
        {'field': 'performedOn', 'issue': 'Unreadable'},
      ],
      'duplicateOf': null,
      'planId': null,
      'selected': false,
    },
  ],
  'identifiers': [
    {
      'key': 0,
      'type': 'IsoChip',
      'code': '276098100123456',
      'appliedOn': '2020-03-01',
      'location': 'Left side of the neck',
      'evidence': null,
      'page': 1,
      'warnings': <Object?>[],
      'selected': true,
    },
    {
      'key': 1,
      'type': 'Implant',
      'code': 'X1',
      'appliedOn': null,
      'location': null,
      'evidence': null,
      'page': 1,
      'warnings': <Object?>[],
      'selected': true,
    },
  ],
  'passport': {
    'passportNumber': 'DE0123456',
    'issuingCountry': 'DE',
    'issuedOn': '2020-03-01',
    'evidence': null,
    'page': 1,
    'warnings': [
      {'field': 'passportNumber', 'issue': 'DiffersFromSaved'},
    ],
    'selected': false,
  },
  'weights': <Object?>[],
};

void main() {
  late FakeAdapter adapter;
  late ApiAiRepository ai;
  // A function: a response body can be read only once.
  var answer = () => json(null);

  setUp(() {
    adapter = FakeAdapter((_) => answer());
    ai = ApiAiRepository(
      ApiClient(
        baseUrl: 'http://localhost:5080',
        authHeaders: () async => const {},
        httpClientAdapter: adapter,
      ),
    );
  });

  Map<String, Object?> sentBody() =>
      adapter.requests.last.data as Map<String, Object?>;

  test('a ready scan: calendar dates, doubts, and values this app does not '
      'know kept harmless', () async {
    answer = () => json(scanJson(draft: draftJson()));
    final scan = await ai.getScan('scan-1');

    expect(adapter.requests.single.path, '/api/v1/ai-imports/scan-1');
    expect(scan.status, ScanStatus.ready);
    expect(scan.source, ScanSource.passportPages);
    expect([for (final page in scan.pages) page.id], ['page-1', 'page-2']);
    expect(scan.createdAt.isUtc, isTrue, reason: 'a moment, shown local');

    final draft = scan.draft!;
    final rabies = draft.records[0];
    expect(rabies.kind, CareKind.vaccination);
    expect(rabies.performedOn, DateTime(2025, 3, 12));
    expect(rabies.validUntil, DateTime(2028, 3, 11));
    expect(rabies.targets, [VaccineTarget.rabies], reason: 'unknown left out');
    expect(rabies.planId, 'plan-rabies');
    expect(rabies.selected, isTrue);
    expect(rabies.warnings, const [
      DraftWarning('performedOn', DraftIssue.ambiguous),
      DraftWarning('batchNumber', DraftIssue.other),
    ]);

    final unknownKind = draft.records[1];
    expect(unknownKind.kind, CareKind.other);
    expect(unknownKind.performedOn, isNull);
    expect(unknownKind.performedTime, const TimeOfDay(hour: 14, minute: 30));
    expect(unknownKind.page, 2);

    expect(draft.identifiers, hasLength(1), reason: 'unknown type left out');
    expect(draft.identifiers.single.type, IdentifierType.isoChip);
    expect(draft.identifiers.single.appliedOn, DateTime(2020, 3, 1));
    expect(draft.passport?.number, 'DE0123456');
    expect(draft.passport?.selected, isFalse);
    expect(draft.passport?.warnings.single.issue, DraftIssue.differsFromSaved);
  });

  test("a check-up's weight comes with its entry, and goes back with the "
      'record when saving', () async {
    answer = () => json(
      scanJson(
        draft: {
          'records': [
            {
              'key': 0,
              'kind': 'VetExam',
              'title': 'Annual check-up',
              'performedOn': '2025-06-10',
              'performedTime': null,
              'product': null,
              'manufacturer': null,
              'batchNumber': null,
              'validFrom': null,
              'validUntil': null,
              'targets': <String>[],
              'veterinarian': null,
              'clinic': null,
              'weightKg': 4.25,
              'evidence': 'Weight 4.25 kg',
              'page': 1,
              'warnings': [
                {'field': 'weightKg', 'issue': 'InvalidFormat'},
              ],
              'duplicateOf': null,
              'planId': null,
              'selected': true,
            },
          ],
          'identifiers': <Object?>[],
          'passport': null,
          'weights': <Object?>[],
        },
      ),
    );
    final draft = (await ai.getScan('scan-1')).draft!.records.single;
    expect((draft.kind, draft.weightKg), (CareKind.vetExam, 4.25));
    expect(draft.warnings, const [
      DraftWarning('weightKg', DraftIssue.invalidFormat),
    ]);

    answer = () => json({
      'recordIds': ['r1'],
      'plansMoved': 0,
      'identifiersAdded': 0,
      'passportUpdated': false,
      'documentId': null,
    });
    await ai.applyScan(
      'scan-1',
      ScanApplyInput(
        records: [
          ScanRecordInput(
            record: CareRecordInput(
              kind: CareKind.vetExam,
              title: 'Annual check-up',
              performedOn: DateTime(2025, 6, 10),
              weightKg: 4.25,
            ),
          ),
        ],
      ),
    );
    final records = sentBody()['records']! as List<Object?>;
    final record = (records.single! as Map<String, Object?>)['record']!;
    expect((record as Map<String, Object?>)['weightKg'], 4.25);
  });

  test('a note: its text, no photos, and the weights of its draft with '
      'calendar dates and doubts', () async {
    answer = () => json({
      ...scanJson(
        draft: {
          'records': <Object?>[],
          'identifiers': <Object?>[],
          'passport': null,
          'weights': [
            {
              'key': 0,
              'measuredOn': '2026-10-06',
              'weightKg': 4.235,
              'evidence': 'weighs 4.235',
              'page': 1,
              'warnings': <Object?>[],
              'duplicateOf': null,
              'selected': true,
            },
            {
              'key': 1,
              'measuredOn': null,
              'weightKg': null,
              'evidence': 'weighed her',
              'page': 1,
              'warnings': [
                {'field': 'measuredOn', 'issue': 'Unreadable'},
                {'field': 'weightKg', 'issue': 'Unreadable'},
              ],
              'duplicateOf': null,
              'selected': false,
            },
            {
              'key': 2,
              'measuredOn': '2026-09-01',
              'weightKg': 4.1,
              'evidence': null,
              'page': 1,
              'warnings': [
                {'field': 'measuredOn', 'issue': 'AlreadySaved'},
              ],
              'duplicateOf': 'weighing-1',
              'selected': false,
            },
          ],
        },
      ),
      'source': 'Text',
      'pages': <Object?>[],
      'text': 'Weighs 4.235 yesterday',
    });
    final scan = await ai.getScan('scan-1');

    expect(scan.source, ScanSource.note);
    expect(scan.isNote, isTrue);
    expect(scan.text, 'Weighs 4.235 yesterday');
    expect(scan.pages, isEmpty);
    final weights = scan.draft!.weights;
    expect(weights, hasLength(3));
    expect(weights[0].measuredOn, DateTime(2026, 10, 6));
    expect(weights[0].weightKg, 4.235);
    expect(weights[0].evidence, 'weighs 4.235');
    expect(weights[0].selected, isTrue);
    expect((weights[1].measuredOn, weights[1].weightKg), (null, null));
    expect(weights[1].warnings, const [
      DraftWarning('measuredOn', DraftIssue.unreadable),
      DraftWarning('weightKg', DraftIssue.unreadable),
    ]);
    expect(weights[2].duplicateOf, 'weighing-1');
    expect(weights[2].warnings.single.issue, DraftIssue.alreadySaved);
    expect(scan.draft!.isEmpty, isFalse, reason: 'weights are something');
  });

  test('a scan has no text; a failed note can be read again while its text '
      'is there', () async {
    answer = () => json(scanJson(draft: draftJson()));
    expect((await ai.getScan('scan-1')).text, isNull);

    answer = () => json({
      ...scanJson(status: 'Failed', error: 'Busy'),
      'source': 'Text',
      'pages': <Object?>[],
      'text': 'Rabies shot today',
    });
    final failed = await ai.getScan('scan-1');
    expect(failed.canReadAgain, isTrue, reason: 'no photos needed');

    answer = () => json({
      ...scanJson(status: 'Discarded'),
      'source': 'Text',
      'pages': <Object?>[],
      'text': null,
    });
    expect((await ai.getScan('scan-1')).canReadAgain, isFalse);
  });

  test(
    'starting a note sends its text, no photos, and the request id',
    () async {
      answer = () => json({
        ...scanJson(status: 'Queued'),
        'source': 'Text',
        'pages': <Object?>[],
        'text': 'Rabies shot today',
      }, 202);
      final scan = await ai.startScan(
        'p1',
        source: ScanSource.note,
        text: 'Rabies shot today',
        requestId: 'request-1',
      );

      expect(adapter.requests.single.path, '/api/v1/ai-imports');
      expect(sentBody(), {
        'petId': 'p1',
        'source': 'Text',
        'fileIds': <Object?>[],
        'requestId': 'request-1',
        'text': 'Rabies shot today',
        'retryOf': null,
      });
      expect((scan.source, scan.status), (ScanSource.note, ScanStatus.queued));
    },
  );

  test('reading a failed one again names it (retryOf)', () async {
    answer = () => json({
      ...scanJson(status: 'Queued'),
      'source': 'Text',
      'pages': <Object?>[],
      'text': 'Rabies shot today',
    }, 202);
    await ai.startScan(
      'p1',
      source: ScanSource.note,
      text: 'Rabies shot today',
      retryOf: 'failed-1',
      requestId: 'request-2',
    );

    expect(sentBody()['retryOf'], 'failed-1');
    expect(sentBody()['requestId'], 'request-2');
  });

  test('the waiting notes and the waiting scans are asked for apart', () async {
    answer = () => json([
      {
        ...scanJson(status: 'Failed', error: 'Busy'),
        'source': 'Text',
        'pages': <Object?>[],
        'text': 'Rabies shot today',
      },
    ]);
    final notes = await ai.getPetScans('p1', notes: true);
    expect(adapter.requests.last.path, '/api/v1/pets/p1/ai-imports');
    expect(adapter.requests.last.queryParameters, {'notes': true});
    expect(notes.single.isNote, isTrue);

    answer = () => json(<Object?>[]);
    await ai.getPetScans('p1', notes: false);
    expect(adapter.requests.last.queryParameters, {'notes': false});
    await ai.getPetScans('p1');
    expect(adapter.requests.last.queryParameters, isEmpty, reason: 'both');
  });

  test('saving sends the ticked weights as weighings, dates as dates and to '
      'the gram, and says how many were added', () async {
    answer = () => json({
      'recordIds': <Object?>[],
      'plansMoved': 0,
      'identifiersAdded': 0,
      'passportUpdated': false,
      'documentId': null,
      'weightsAdded': 2,
    });
    final result = await ai.applyScan(
      'scan-1',
      ScanApplyInput(
        weights: [
          ScanWeightInput(measuredOn: DateTime(2026, 10, 6), weightKg: 4.2),
          ScanWeightInput(
            measuredOn: DateTime(2026, 9, 1),
            weightKg: 4.2350000001,
          ),
        ],
        keepPhotos: false,
      ),
    );

    final body = sentBody();
    expect(body['weights'], [
      {'measuredOn': '2026-10-06', 'weightKg': 4.2},
      {'measuredOn': '2026-09-01', 'weightKg': 4.235},
    ]);
    expect(body['keepPhotos'], false);
    expect(result.weightsAdded, 2);

    // An answer without the count (an older server): none.
    answer = () => json({
      'recordIds': ['r1'],
      'plansMoved': 0,
      'identifiersAdded': 0,
      'passportUpdated': false,
      'documentId': null,
    });
    final older = await ai.applyScan('scan-1', const ScanApplyInput());
    expect(older.weightsAdded, 0);
    expect(sentBody()['weights'], <Object?>[]);
  });

  test('a failed scan says why; an unknown reason reads as none', () async {
    answer = () => json(scanJson(status: 'Failed', error: 'Busy'));
    expect((await ai.getScan('scan-1')).error, ScanError.busy);

    answer = () => json(scanJson(status: 'Failed', error: 'Overheated'));
    final unknown = await ai.getScan('scan-1');
    expect(unknown.status, ScanStatus.failed);
    expect(unknown.error, isNull);
  });

  test('starting sends the pet, what was scanned, the photos in order and '
      'the request id', () async {
    answer = () => json(scanJson(status: 'Queued'), 202);
    final scan = await ai.startScan(
      'p1',
      source: ScanSource.vetDocument,
      fileIds: const ['f2', 'f1'],
      requestId: 'request-1',
    );

    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.path, '/api/v1/ai-imports');
    expect(sentBody(), {
      'petId': 'p1',
      'source': 'VetDocument',
      'fileIds': ['f2', 'f1'],
      'requestId': 'request-1',
      'text': null,
      'retryOf': null,
    });
    expect(scan.status, ScanStatus.queued);
  });

  test('saving sends the ticked entries, dates as dates, and what to do '
      'with the photos', () async {
    answer = () => json({
      'recordIds': ['r1'],
      'plansMoved': 1,
      'identifiersAdded': 1,
      'passportUpdated': true,
      'documentId': 'doc-1',
    });
    final result = await ai.applyScan(
      'scan-1',
      ScanApplyInput(
        records: [
          ScanRecordInput(
            record: CareRecordInput(
              kind: CareKind.vaccination,
              title: 'Rabies vaccination',
              performedOn: DateTime(2025, 3, 12),
              product: 'Nobivac Rabies',
              validUntil: DateTime(2028, 3, 11),
              targets: const [VaccineTarget.rabies],
            ),
            planId: 'plan-rabies',
          ),
        ],
        identifiers: [
          PetIdentifier(
            type: IdentifierType.isoChip,
            code: '276098100123456',
            rawCode: '276 098 100 123 456',
            appliedOn: DateTime(2020, 3, 1),
          ),
        ],
        passport: ScanPassportInput(
          number: 'DE0123456',
          issuedOn: DateTime(2020, 3, 1),
        ),
        keepPhotos: false,
      ),
    );

    expect(adapter.requests.single.path, '/api/v1/ai-imports/scan-1/apply');
    final body = sentBody();
    final records = body['records']! as List<Object?>;
    final record = records.single! as Map<String, Object?>;
    expect(record['planId'], 'plan-rabies');
    final fields = record['record']! as Map<String, Object?>;
    expect(fields['kind'], 'Vaccination');
    expect(fields['performedOn'], '2025-03-12');
    expect(fields['validUntil'], '2028-03-11');
    expect(fields['targets'], ['Rabies']);
    expect(fields['requestId'], isNull, reason: 'applying is idempotent');
    expect(body['identifiers'], [
      {
        'type': 'IsoChip',
        // As typed: the server normalises it.
        'code': '276 098 100 123 456',
        'appliedOn': '2020-03-01',
        'readOn': null,
        'location': null,
      },
    ]);
    expect(body['passport'], {
      'passportNumber': 'DE0123456',
      'issuingCountry': null,
      'issuedOn': '2020-03-01',
    });
    expect(body['keepPhotos'], false);

    expect(result.recordIds, ['r1']);
    expect(result.plansMoved, 1);
    expect(result.passportUpdated, isTrue);
    expect(result.documentId, 'doc-1');
  });

  test('discarding a scan that is gone is no error; one that was saved '
      'is (409)', () async {
    answer = () => json({'status': 404, 'title': 'Not Found'}, 404);
    await ai.discardScan('scan-1');
    expect(adapter.requests.single.method, 'DELETE');

    answer = () =>
        json({'status': 409, 'title': "A saved scan can't be discarded."}, 409);
    await expectLater(
      () => ai.discardScan('scan-1'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.conflict,
        ),
      ),
    );

    answer = () => json({'status': 500, 'title': 'Oops'}, 500);
    await expectLater(
      () => ai.discardScan('scan-1'),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.server),
      ),
    );
  });

  test('the status and the connection test', () async {
    answer = () => json({
      'configured': true,
      'models': [
        {'provider': 'Gemini', 'model': 'gemini-3.8-flash', 'ready': true},
        {'provider': 'Mistral', 'model': 'mistral-small', 'ready': false},
      ],
      'freeTier': true,
      'thisMonth': {'requests': 3, 'inputTokens': 5100, 'outputTokens': 2900},
    });
    final status = await ai.getStatus();
    expect(status.configured, isTrue);
    expect(status.freeTier, isTrue);
    expect(
      [for (final m in status.models) m.provider],
      [AiProvider.gemini, AiProvider.other],
    );
    expect(status.thisMonth.inputTokens, 5100);

    answer = () => json({
      'ok': false,
      'model': null,
      'latencyMs': 4200,
      'problem': 'Busy',
    });
    final failed = await ai.testConnection();
    expect(failed.ok, isFalse);
    expect(failed.problem, AiTestProblem.busy);
    expect(failed.latency, const Duration(milliseconds: 4200));

    answer = () => json({
      'ok': true,
      'model': 'gemini-3.8-flash',
      'latencyMs': 1240,
      'problem': null,
    });
    final ok = await ai.testConnection();
    expect(ok.ok, isTrue);
    expect(ok.problem, isNull);
    expect(ok.model, 'gemini-3.8-flash');
  });
}
