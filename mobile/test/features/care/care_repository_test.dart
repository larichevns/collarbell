// The care and Today repositories against a fake HTTP layer: what they send
// (dates as dates, one photo per request) and how they read what a newer
// server may send (values this app doesn't know).
import 'dart:convert';
import 'dart:typed_data';

import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/care_repository.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/today/today_repository.dart';
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

Map<String, Object?> planJson({
  String kind = 'Deworming',
  String status = 'DueSoon',
  int? intervalValue = 3,
  String? intervalUnit = 'Month',
  List<String> targets = const [],
}) => {
  'id': 'plan1',
  'petId': 'p1',
  'kind': kind,
  'title': 'Deworming',
  'intervalValue': intervalValue,
  'intervalUnit': intervalUnit,
  'nextDueOn': '2026-10-06',
  'status': status,
  'daysLeft': 5,
  'lastDoneOn': '2026-07-06',
  'remindOffsetsDays': [7, 1, 0],
  'defaultProduct': 'Milbemax',
  'targets': targets,
  'presetCode': 'cat-deworm',
  'notes': null,
  'active': true,
  'createdAt': '2026-10-01T16:32:28.65824+00:00',
  'updatedAt': '2026-10-01T16:32:28.65824+00:00',
};

Map<String, Object?> recordJson({
  String kind = 'Vaccination',
  List<String> targets = const ['Rabies'],
  String source = 'Manual',
  List<Object?> files = const [],
}) => {
  'id': 'rec1',
  'petId': 'p1',
  'planId': null,
  'kind': kind,
  'title': 'Rabies',
  'performedOn': '2025-03-01',
  'performedTime': '14:30:00',
  'product': 'Nobivac Rabies',
  'manufacturer': 'MSD',
  'batchNumber': 'A123',
  'validFrom': '2025-03-22',
  'validUntil': '2028-02-28',
  'targets': targets,
  'clinic': null,
  'veterinarian': null,
  'weightKg': 4.2,
  'details': {
    'laboratory': null,
    'reportNumber': null,
    'titerIuPerMl': null,
    'fitForTravel': true,
  },
  'notes': null,
  'source': source,
  'files': files,
  'createdAt': '2026-10-01T16:32:28.65824+00:00',
  'updatedAt': '2026-10-01T16:32:28.65824+00:00',
};

void main() {
  late FakeAdapter adapter;
  late ApiCareRepository care;
  late ApiTodayRepository today;
  // A function: a response body can be read only once.
  var answer = () => json(null);

  setUp(() {
    adapter = FakeAdapter((_) => answer());
    final client = ApiClient(
      baseUrl: 'http://localhost:5080',
      authHeaders: () async => const {},
      httpClientAdapter: adapter,
    );
    care = ApiCareRepository(client);
    today = ApiTodayRepository(client);
  });

  Map<String, Object?> sentBody() =>
      adapter.requests.last.data as Map<String, Object?>;

  group('requests', () {
    test('a new plan sends its next date as a date and its request id; an '
        'edit sends none', () async {
      answer = () => json(planJson(), 201);
      final input = CarePlanInput(
        kind: CareKind.deworming,
        title: 'Deworming',
        interval: const CareInterval(3, IntervalUnit.month),
        nextDueOn: DateTime(2026, 10, 6),
        presetCode: 'cat-deworm',
      );
      await care.createPlan('p1', input, requestId: 'plan-request-1');

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/pets/p1/care-plans');
      expect(sentBody()['nextDueOn'], '2026-10-06');
      expect(sentBody()['intervalValue'], 3);
      expect(sentBody()['intervalUnit'], 'Month');
      expect(sentBody()['presetCode'], 'cat-deworm');
      expect(sentBody()['active'], isNull, reason: 'null keeps or defaults');
      expect(sentBody()['requestId'], 'plan-request-1');

      answer = () => json(planJson());
      await care.updatePlan('plan1', input);
      expect(adapter.requests.last.method, 'PUT');
      expect(sentBody().containsKey('requestId'), isTrue);
      expect(sentBody()['requestId'], isNull, reason: 'for creating only');
    });

    test('"Done" sends dates as dates, the time with seconds, the product '
        'as typed and its request id', () async {
      answer = () => json({'plan': planJson(), 'record': recordJson()});
      await care.completePlan(
        'plan1',
        CompletionInput(
          performedOn: DateTime(2026, 10, 1),
          performedTime: const TimeOfDay(hour: 9, minute: 5),
          validFrom: DateTime(2026, 10, 22),
          validUntil: DateTime(2027, 9, 30),
        ),
        requestId: '0199a3b2-0000-7000-8000-00000000d0e1',
      );

      expect(adapter.requests.single.path, '/api/v1/care-plans/plan1/complete');
      expect(sentBody()['performedOn'], '2026-10-01');
      expect(sentBody()['performedTime'], '09:05:00');
      expect(sentBody()['validFrom'], '2026-10-22');
      expect(sentBody()['validUntil'], '2027-09-30');
      expect(sentBody()['nextDueOn'], isNull);
      // No product means none: the server no longer fills in the plan's.
      expect(sentBody()['product'], isNull);
      expect(sentBody()['requestId'], '0199a3b2-0000-7000-8000-00000000d0e1');
    });

    test('a record sends its targets, details and dates', () async {
      answer = () => json(recordJson(), 201);
      await care.createRecord(
        'p1',
        CareRecordInput(
          kind: CareKind.rabiesTiter,
          title: 'Titer',
          performedOn: DateTime(2025, 2, 1),
          details: const CareRecordDetails(
            laboratory: 'BioLab',
            titerIuPerMl: 2.5,
          ),
        ),
        requestId: 'request-1',
      );
      expect(sentBody()['requestId'], 'request-1');
      expect(sentBody()['kind'], 'RabiesTiter');
      expect(sentBody()['performedOn'], '2025-02-01');
      expect(sentBody()['details'], {
        'laboratory': 'BioLab',
        'reportNumber': null,
        'titerIuPerMl': 2.5,
        'fitForTravel': null,
      });

      await care.createRecord(
        'p1',
        CareRecordInput(
          kind: CareKind.vaccination,
          title: 'Rabies',
          performedOn: DateTime(2025, 3, 1),
          targets: const [VaccineTarget.rabies, VaccineTarget.fpv],
        ),
        requestId: 'request-2',
      );
      expect(sentBody()['targets'], ['Rabies', 'Fpv']);
      expect(sentBody()['details'], isNull, reason: 'no empty details');

      // The request id is for creating only.
      answer = () => json(recordJson());
      await care.updateRecord(
        'rec1',
        CareRecordInput(
          kind: CareKind.vaccination,
          title: 'Rabies',
          performedOn: DateTime(2025, 3, 1),
        ),
      );
      expect(adapter.requests.last.method, 'PUT');
      expect(sentBody().containsKey('requestId'), isTrue);
      expect(sentBody()['requestId'], isNull);
    });

    test(
      'photos are attached one per request; a missing one is no error',
      () async {
        answer = () => json(recordJson());
        await care.addRecordFile('rec1', 'f1');
        expect(adapter.requests.single.path, '/api/v1/care-records/rec1/files');
        expect(sentBody(), {
          'fileIds': ['f1'],
        });

        answer = () => json({'status': 404, 'title': 'Not Found'}, 404);
        await care.removeRecordFile('rec1', 'f1');
        expect(adapter.requests.last.method, 'DELETE');
        expect(
          adapter.requests.last.path,
          '/api/v1/care-records/rec1/files/f1',
        );
      },
    );

    test('presets are asked for the pet species', () async {
      answer = () => json([]);
      await care.getPresets(PetSpecies.dog);
      expect(adapter.requests.single.uri.query, 'species=Dog');
    });
  });

  group('values this app does not know', () {
    test('a plan with an unknown kind, status, unit and target', () async {
      answer = () => json(
        planJson(
          kind: 'Microchipping',
          status: 'Snoozed',
          intervalUnit: 'Decade',
          targets: ['Rabies', 'Ehrlichia'],
        ),
      );
      final plan = await care.getPlan('plan1');

      expect(plan.kind, CareKind.other);
      // Worked out from the 5 days left.
      expect(plan.status, CareStatus.dueSoon);
      expect(plan.interval, isNull);
      expect(plan.intervalUnknown, isTrue);
      expect(plan.isOneOff, isFalse);
      expect(plan.targets, [VaccineTarget.rabies]);
      expect(plan.hasUnknownValues, isTrue);
    });

    test('a known plan is editable', () async {
      answer = () => json(planJson());
      final plan = await care.getPlan('plan1');
      expect(plan.hasUnknownValues, isFalse);
      expect(plan.interval, const CareInterval(3, IntervalUnit.month));
      expect(plan.lastDoneOn, DateTime(2026, 7, 6));
      expect(plan.nextDueOn, DateTime(2026, 10, 6));
    });

    test('a record with an unknown kind, target and source', () async {
      answer = () => json(
        recordJson(
          kind: 'Microchipping',
          targets: ['Ehrlichia'],
          source: 'Import',
        ),
      );
      final record = await care.getRecord('rec1');
      expect(record.kind, CareKind.other);
      expect(record.targets, isEmpty);
      expect(record.source, isNull);
      expect(record.hasUnknownValues, isTrue);
    });

    test('a known record maps every field', () async {
      answer = () => json(recordJson());
      final record = await care.getRecord('rec1');
      expect(record.hasUnknownValues, isFalse);
      expect(record.performedTime, const TimeOfDay(hour: 14, minute: 30));
      expect(record.validUntil, DateTime(2028, 2, 28));
      expect(record.weightKg, 4.2);
      expect(record.details.fitForTravel, isTrue);
      expect(record.source, RecordSource.manual);
    });

    test('presets the app could not save are left out', () async {
      answer = () => json([
        {
          'code': 'cat-deworm',
          'species': 'Cat',
          'kind': 'Deworming',
          'title': 'Deworming',
          'intervalValue': 3,
          'intervalUnit': 'Month',
          'targets': [],
          'dogOnly': false,
          'note': null,
        },
        {
          'code': 'cat-microchip',
          'species': 'Cat',
          'kind': 'Microchipping',
          'title': 'Microchip check',
          'intervalValue': 1,
          'intervalUnit': 'Year',
          'targets': [],
          'dogOnly': false,
          'note': null,
        },
        {
          'code': 'cat-decade',
          'species': 'Cat',
          'kind': 'Deworming',
          'title': 'Once a decade',
          'intervalValue': 1,
          'intervalUnit': 'Decade',
          'targets': [],
          'dogOnly': false,
          'note': null,
        },
      ]);
      final presets = await care.getPresets(PetSpecies.cat);
      expect([for (final p in presets) p.code], ['cat-deworm']);
    });

    test('Today with an unknown kind, status and coat', () async {
      answer = () => json({
        'date': '2026-10-01',
        'feedings': <Object?>[],
        'appointments': <Object?>[],
        'care': [
          {
            'planId': 'plan1',
            'petId': 'p1',
            'petName': 'Murka',
            'petCoat': 'Tabby',
            'petPhoto': null,
            'kind': 'Microchipping',
            'title': 'Chip check',
            'nextDueOn': '2026-09-28',
            'status': 'Late',
            'daysLeft': -3,
          },
        ],
        'shopping': <Object?>[],
      });
      final care = await today.getToday();
      final item = care.items.single;
      expect(care.date, DateTime(2026, 10, 1));
      expect(item.kind, CareKind.other);
      expect(item.status, CareStatus.overdue);
    });
  });
}
