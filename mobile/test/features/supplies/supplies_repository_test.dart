// The supplies repository against a fake HTTP layer: how it reads the
// estimate, what it sends, and how it tells a bad barcode or a busy AI.
import 'dart:convert';
import 'dart:typed_data';

import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/supplies/supplies_repository.dart';
import 'package:collarbell/features/supplies/supply.dart';
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

ApiClient client(FakeAdapter adapter) => ApiClient(
  baseUrl: 'http://api.test',
  authHeaders: () async => const {},
  httpClientAdapter: adapter,
);

Map<String, Object?> supplyJson({
  String status = 'BuyNow',
  String category = 'DryFood',
  String unit = 'Gram',
}) => {
  'id': 's1',
  'name': 'Royal Canin',
  'brand': 'Royal Canin',
  'barcode': '4006381333931',
  'category': category,
  'unit': unit,
  'packageSize': 2000,
  'kcalPerKg': 3860,
  'usageMode': 'Feeding',
  'manualDailyUsage': null,
  'leadTimeDays': 5,
  'storeUrl': null,
  'notes': null,
  'active': true,
  'forecast': {
    'remaining': 300.5,
    'usagePerDay': 80,
    'daysLeft': 3.8,
    'runsOutOn': '2026-10-05',
    'buyBy': '2026-09-30',
    'status': status,
    'countedFrom': '2026-09-20T08:00:00+00:00',
  },
  'feedings': [
    {
      'routineId': 'r1',
      'petId': 'p1',
      'petName': 'Murka',
      'amount': 40,
      'unit': 'Gram',
      'timesPerDay': 2,
      'counted': true,
    },
  ],
  'createdAt': '2026-09-20T08:00:00+00:00',
  'updatedAt': '2026-09-20T08:00:00+00:00',
};

void main() {
  test('an item is read with its estimate and feedings', () async {
    final repository = ApiSuppliesRepository(
      client(FakeAdapter((_) => json([supplyJson()]))),
    );

    final supply = (await repository.getSupplies()).single;

    expect(supply.forecast.status, SupplyStatus.buyNow);
    expect(supply.needsBuying, isTrue);
    expect(supply.forecast.runsOutOn, DateTime(2026, 10, 5));
    expect(supply.forecast.remaining, 300.5);
    expect(supply.feedings.single.petName, 'Murka');
    expect(supply.hasUnknownValues, isFalse);
  });

  test('values of a newer server keep the item from being edited', () async {
    final repository = ApiSuppliesRepository(
      client(
        FakeAdapter((_) => json(supplyJson(status: 'Expired', unit: 'Box'))),
      ),
    );

    final supply = await repository.getSupply('s1');

    expect(supply.hasUnknownValues, isTrue);
  });

  test('a purchase goes out with its request id; the new estimate comes '
      'back', () async {
    final adapter = FakeAdapter(
      (_) => json({
        'event': {
          'id': 'e1',
          'kind': 'Purchase',
          'quantity': 4000,
          'at': '2026-10-02T08:00:00+00:00',
          'byName': null,
          'byMe': true,
        },
        'supply': supplyJson(status: 'Enough'),
      }, 201),
    );
    final repository = ApiSuppliesRepository(client(adapter));

    final supply = await repository.addStock(
      's1',
      StockEventKind.purchase,
      4000,
      requestId: 'req-1',
    );

    expect(supply.forecast.status, SupplyStatus.enough);
    final request = adapter.requests.single;
    expect(request.path, '/api/v1/supplies/s1/stock-events');
    expect(request.data, {
      'kind': 'Purchase',
      'quantity': 4000.0,
      'requestId': 'req-1',
    });
  });

  test('a code that isn\'t a product barcode is told apart', () async {
    final repository = ApiSuppliesRepository(
      client(
        FakeAdapter(
          (_) => json({
            'title': 'One or more validation errors occurred.',
            'status': 400,
            'errors': {
              'code': ['Not a product barcode.'],
            },
          }, 400),
        ),
      ),
    );

    expect(() => repository.lookup('WIFI:x'), throwsA(isA<NotAProductCode>()));
  });

  test(
    'a scan with busy models is a "busy", with no AI a "not set up"',
    () async {
      for (final (status, problem) in [
        (503, ProductScanProblem.busy),
        (409, ProductScanProblem.notConfigured),
        (502, ProductScanProblem.rejected),
      ]) {
        final repository = ApiSuppliesRepository(
          client(FakeAdapter((_) => json({'status': status}, status))),
        );

        await expectLater(
          repository.scan(['f1']),
          throwsA(
            isA<ProductScanFailed>().having(
              (e) => e.problem,
              'problem',
              problem,
            ),
          ),
        );
      }
    },
  );

  test('a medicine read from photos says what it treats', () async {
    final repository = ApiSuppliesRepository(
      client(
        FakeAdapter(
          (_) => json({
            'product': {
              'isPetProduct': true,
              'name': 'Bravecto',
              'brand': 'MSD',
              'category': 'Medication',
              'unit': 'Dose',
              'packageSize': 1,
              'kcalPerKg': null,
              'barcode': null,
              'species': 'Cat',
              'treatment': 'FleaTick',
              'protectionWeeks': 12,
              'dosesInPackage': 1,
              'evidence': 'Bravecto, 12 weeks',
            },
            'model': 'gemini-3.8-flash',
          }),
        ),
      ),
    );

    final draft = await repository.scan(['f1'], barcode: '4006381333931');

    expect(
      (draft.treatment, draft.protectionWeeks, draft.unit, draft.packageSize),
      (CareKind.fleaTick, 12, SupplyUnit.dose, 1.0),
    );
  });

  test('a lookup gives the product and where it came from', () async {
    final repository = ApiSuppliesRepository(
      client(
        FakeAdapter(
          (_) => json({
            'code': '4006381333931',
            'batch': 'LOT42',
            'expiresOn': '2027-12-31',
            'existing': null,
            'product': {
              'name': 'Sterilised 37',
              'brand': 'Royal Canin',
              'category': 'DryFood',
              'unit': 'Gram',
              'packageSize': 2000,
              'kcalPerKg': 3860,
            },
            'source': 'OpenPetFoodFacts',
          }),
        ),
      ),
    );

    final found = await repository.lookup('4006381333931');

    expect(found.source, ProductSource.openPetFoodFacts);
    expect(found.product!.packageSize, 2000);
    expect(found.expiresOn, DateTime(2027, 12, 31));
    final prefill = SupplyPrefill.from(lookup: found);
    expect(
      (prefill.name, prefill.unit, prefill.dataSource),
      ('Sterilised 37', SupplyUnit.gram, SupplyDataSource.openPetFoodFacts),
    );
  });
}
