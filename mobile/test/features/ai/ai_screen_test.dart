// More → AI: whether the server reads photos with AI, its models, the
// free-tier warning, this month's use, and the connection test with its
// answer or what went wrong.
import 'package:collarbell/features/ai/ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

void main() {
  late FakeAiRepository ai;

  setUp(() => ai = FakeAiRepository(status: testAiStatus));

  Future<void> open(
    WidgetTester tester, {
    String language = 'en',
    Size size = const Size(390, 844),
  }) => pumpApp(
    tester,
    location: '/more',
    language: language,
    size: size,
    overrides: fakeRepositories(ai: ai),
  );

  Future<void> openAiScreen(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Reading photos with AI'), 300);
    await tapVisible(tester, find.text('Reading photos with AI'));
  }

  testWidgets('connected: models, the free-tier warning and this month', (
    tester,
  ) async {
    await open(tester);
    await tester.scrollUntilVisible(find.text('Reading photos with AI'), 300);
    expect(find.text('Connected'), findsOneWidget);
    await openAiScreen(tester);

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('gemini-3.8-flash'), findsOneWidget);
    expect(find.text('gemini-3.7-flash'), findsOneWidget);
    expect(find.text('Ready'), findsNWidgets(2));
    expect(
      find.textContaining('Free Gemini tier: Google may use what is sent'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('20,400'), 300);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('9,800'), findsOneWidget);
    // The screen loads the status afresh for the buttons too.
    expect(ai.statusCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('the connection test: the model and how fast, or why not', (
    tester,
  ) async {
    await open(tester);
    await openAiScreen(tester);

    await tester.scrollUntilVisible(find.text('Test connection'), 300);
    // The models are asked in turn: it can take a while.
    expect(
      find.text(
        'A model is asked the colour of a square on a small picture. It can '
        'take up to a minute.',
      ),
      findsOneWidget,
    );
    await tapVisible(tester, find.text('Test connection'));
    expect(ai.testCalls, 1);
    expect(
      find.text('It works: gemini-3.8-flash answered in 1.2 s.'),
      findsOneWidget,
    );

    ai.testResult = const AiTestResult(
      ok: false,
      latency: Duration(seconds: 3),
      problem: AiTestProblem.busy,
    );
    await tapVisible(tester, find.text('Test connection'));
    expect(
      find.text(
        "It doesn't work. The models are busy or out of free requests. Try "
        'again in a few minutes.',
      ),
      findsOneWidget,
    );

    ai.testResult = const AiTestResult(
      ok: false,
      latency: Duration(seconds: 2),
      model: 'gemini-3.8-flash',
      problem: AiTestProblem.wrongAnswer,
    );
    await tapVisible(tester, find.text('Test connection'));
    expect(
      find.text(
        "It doesn't work. A model answered but didn't see the picture.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('a status that could not be loaded: More says so, with a '
      'retry, instead of checking for ever', (tester) async {
    ai.statusError = networkError;
    await open(tester);
    await tester.scrollUntilVisible(find.text('Reading photos with AI'), 300);
    expect(find.text("Couldn't check"), findsOneWidget);
    expect(find.text('Checking…'), findsNothing);
    final calls = ai.statusCalls;

    ai.statusError = null;
    await tapVisible(tester, find.text('Try again'));
    expect(ai.statusCalls, calls + 1);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text("Couldn't check"), findsNothing);
  });

  testWidgets('not set up: where it is set up, and that typing works', (
    tester,
  ) async {
    ai.status = const AiStatus(
      configured: false,
      models: [
        AiModel(
          provider: AiProvider.gemini,
          name: 'gemini-3.8-flash',
          ready: false,
        ),
      ],
    );
    await open(tester);
    await tester.scrollUntilVisible(find.text('Reading photos with AI'), 300);
    expect(find.text('Not set up'), findsOneWidget);
    await openAiScreen(tester);

    expect(find.text('Not set up'), findsOneWidget);
    expect(
      find.textContaining('AI is connected in the server settings'),
      findsOneWidget,
    );
    expect(find.text('No key'), findsOneWidget);
    expect(find.textContaining('Free Gemini tier'), findsNothing);
  });

  testWidgets('the AI screen in Russian on a small phone', (tester) async {
    await open(tester, language: 'ru', size: const Size(360, 1600));
    await tester.scrollUntilVisible(find.text('Распознавание фото'), 300);
    await tapVisible(tester, find.text('Распознавание фото'));

    expect(find.text('Подключено'), findsOneWidget);
    expect(find.textContaining('Бесплатный тариф Gemini'), findsOneWidget);
    await tapVisible(tester, find.text('Проверить подключение'));
    expect(
      find.text('Работает: модель gemini-3.8-flash ответила за 1,2 с.'),
      findsOneWidget,
    );
  });
}
