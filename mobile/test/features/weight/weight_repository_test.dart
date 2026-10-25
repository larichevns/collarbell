// The weight repository against a fake HTTP layer: how the log is read
// (weighings and a vet's weights, newest first, scores, values a newer
// server may send) and what adding, changing and deleting a weighing send
// (the day as a date, the score with its scale, the request id).
import 'dart:convert';
import 'dart:typed_data';

import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/features/weight/weight.dart';
import 'package:collarbell/features/weight/weight_repository.dart';
import 'package:dio/dio.dart';
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

Map<String, Object?> weightJson(
  String id, {
  String source = 'Weighing',
  String measuredOn = '2026-10-05',
  num weightKg = 4.2,
  int? bcs,
  int? bcsScale,
  String? note,
  String createdAt = '2026-10-05T06:00:00+00:00',
}) => {
  'id': id,
  'petId': 'p1',
  'source': source,
  'measuredOn': measuredOn,
  'weightKg': weightKg,
  'bcs': bcs,
  'bcsScale': bcsScale,
  'note': note,
  'createdAt': createdAt,
  'updatedAt': createdAt,
};

void main() {
  late FakeAdapter adapter;
  late ApiWeightRepository weights;
  // A function: a response body can be read only once.
  var answer = () => json(null);

  setUp(() {
    adapter = FakeAdapter((_) => answer());
    weights = ApiWeightRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        authHeaders: () async => const {},
        httpClientAdapter: adapter,
      ),
    );
  });

  Map<String, Object?> sentBody() =>
      adapter.requests.last.data as Map<String, Object?>;

  test('the log: weighings and a vet\'s weights newest first, with scores '
      'and notes, and values a newer server may send', () async {
    answer = () => json([
      // Not in order: the log is sorted all the same.
      weightJson('w-old', measuredOn: '2026-08-01', weightKg: 3.95),
      weightJson(
        'w-1',
        weightKg: 4.235,
        bcs: 5,
        bcsScale: 9,
        note: 'Before breakfast',
        createdAt: '2026-10-05T18:00:00+00:00',
      ),
      weightJson(
        'r-1',
        source: 'CareRecord',
        measuredOn: '2026-09-12',
        weightKg: 4.1,
        note: 'Annual check-up',
      ),
      // The same day as w-1, added earlier.
      weightJson('w-morning', weightKg: 4.2),
      weightJson('x-1', source: 'Import', measuredOn: '2026-07-01'),
      weightJson('w-new-scale', measuredOn: '2026-06-01', bcs: 4, bcsScale: 7),
    ]);

    final log = await weights.getLog('p1');

    expect(adapter.requests.single.path, '/api/v1/pets/p1/weights');
    expect(
      [for (final entry in log) entry.id],
      ['w-1', 'w-morning', 'r-1', 'w-old', 'x-1', 'w-new-scale'],
    );
    final latest = log.first;
    expect(latest.source, WeightSource.weighing);
    expect(latest.measuredOn, DateTime(2026, 10, 5));
    expect((latest.weightKg, latest.grams), (4.235, 4235));
    expect(latest.bodyCondition, const BodyCondition(5, 9));
    expect(latest.note, 'Before breakfast');
    expect(latest.hasUnknownValues, isFalse);

    final vet = log[2];
    expect(
      (vet.source, vet.isVet, vet.isWeighing),
      (WeightSource.careRecord, true, false),
    );
    expect((vet.note, vet.bodyCondition), ('Annual check-up', null));
    expect(log[3].grams, 3950);

    // A source this app doesn't know, and a scale it doesn't: shown, kept
    // as they are, not edited.
    expect(
      (log[4].source, log[4].hasUnknownValues),
      (WeightSource.other, true),
    );
    expect(log[5].bodyCondition, const BodyCondition(4, 7));
    expect(log[5].hasUnknownValues, isTrue);
  });

  test('a weighing goes out as a date, to the gram, with its score and the '
      'request id', () async {
    answer = () => json(
      weightJson('w-1', weightKg: 4.235, bcs: 5, bcsScale: 9, note: 'At home'),
      201,
    );

    final saved = await weights.createWeighing(
      'p1',
      WeighingInput(
        measuredOn: DateTime(2026, 10, 5),
        weightKg: 4.235,
        bodyCondition: const BodyCondition(5, 9),
        note: 'At home',
      ),
      requestId: 'req-1',
    );

    final request = adapter.requests.single;
    expect((request.method, request.path), ('POST', '/api/v1/pets/p1/weights'));
    expect(sentBody(), {
      'measuredOn': '2026-10-05',
      'weightKg': 4.235,
      'bcs': 5,
      'bcsScale': 9,
      'note': 'At home',
      'requestId': 'req-1',
    });
    expect(
      (saved.id, saved.grams, saved.bodyCondition),
      ('w-1', 4235, const BodyCondition(5, 9)),
    );
  });

  test('a change sends no request id, and no score when it has none; '
      'deleting names the weighing', () async {
    answer = () => json(weightJson('w-1', weightKg: 4.3));
    await weights.updateWeighing(
      'w-1',
      WeighingInput(measuredOn: DateTime(2026, 10, 4), weightKg: 4.3),
    );

    final change = adapter.requests.single;
    expect((change.method, change.path), ('PUT', '/api/v1/weights/w-1'));
    expect(sentBody(), {
      'measuredOn': '2026-10-04',
      'weightKg': 4.3,
      'bcs': null,
      'bcsScale': null,
      'note': null,
      'requestId': null,
    });

    answer = () => ResponseBody.fromString('', 204);
    await weights.deleteWeighing('w-1');
    final delete = adapter.requests.last;
    expect((delete.method, delete.path), ('DELETE', '/api/v1/weights/w-1'));
  });
}
