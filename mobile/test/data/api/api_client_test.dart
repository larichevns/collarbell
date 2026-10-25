import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/data/api/app_session.dart';
import 'package:collarbell/data/api/generated/export.dart' as dto;
import 'package:collarbell/features/files/files_repository.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [respond] and records the requests.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(
  Object? body,
  int status, {
  String contentType = 'application/json; charset=utf-8',
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [contentType],
    },
  );
}

ResponseBody problem(int status, Map<String, Object?> body) =>
    json(body, status, contentType: 'application/problem+json');

const me = {
  'id': '0199a3b2-0000-7000-8000-000000000001',
  'email': 'anna@example.com',
  'displayName': null,
  'locale': 'ru',
  'timeZone': 'Europe/Berlin',
  'household': {
    'id': '0199a3b2-0000-7000-8000-000000000002',
    'name': 'Home',
    'timeZone': 'Europe/Berlin',
    'role': 'Owner',
  },
  'households': [
    {
      'id': '0199a3b2-0000-7000-8000-000000000002',
      'name': 'Home',
      'role': 'Owner',
      'timeZone': 'Europe/Berlin',
      'memberCount': 1,
    },
  ],
};

const fileLink = {
  'id': 'f1',
  'contentType': 'image/jpeg',
  'sizeBytes': 2048,
  'width': 800,
  'height': 600,
  'url': 'http://localhost:8333/collarbell/f1?X-Amz-Signature=a',
  'thumbnailUrl': 'http://localhost:8333/collarbell/f1-thumb?X-Amz-Signature=b',
  'expiresAt': '2026-10-01T14:31:17.959939+00:00',
};

Map<String, Object?> petJson({
  String species = 'Cat',
  Object? photo = fileLink,
}) => {
  'id': 'p1',
  'name': 'Murka',
  'species': species,
  'breed': null,
  'sex': 'Female',
  'birthDate': '2021-04-03',
  'birthDateApproximate': true,
  'neutered': true,
  'neuteredOn': null,
  'color': null,
  'markings': null,
  'coat': 'Ginger',
  'allergies': null,
  'notes': null,
  'status': 'Active',
  'photo': photo,
  'identifiers': [
    {
      'id': 'i1',
      'type': 'IsoChip',
      'code': '276098100123456',
      'rawCode': '276 098 100 123 456',
      'appliedOn': '2021-06-01',
      'readOn': null,
      'location': 'Left side of the neck',
    },
  ],
  'createdAt': '2026-10-01T14:16:17.976556+00:00',
  'updatedAt': '2026-10-01T14:16:17.976556+00:00',
};

void main() {
  ApiClient client(FakeAdapter adapter) => ApiClient(
    baseUrl: 'http://api.test',
    authHeaders: () async => {'X-Dev-User': 'dev-1', 'X-Dev-Email': 'a@b.co'},
    httpClientAdapter: adapter,
  );

  test('listPets sends the auth headers and parses the list', () async {
    final adapter = FakeAdapter((_) async => json([petJson()], 200));

    final pets = await ApiPetsRepository(client(adapter)).getPets();

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.uri.toString(), 'http://api.test/api/v1/pets');
    expect(request.headers['X-Dev-User'], 'dev-1');
    expect(request.headers['X-Dev-Email'], 'a@b.co');
    final pet = pets.single;
    expect(pet.name, 'Murka');
    expect(pet.birthDate, DateTime(2021, 4, 3));
    expect(pet.birthDateApproximate, isTrue);
    expect(pet.identifiers.single.code, '276098100123456');
    expect(pet.identifiers.single.appliedOn, DateTime(2021, 6, 1));
    expect(pet.photo?.width, 800);
    expect(pet.photo?.thumbnailCacheKey, 'f1-thumb');
  });

  test('every request names this launch for live updates (X-Client), so '
      'its own changes come back marked as its own', () async {
    final adapter = FakeAdapter(
      (options) async =>
          options.method == 'GET' ? json([petJson()], 200) : json(me, 200),
    );

    // Two clients, as after a change of the app's settings: one launch.
    await client(adapter).send((api) => api.pets.listPets());
    await client(adapter).send(
      (api) => api.me.updateMe(
        body: const dto.UpdateMeRequest(
          displayName: null,
          locale: 'ru',
          timeZone: null,
        ),
      ),
    );

    expect(liveClientHeader, 'X-Client');
    expect(
      [for (final request in adapter.requests) request.headers['X-Client']],
      [liveClientId, liveClientId],
    );
    // What the server passes on: letters, digits and dashes, at most 64.
    expect(liveClientId, matches(RegExp(r'^[A-Za-z0-9-]{1,64}$')));
    // Not the visor's id of the launch: every phone of the household hears
    // this one.
    expect(liveClientId, isNot(appSession));
  });

  test('updateMe sends every field; the server keeps null ones', () async {
    final adapter = FakeAdapter((_) async => json(me, 200));

    final result = await client(adapter).send(
      (api) => api.me.updateMe(
        body: const dto.UpdateMeRequest(
          displayName: null,
          locale: 'ru',
          timeZone: 'Europe/Berlin',
        ),
      ),
    );

    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.uri.path, '/api/v1/me');
    expect(request.data, {
      'displayName': null,
      'locale': 'ru',
      'timeZone': 'Europe/Berlin',
    });
    expect(result.household.name, 'Home');
    expect(result.displayName, isNull);
  });

  test('calendar dates are sent as YYYY-MM-DD, identifiers as typed', () async {
    final adapter = FakeAdapter((_) async => json(petJson(), 201));

    await ApiPetsRepository(client(adapter)).createPet(
      PetInput(
        name: 'Murka',
        species: PetSpecies.cat,
        birthDate: DateTime(2021, 4, 3),
        identifiers: [
          PetIdentifier(
            type: IdentifierType.isoChip,
            code: '276098100123456',
            rawCode: '276 098 100 123 456',
            appliedOn: DateTime(2021, 6, 1),
          ),
        ],
      ),
    );

    final body = adapter.requests.single.data as Map<String, Object?>;
    expect(body['birthDate'], '2021-04-03');
    expect(body['species'], 'Cat');
    expect(body['sex'], 'Unknown');
    expect(body['coat'], isNull, reason: 'the app sends no colour');
    expect(body['status'], isNull);
    expect(body['identifiers'], [
      {
        'type': 'IsoChip',
        'code': '276 098 100 123 456',
        'appliedOn': '2021-06-01',
        'readOn': null,
        'location': null,
      },
    ]);
  });

  test('uploads are multipart with the "file" field and more time', () async {
    final adapter = FakeAdapter((_) async => json(fileLink, 201));

    final file = await client(adapter).send(
      (api) => api.files.uploadFile(
        file: MultipartFile.fromBytes([1, 2, 3], filename: 'page.jpg'),
      ),
    );

    final request = adapter.requests.single;
    expect(request.uri.path, '/api/v1/files');
    expect(request.contentType, startsWith('multipart/form-data'));
    expect((request.data as FormData).files.single.key, 'file');
    expect(request.sendTimeout, UploadTimeoutInterceptor.uploadSendTimeout);
    expect(storedFileFromDto(file).sizeBytes, 2048);
  });

  test(
    'the AI connection test may take minutes; other requests may not',
    () async {
      final adapter = FakeAdapter(
        (options) async => options.uri.path.endsWith('/ai/test')
            ? json({
                'ok': true,
                'model': 'gemini-3.8-flash',
                'latencyMs': 61000,
                'problem': null,
              }, 200)
            : json(<Object?>[], 200),
      );

      await client(adapter).send((api) => api.ai.testAi());
      await client(adapter).send((api) => api.pets.listPets());

      final [aiTest, petList] = adapter.requests;
      expect(aiTest.uri.path, '/api/v1/ai/test');
      expect(
        aiTest.receiveTimeout,
        AiTestTimeoutInterceptor.testReceiveTimeout,
      );
      expect(petList.receiveTimeout, const Duration(seconds: 20));
    },
  );

  test('a chip scan sends the photo, may take minutes and gives the numbers '
      'read', () async {
    final adapter = FakeAdapter(
      (_) async => json({
        'identifiers': [
          {
            'type': 'IsoChip',
            'code': '643094100000001',
            'rawCode': '643 094 100 000 001',
            'appliedOn': '2021-08-14',
            'location': 'Between shoulder blades',
            'problem': null,
          },
          {
            'type': 'IsoChip',
            'code': '27609810012345',
            'rawCode': '27609810012345',
            'appliedOn': null,
            'location': null,
            'problem': 'An ISO microchip number has 15 digits.',
          },
        ],
        'model': 'gemini-3.8-flash',
      }, 200),
    );

    final readings = await ApiPetsRepository(
      client(adapter),
    ).scanIdentifiers(['f1']);

    final request = adapter.requests.single;
    expect(
      (request.method, request.uri.path),
      ('POST', '/api/v1/pets/identifiers/scan'),
    );
    expect(request.data, {
      'fileIds': ['f1'],
    });
    expect(request.receiveTimeout, AiTestTimeoutInterceptor.testReceiveTimeout);
    final [chip, misread] = readings;
    expect(
      (chip.type, chip.code, chip.rawCode, chip.appliedOn, chip.location),
      (
        IdentifierType.isoChip,
        '643094100000001',
        '643 094 100 000 001',
        DateTime(2021, 8, 14),
        'Between shoulder blades',
      ),
    );
    expect(misread.problem, 'An ISO microchip number has 15 digits.');
  });

  test('a chip scan called off stops waiting, and the request carries the '
      'token', () async {
    // The server takes its time: no answer comes.
    final adapter = FakeAdapter((_) => Completer<ResponseBody>().future);
    final cancel = CancelToken();

    final scan = ApiPetsRepository(
      client(adapter),
    ).scanIdentifiers(['f1'], cancelToken: cancel);
    await pumpEventQueue();
    expect(adapter.requests.single.cancelToken, same(cancel));
    cancel.cancel();

    await expectLater(
      scan,
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.cancelled,
        ),
      ),
    );
  });

  test(
    'a chip scan with busy models is a "busy", with no AI a "not set up"',
    () async {
      for (final (status, expected) in [
        (503, IdentifierScanProblem.busy),
        (409, IdentifierScanProblem.notConfigured),
        (502, IdentifierScanProblem.rejected),
      ]) {
        final repository = ApiPetsRepository(
          client(FakeAdapter((_) async => problem(status, {'status': status}))),
        );

        await expectLater(
          repository.scanIdentifiers(['f1']),
          throwsA(
            isA<IdentifierScanFailed>().having(
              (e) => e.problem,
              'problem',
              expected,
            ),
          ),
        );
      }
    },
  );

  test('a pet from a newer server with unknown values still loads', () async {
    final adapter = FakeAdapter(
      (_) async => json([petJson(species: 'Hamster', photo: null)], 200),
    );

    final pets = await ApiPetsRepository(client(adapter)).getPets();

    expect(pets.single.species, PetSpecies.other);
    expect(pets.single.photo, isNull);
  });

  test('problem+json errors become a typed ApiException', () async {
    final adapter = FakeAdapter(
      (_) async => problem(401, {
        'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.2',
        'title': 'Unauthorized',
        'status': 401,
        'detail': 'No credentials',
        'traceId': '00-abc-01',
      }),
    );

    await expectLater(
      client(adapter).send((api) => api.me.getMe()),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.problem?.detail, 'detail', 'No credentials')
            .having((e) => e.traceId, 'traceId', '00-abc-01'),
      ),
    );
  });

  test('validation problems keep the field errors', () async {
    final adapter = FakeAdapter(
      (_) async => problem(400, {
        'title': 'One or more validation errors occurred.',
        'status': 400,
        'errors': {
          'identifiers[1].code': [
            'Numbers starting with 999 belong to test chips.',
          ],
        },
      }),
    );

    await expectLater(
      ApiPetsRepository(
        client(adapter),
      ).createPet(const PetInput(name: 'Murka', species: PetSpecies.cat)),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.validation)
            .having((e) => e.problem?.errors, 'errors', {
              'identifiers[1].code': [
                'Numbers starting with 999 belong to test chips.',
              ],
            }),
      ),
    );
  });

  test('a refused upload says why: too large or unsupported', () async {
    for (final (status, kind) in [
      (413, ApiErrorKind.payloadTooLarge),
      (415, ApiErrorKind.unsupportedMediaType),
    ]) {
      final adapter = FakeAdapter(
        (_) async => problem(status, {'title': 'No', 'status': status}),
      );
      await expectLater(
        client(adapter).send(
          (api) => api.files.uploadFile(
            file: MultipartFile.fromBytes([1], filename: 'a.txt'),
          ),
        ),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', kind)),
      );
    }
  });

  test('a 5xx without a body is a server error', () async {
    final adapter = FakeAdapter((_) async => ResponseBody.fromString('', 503));

    await expectLater(
      client(adapter).send((api) => api.pets.listPets()),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.server)
            .having((e) => e.problem, 'problem', isNull),
      ),
    );
  });

  test('connection failures are network errors', () async {
    final adapter = FakeAdapter(
      (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused',
      ),
    );

    await expectLater(
      client(adapter).send((api) => api.me.getMe()),
      throwsA(
        isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network),
      ),
    );
  });

  test('a body that breaks the contract is an invalid response', () async {
    final adapter = FakeAdapter(
      (_) async => json([
        {'id': 42},
      ], 200),
    );

    await expectLater(
      client(adapter).send((api) => api.pets.listPets()),
      throwsA(
        isA<ApiException>().having(
          (e) => e.kind,
          'kind',
          ApiErrorKind.invalidResponse,
        ),
      ),
    );
  });
}
