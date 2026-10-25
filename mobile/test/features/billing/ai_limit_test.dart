// AI reads photos within the month's AI photos: the group's for its plan,
// and on Free also the person's in all their Free groups. The refusal (409
// urn:collarbell:problem:ai-limit) carries how many are used of how many and
// when the count starts again: the app says the photos are used up, or that
// fewer are left than were sent, and the screens that read photos offer the
// plan. A 409 without the type still means AI isn't set up. Too many
// readings in a row (429) say to wait.
import 'package:collarbell/app/router.dart';
import 'package:collarbell/data/api/api_client.dart';
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/data/api/app_events.dart';
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/pets/chip_reader.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/features/pets/pets_repository.dart';
import 'package:collarbell/features/supplies/supplies_repository.dart';
import 'package:collarbell/l10n/app_localizations_en.dart';
import 'package:collarbell/l10n/app_localizations_ru.dart';
import 'package:collarbell/shared/error_messages.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:dio/dio.dart' show Headers, ResponseBody;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../data/api/api_client_test.dart' show FakeAdapter, problem;
import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

/// The server's refusal, as `ProblemDetails` reads it from the body. The
/// count starts again at midnight UTC; noon here keeps the day the same in
/// any time zone the tests run in.
ApiException aiLimit({
  Object? scope = 'household',
  Object? plan = 'Free',
  Object? limit = 20,
  Object? used = 20,
  Object? requested = 1,
  Object? resetsAt = '2026-11-01T12:00:00Z',
}) => ApiException(
  ApiErrorKind.conflict,
  statusCode: 409,
  problem: ProblemDetails.tryParse({
    'type': ProblemTypes.aiLimit,
    'title': "This month's AI photos are used up.",
    'status': 409,
    'scope': ?scope,
    'plan': ?plan,
    'limit': ?limit,
    'used': ?used,
    'requested': ?requested,
    'resetsAt': ?resetsAt,
    'traceId': '00-4bf92f35-01',
  }),
);

/// An API client whose server answers every request with [answer].
ApiClient _client(ResponseBody Function() answer) => ApiClient(
  baseUrl: 'http://api.test',
  authHeaders: () async => {'X-Dev-User': 'dev-1'},
  httpClientAdapter: FakeAdapter((_) async => answer()),
);

/// The refusal's body, as the server sends it.
ResponseBody _aiLimitBody() => problem(409, {
  'type': ProblemTypes.aiLimit,
  'title': "This month's AI photos are used up.",
  'status': 409,
  'scope': 'household',
  'plan': 'Free',
  'limit': 20,
  'used': 20,
  'requested': 1,
  'resetsAt': '2026-11-01T00:00:00Z',
});

/// The 409 of the AI calls when AI isn't set up: no type.
ResponseBody _notSetUpBody() =>
    problem(409, {'title': "AI isn't configured.", 'status': 409});

const _aiReady = AiStatus(configured: true);

void main() {
  final en = AppLocalizationsEn();
  final ru = AppLocalizationsRu();

  group('the message', () {
    // Widget tests get the dates' words from the app's localizations.
    setUpAll(() async {
      await initializeDateFormatting('en');
      await initializeDateFormatting('ru');
    });

    test("the server's refusal reaches the app with its numbers, and "
        "changes nothing about the user's group or role", () async {
      final lost = <String>[];
      var roleRefusals = 0;
      final adapter = FakeAdapter(
        (_) async => problem(409, {
          'type': ProblemTypes.aiLimit,
          'title': "This month's AI photos are used up.",
          'status': 409,
          'scope': 'person',
          'plan': 'Free',
          'limit': 20,
          'used': 19,
          'requested': 3,
          'resetsAt': '2026-11-01T00:00:00Z',
        }),
      );
      final client = ApiClient(
        baseUrl: 'http://api.test',
        authHeaders: () async => {'X-Dev-User': 'dev-1'},
        household: () => 'home',
        onNotAMember: lost.add,
        onRoleRefused: () => roleRefusals++,
        httpClientAdapter: adapter,
      );

      Object? error;
      try {
        await client.send((api) => api.ai.testAi());
      } catch (caught) {
        error = caught;
      }

      expect(isAiLimit(error!), isTrue);
      final limit = AiLimit.of(error)!;
      expect(limit.scope, AiLimitScope.person);
      expect(limit.plan, 'Free');
      expect(limit.limit, 20);
      expect(limit.used, 19);
      expect(limit.requested, 3);
      expect(limit.left, 1);
      // A moment: its date is the one on this phone.
      expect(limit.resetsAt, DateTime.utc(2026, 11, 1).toLocal());
      expect(limit.resetsAt.isUtc, isFalse);
      expect(lost, isEmpty);
      expect(roleRefusals, 0);
    });

    test("the group's photos used up: how many of how many, the plan, and "
        'when they count from zero again', () {
      expect(
        errorMessageFor(aiLimit(), en),
        'AI has read 20 of 20 photos this month: that\'s the limit of the '
        'Free plan. The count starts again on November 1.',
      );
      expect(
        errorMessageFor(aiLimit(), ru),
        'В этом месяце AI прочитал 20 из 20 фото — это лимит тарифа Free. '
        'Счётчик обнулится 1 ноября.',
      );
      expect(
        errorMessageFor(aiLimit(plan: 'Premium', limit: 300, used: 300), en),
        'AI has read 300 of 300 photos this month: that\'s the limit of the '
        'Premium plan. The count starts again on November 1.',
      );
      // An answer without the scope is about the group.
      expect(
        errorMessageFor(aiLimit(scope: null), en),
        errorMessageFor(aiLimit(), en),
      );
    });

    test("the group's, some left but fewer than were sent: how many are "
        'left', () {
      expect(
        errorMessageFor(aiLimit(used: 18, requested: 3), en),
        '2 of 20 photos are left this month: choose fewer.',
      );
      expect(
        errorMessageFor(aiLimit(used: 18, requested: 3), ru),
        'Осталось 2 из 20 фото в этом месяце: выберите меньше.',
      );
    });

    test("the person's, in all their Free groups together", () {
      expect(
        errorMessageFor(aiLimit(scope: 'person'), en),
        "You've sent AI 20 of 20 photos this month in all your groups on "
        'Free. The count starts again on November 1.',
      );
      expect(
        errorMessageFor(aiLimit(scope: 'person'), ru),
        'Вы уже отправили AI 20 из 20 фото в этом месяце во всех своих '
        'группах на Free. Счётчик обнулится 1 ноября.',
      );
      expect(
        errorMessageFor(aiLimit(scope: 'person', used: 18, requested: 3), en),
        'You have 2 of 20 photos left this month in all your groups on Free: '
        'choose fewer.',
      );
      expect(
        errorMessageFor(aiLimit(scope: 'person', used: 18, requested: 3), ru),
        'Вам осталось 2 из 20 фото в этом месяце во всех своих группах на '
        'Free: выберите меньше.',
      );
    });

    test('without the numbers: just that the limit is used up', () {
      for (final error in [
        aiLimit(used: null),
        aiLimit(limit: null),
        aiLimit(resetsAt: null),
        aiLimit(resetsAt: 'soon'),
        aiLimit(plan: null),
      ]) {
        expect(AiLimit.of(error), isNull);
        expect(errorMessageFor(error, en), "This month's AI limit is used up.");
        expect(errorMessageFor(error, ru), 'Лимит AI на этот месяц исчерпан.');
      }
      // A 403 is about the role, as before.
      expect(
        errorMessageFor(
          const ApiException(ApiErrorKind.forbidden, statusCode: 403),
          en,
        ),
        "Your role in the group doesn't allow this.",
      );
    });

    test('the scans tell the limit from "AI isn\'t set up", both 409s, by '
        'the type', () async {
      Future<Object> failure(Future<Object?> Function() request) async {
        try {
          await request();
        } catch (error) {
          return error;
        }
        fail('the request went through');
      }

      final package = await failure(
        () => ApiSuppliesRepository(_client(_aiLimitBody)).scan(['f1']),
      );
      expect(isAiLimit(package), isTrue);
      expect(
        await failure(
          () => ApiSuppliesRepository(_client(_notSetUpBody)).scan(['f1']),
        ),
        isA<ProductScanFailed>().having(
          (failed) => failed.problem,
          'problem',
          ProductScanProblem.notConfigured,
        ),
      );

      final chip = await failure(
        () => ApiPetsRepository(_client(_aiLimitBody)).scanIdentifiers(['f1']),
      );
      expect(isAiLimit(chip), isTrue);
      expect(
        await failure(
          () =>
              ApiPetsRepository(_client(_notSetUpBody)).scanIdentifiers(['f1']),
        ),
        isA<IdentifierScanFailed>().having(
          (failed) => failed.problem,
          'problem',
          IdentifierScanProblem.notConfigured,
        ),
      );
    });

    test('too many readings in a row (429): wait a minute, or as long as the '
        'server says', () async {
      ResponseBody tooMany(String? retryAfter) => ResponseBody.fromString(
        '{"title":"Too Many Requests","status":429}',
        429,
        headers: {
          Headers.contentTypeHeader: ['application/problem+json'],
          'retry-after': ?(retryAfter == null ? null : [retryAfter]),
        },
      );
      String? retryAfter;
      final client = ApiClient(
        baseUrl: 'http://api.test',
        authHeaders: () async => {'X-Dev-User': 'dev-1'},
        httpClientAdapter: FakeAdapter((_) async => tooMany(retryAfter)),
      );
      Future<ApiException> read() async {
        try {
          await client.send((api) => api.ai.testAi());
        } on ApiException catch (error) {
          return error;
        }
        fail('the request went through');
      }

      retryAfter = '42';
      final waitAWhile = await read();
      expect(waitAWhile.kind, ApiErrorKind.tooManyRequests);
      expect(waitAWhile.retryAfter, const Duration(seconds: 42));
      expect(
        errorMessageFor(waitAWhile, en),
        'Too many requests in a row. Try again in 42 seconds.',
      );
      expect(
        errorMessageFor(waitAWhile, ru),
        'Слишком много запросов подряд. Попробуйте через 42 секунды.',
      );

      retryAfter = '1';
      expect(
        errorMessageFor(await read(), ru),
        'Слишком много запросов подряд. Попробуйте через 1 секунду.',
      );

      retryAfter = null;
      final noWord = await read();
      expect(noWord.retryAfter, isNull);
      expect(
        errorMessageFor(noWord, en),
        'Too many requests in a row. Try again in a minute.',
      );
      expect(
        errorMessageFor(noWord, ru),
        'Слишком много запросов подряд. Попробуйте через минуту.',
      );
    });

    test('the visor tells them apart: the problem type, and the 429 by its '
        'name', () {
      expect(errorName(aiLimit()), 'conflict');
      expect(
        errorDetail(aiLimit()),
        'status=409 type=urn:collarbell:problem:ai-limit '
        'traceId=00-4bf92f35-01',
      );
      expect(
        errorName(
          const ApiException(ApiErrorKind.tooManyRequests, statusCode: 429),
        ),
        'tooManyRequests',
      );
    });
  });

  group('the screens that read photos', () {
    testWidgets('the connection test: the limit, without "It doesn\'t '
        'work", and the plan', (tester) async {
      final ai = FakeAiRepository(status: testAiStatus)..testError = aiLimit();
      await pumpApp(
        tester,
        location: AppRoutes.ai,
        overrides: fakeRepositories(ai: ai),
      );

      await tester.scrollUntilVisible(find.text('Test connection'), 300);
      await tapVisible(tester, find.text('Test connection'));

      expect(
        find.text(
          'AI has read 20 of 20 photos this month: that\'s the limit of the '
          'Free plan. The count starts again on November 1.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining("It doesn't work."), findsNothing);
      await tapVisible(tester, find.byKey(const ValueKey('openPlan')));
      expect(find.text('7 of 20'), findsOneWidget);
      // Back where it was.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Test connection'), findsOneWidget);
    });

    testWidgets('a passport scan with more pages than are left: how many '
        'are left; no "Try again", but a new scan and the plan', (
      tester,
    ) async {
      final ai = FakeAiRepository(status: testAiStatus)
        ..startError = aiLimit(used: 19);
      await pumpApp(
        tester,
        location: '/pets/p1/scan',
        overrides: fakeRepositories(
          pets: FakePetsRepository([
            const Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat),
          ]),
          picker: FakeMediaPicker()
            ..scanned = const [
              PickedMedia(path: '/tmp/page-1.jpg', name: 'page-1.jpg'),
              PickedMedia(path: '/tmp/page-2.jpg', name: 'page-2.jpg'),
            ],
          ai: ai,
        ),
      );

      await tapAndWait(tester, find.text('Scan with the camera'));

      expect(
        find.text('1 of 20 photos are left this month: choose fewer.'),
        findsOneWidget,
      );
      // A 409, but not "AI isn't set up".
      expect(find.textContaining("AI isn't set up"), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Scan again'), findsOneWidget);
      expect(find.byKey(const ValueKey('openPlan')), findsOneWidget);
    });

    testWidgets('a package scan over the limit: said, no "Try again", the '
        'plan, and typing it in still works', (tester) async {
      final supplies = FakeSuppliesRepository()..scanResult = aiLimit();
      await pumpApp(
        tester,
        location: AppRoutes.supplyScan(photos: true),
        overrides: fakeRepositories(
          supplies: supplies,
          picker: FakeMediaPicker()
            ..camera.add(
              const PickedMedia(path: '/tmp/front.jpg', name: 'front.jpg'),
            ),
          ai: FakeAiRepository(status: _aiReady),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('readPhotos')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('AI has read 20 of 20 photos this month'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('retry')), findsNothing);
      expect(find.byKey(const ValueKey('fillByHand')), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('openPlan')));
      expect(find.text('What Premium gives'), findsOneWidget);
    });

    testWidgets('a chip photo over the limit: the card says so', (
      tester,
    ) async {
      final pets = FakePetsRepository()..identifierScanResult = aiLimit();
      await pumpApp(
        tester,
        location: '/pets/new',
        size: const Size(390, 2600),
        overrides: fakeRepositories(
          pets: pets,
          ai: FakeAiRepository(status: _aiReady),
          chips: FakeChipReader([
            const ChipPhoto(
              PickedMedia(path: '/tmp/passport.jpg', name: 'passport.jpg'),
            ),
          ]),
        ),
      );
      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(CbTextField, 'Name'),
          matching: find.byType(TextFormField),
        ),
        'Murka',
      );
      await tester.tap(find.text('Add a microchip or tattoo'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Scan the number'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('AI has read 20 of 20 photos this month'),
        findsOneWidget,
      );
    });
  });
}
