// The feeding, visits and Today repositories against a fake HTTP layer:
// what they send (times as 08:00:00, days by name) and how they read the
// server's answers, including the 409 of a feeding marked by someone else.
import 'dart:convert';
import 'dart:typed_data';

import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/feeding/feeding.dart';
import 'package:collarbell/features/feeding/feeding_repository.dart';
import 'package:collarbell/features/today/today_repository.dart';
import 'package:collarbell/features/visits/visit.dart';
import 'package:collarbell/features/visits/visits_repository.dart';
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

ApiClient client(FakeAdapter adapter) => ApiClient(
  baseUrl: 'http://api.test',
  authHeaders: () async => const {},
  httpClientAdapter: adapter,
);

Map<String, Object?> markJson({String? byName = 'Anna', bool byMe = false}) => {
  'id': 'm1',
  'routineId': 'r1',
  'date': '2026-10-02',
  'time': '08:00:00',
  'status': 'Done',
  'doneAt': '2026-10-02T06:02:00+00:00',
  'byName': byName,
  'byMe': byMe,
};

void main() {
  test(
    'a schedule goes out with times and days the way the API wants',
    () async {
      final adapter = FakeAdapter(
        (_) => json({
          'id': 'r1',
          'petId': 'p1',
          'kind': 'Feeding',
          'times': ['08:00:00', '20:00:00'],
          'days': ['Sunday', 'Monday'],
          'food': 'Royal Canin',
          'amount': 40,
          'unit': 'Gram',
          'notes': null,
          'active': true,
          'createdAt': '2026-10-02T06:00:00+00:00',
          'updatedAt': '2026-10-02T06:00:00+00:00',
        }, 201),
      );
      final repository = ApiFeedingRepository(client(adapter));

      final saved = await repository.createSchedule(
        'p1',
        const FeedingInput(
          times: [
            TimeOfDay(hour: 8, minute: 0),
            TimeOfDay(hour: 20, minute: 0),
          ],
          days: [DateTime.monday, DateTime.sunday],
          food: 'Royal Canin',
          amount: 40,
          unit: PortionUnit.gram,
        ),
        requestId: 'req-1',
      );

      final sent = adapter.requests.single.data as Map<String, Object?>;
      expect(sent['times'], ['08:00:00', '20:00:00']);
      expect(sent['days'], ['Monday', 'Sunday']);
      expect(
        (sent['unit'], sent['kind'], sent['requestId']),
        ('Gram', 'Feeding', 'req-1'),
      );
      // Monday first, whatever order the server sends.
      expect(saved.days, [DateTime.monday, DateTime.sunday]);
      expect(saved.times.last, const TimeOfDay(hour: 20, minute: 0));
      expect((saved.unit, saved.hasUnknownValues), (PortionUnit.gram, false));
    },
  );

  test('a feeding someone else marked comes back with who and when', () async {
    final adapter = FakeAdapter((_) => json(markJson(), 409));
    final repository = ApiFeedingRepository(client(adapter));

    final marking = repository.mark(
      'r1',
      DateTime(2026, 10, 2),
      const TimeOfDay(hour: 8, minute: 0),
    );

    await expectLater(
      marking,
      throwsA(
        isA<FeedingAlreadyMarked>()
            .having((e) => e.mark.byName, 'byName', 'Anna')
            .having((e) => e.mark.byMe, 'byMe', false)
            .having((e) => e.mark.doneAt.isUtc, 'local time', false),
      ),
    );
    final sent = adapter.requests.single.data as Map<String, Object?>;
    expect(
      (sent['date'], sent['time'], sent['status']),
      ('2026-10-02', '08:00:00', 'Done'),
    );
  });

  test('a 409 that is not a mark stays a conflict', () async {
    final adapter = FakeAdapter(
      (_) => json({'title': 'Conflict', 'status': 409}, 409),
    );
    final repository = ApiFeedingRepository(client(adapter));

    await expectLater(
      repository.mark(
        'r1',
        DateTime(2026, 10, 2),
        const TimeOfDay(hour: 8, minute: 0),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.conflict,
        ),
      ),
    );
  });

  test('a visit goes out as a date and a time of the household', () async {
    final adapter = FakeAdapter(
      (_) => json({
        'id': 'v1',
        'type': 'Grooming',
        'title': 'Bath',
        'date': '2026-10-05',
        'time': '10:30:00',
        'startsAt': '2026-10-05T08:30:00+00:00',
        'durationMinutes': null,
        'location': null,
        'notes': null,
        'petIds': ['p1'],
        'remindOffsetsMinutes': [1440, 120],
        'status': 'Planned',
        'recordIds': <String>[],
        'createdAt': '2026-10-02T06:00:00+00:00',
        'updatedAt': '2026-10-02T06:00:00+00:00',
      }, 201),
    );
    final repository = ApiVisitsRepository(client(adapter));

    final visit = await repository.createVisit(
      VisitInput(
        type: VisitType.grooming,
        title: 'Bath',
        date: DateTime(2026, 10, 5),
        time: const TimeOfDay(hour: 10, minute: 30),
        petIds: const ['p1'],
        remindMinutesBefore: const [1440, 120],
      ),
      requestId: 'req-2',
    );

    final sent = adapter.requests.single.data as Map<String, Object?>;
    expect(
      (sent['date'], sent['time'], sent['type']),
      ('2026-10-05', '10:30:00', 'Grooming'),
    );
    expect(
      (visit.date, visit.time),
      (DateTime(2026, 10, 5), const TimeOfDay(hour: 10, minute: 30)),
    );
  });

  test('Today reads feedings with their marks and planned visits', () async {
    final adapter = FakeAdapter(
      (_) => json({
        'date': '2026-10-02',
        'feedings': [
          {
            'routineId': 'r1',
            'petId': 'p1',
            'petName': 'Murka',
            'petCoat': 'Ginger',
            'petPhoto': null,
            'time': '08:00:00',
            'food': 'Royal Canin',
            'amount': 40,
            'unit': 'Gram',
            'mark': markJson(byName: 'Me', byMe: true),
          },
        ],
        'appointments': [
          {
            'id': 'v1',
            'type': 'Vet',
            'title': 'Vaccination',
            'date': '2026-10-03',
            'time': '10:30:00',
            'startsAt': '2026-10-03T08:30:00+00:00',
            'daysAway': 1,
            'location': 'Clinic',
            'pets': [
              {'id': 'p1', 'name': 'Murka', 'coat': 'Ginger', 'photo': null},
            ],
          },
        ],
        'care': <Object?>[],
        'shopping': <Object?>[],
      }),
    );

    final today = await ApiTodayRepository(client(adapter)).getToday();

    final feeding = today.feedings.single;
    expect(
      (feeding.petName, feeding.time, feeding.amount),
      ('Murka', const TimeOfDay(hour: 8, minute: 0), 40.0),
    );
    expect(feeding.mark?.byMe, isTrue);
    final visit = today.visits.single;
    expect(
      (visit.title, visit.daysAway, visit.pets.single.name),
      ('Vaccination', 1, 'Murka'),
    );
    expect(today.isEmpty, isFalse);
  });
}
