// Writing a note for AI ("Write it in words", on the Health tab next to the
// scan button): offered only when the server has AI, and never to helpers.
// The note is checked here as the server checks it (some letter or digit,
// 1000 characters at most, counted as the counter counts them), sent with
// source Text and one request id per text (the same on a retry, or when the
// text comes back), waited for like a scan, and opened in the same review.
// The day's notes used up have their own words; typed text isn't lost
// without asking, and otherwise iOS's back swipe works; a note that failed
// is read again in its place.
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/scan_screen.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

const note = 'Yesterday the rabies shot, Nobivac; weighs 4.2 kg';

/// The day's notes are used up: a 429 of its own type.
const noteLimit = ApiException(
  ApiErrorKind.tooManyRequests,
  statusCode: 429,
  problem: ProblemDetails(type: ProblemTypes.textLimit, status: 429),
);

Finder noteField() => find.descendant(
  of: find.byKey(const ValueKey('note')),
  matching: find.byType(TextFormField),
);

FilledButton readButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Read'));

/// One check of the screen: the 2 seconds pass, the answer arrives.
Future<void> nextCheck(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
  await tester.pump();
}

/// A new note that is ready at the first check: a vaccination and a weight.
List<AiScan> readyNote(AiScan started) => [
  testNote(
    started.id,
    text: started.text!,
    status: ScanStatus.ready,
    draft: ScanDraft(
      records: [
        DraftRecord(
          key: 0,
          kind: CareKind.vaccination,
          title: 'Rabies vaccination',
          performedOn: DateTime(2025, 10, 6),
          evidence: 'the rabies shot',
        ),
      ],
      weights: [
        DraftWeight(
          key: 0,
          measuredOn: DateTime(2025, 10, 6),
          weightKg: 4.2,
          evidence: 'weighs 4.2 kg',
        ),
      ],
    ),
  ),
];

/// "Write it in words" and "Scan from passport" on the Health tab: cards
/// while the history is empty, as in these tests.
final noteEntry = find.byKey(const ValueKey('historyNote'));
final scanEntry = find.byKey(const ValueKey('historyScan'));

void main() {
  late FakeAiRepository ai;

  setUp(() => ai = FakeAiRepository(status: testAiStatus));

  Future<void> open(
    WidgetTester tester,
    String location, {
    FakeMeRepository? me,
    String language = 'en',
  }) => pumpApp(
    tester,
    location: location,
    me: me,
    language: language,
    overrides: fakeRepositories(pets: FakePetsRepository([murka]), ai: ai),
  );

  /// Types [text] as the note and taps "Read".
  Future<void> read(WidgetTester tester, String text) async {
    await tester.enterText(noteField(), text);
    await tapAndWait(tester, find.text('Read'));
  }

  testWidgets('offered next to the scan button; a note is written, sent '
      'with its text and waited for like a scan', (tester) async {
    ai.scriptForStart = readyNote;
    await open(tester, '/pets/p1?tab=health');

    expect(scanEntry, findsOneWidget);
    await tapVisible(tester, noteEntry);
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.text('Write it in words'), findsOneWidget, reason: 'title');
    expect(
      find.text(
        'Write what was done and when, in your own words: vaccinations, '
        'treatments, a visit to the vet, the weight. AI turns it into '
        'entries for you to check.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('e.g. Yesterday the rabies shot, Nobivac; weighs 4.2 kg'),
      findsOneWidget,
      reason: 'an example in the user\'s language',
    );
    expect(
      find.text('To dictate, tap the microphone on the keyboard.'),
      findsOneWidget,
    );
    expect(find.text('0/1000'), findsOneWidget);
    // As before a scan: a draft only, and where the words go.
    expect(
      find.text(
        'AI only prepares a draft: you check every entry and decide what '
        'to save.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Free Gemini tier: Google may use what is sent to improve its '
        "products, and human reviewers may read it. Don't write personal "
        'details such as phone numbers or addresses.',
      ),
      findsOneWidget,
      reason: "a note's words, not a scan's",
    );
    expect(ai.starts, isEmpty, reason: 'nothing is sent before "Read"');

    await tester.enterText(noteField(), note);
    await tester.pump();
    expect(find.text('${note.length}/1000'), findsOneWidget);
    await tapAndWait(tester, find.text('Read'));

    final start = ai.starts.single;
    expect(start.petId, 'p1');
    expect(start.source, ScanSource.note);
    expect(start.text, note);
    expect(start.fileIds, isEmpty, reason: 'a note has no photos');
    expect(find.text('Reading the note…'), findsOneWidget);
    expect(find.text('Usually 5–30 seconds.'), findsOneWidget);
    expect(
      find.text(
        'You can leave this screen: the note is read on the server and '
        'waits for you on the Health tab.',
      ),
      findsOneWidget,
    );
    expect(find.text('“$note”'), findsOneWidget, reason: 'the note quoted');

    await nextCheck(tester);
    expect(find.text('Check the note'), findsOneWidget);
    expect(find.text('Rabies vaccination'), findsOneWidget);
    expect(find.text('4.2 kg'), findsOneWidget);
  });

  testWidgets('without AI on the server, or for a helper, there is no note '
      'to write', (tester) async {
    ai.status = AiStatus.notConfigured;
    await open(tester, '/pets/p1?tab=health');
    expect(find.byType(HealthTab), findsOneWidget);
    expect(noteEntry, findsNothing);
    expect(find.text('Add past record'), findsOneWidget);

    ai.status = testAiStatus;
    await open(
      tester,
      '/pets/p1?tab=health',
      me: FakeMeRepository(
        households: [
          testHousehold(FakeMeRepository.homeId, role: HouseholdRole.helper),
        ],
      ),
    );
    expect(find.byType(HealthTab), findsOneWidget);
    expect(noteEntry, findsNothing);
    expect(scanEntry, findsNothing);
  });

  testWidgets('an empty note, or one over 1000 characters, is refused '
      'before anything is sent', (tester) async {
    await open(tester, '/pets/p1/note');

    await tapAndWait(tester, find.text('Read'));
    expect(find.text('Write what was done, in words.'), findsOneWidget);
    await tester.enterText(noteField(), '   \n  ');
    await tapAndWait(tester, find.text('Read'));
    expect(find.text('Write what was done, in words.'), findsOneWidget);

    // Pasted text keeps its end: the counter says it is too long.
    await tester.enterText(noteField(), 'a' * 1001);
    await tester.pump();
    expect(find.text('1001/1000'), findsOneWidget);
    await tapAndWait(tester, find.text('Read'));
    expect(find.text('Use 1000 characters or fewer'), findsOneWidget);
    expect(ai.starts, isEmpty);

    // 1000 is fine; like the server, the counter leaves out the spaces
    // around the note, and the note is sent trimmed.
    await tester.enterText(noteField(), ' ${'a' * 1000} ');
    await tester.pump();
    expect(find.text('1000/1000'), findsOneWidget);
    await tapAndWait(tester, find.text('Read'));
    expect(find.text('Use 1000 characters or fewer'), findsNothing);
    expect(ai.starts.single.text, 'a' * 1000);
  });

  testWidgets('a lost answer: "Read" again sends the same request id, and '
      'the note is read once', (tester) async {
    await open(tester, '/pets/p1/note');
    ai.loseNextStartResponse = true;

    await read(tester, note);
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(noteField()).controller!.text,
      note,
      reason: 'the note is still there',
    );

    await tapAndWait(tester, find.text('Read'));
    expect(ai.starts, hasLength(2));
    expect(ai.starts.map((s) => s.requestId).toSet(), hasLength(1));
    expect(ai.scans, hasLength(1), reason: 'one note on the server');
    expect(find.text('Reading the note…'), findsOneWidget);
  });

  testWidgets('a note changed after a failure is another note, with a '
      'request id of its own', (tester) async {
    await open(tester, '/pets/p1/note');
    ai.loseNextStartResponse = true;

    await read(tester, note);
    await read(tester, '$note, and dewormed');

    expect(ai.starts, hasLength(2));
    expect(ai.starts.first.text, note);
    expect(ai.starts.last.text, '$note, and dewormed');
    expect(ai.starts.last.requestId, isNot(ai.starts.first.requestId));
  });

  testWidgets("the day's notes used up: words of their own, and \"Read\" is "
      'off', (tester) async {
    ai.startError = noteLimit;
    await open(tester, '/pets/p1/note');

    await read(tester, note);

    expect(
      find.text(
        'AI has already read 30 notes in the last 24 hours. Try again '
        'tomorrow or add the record by hand.',
      ),
      findsOneWidget,
    );
    expect(readButton(tester).onPressed, isNull);
    expect(
      tester.widget<TextFormField>(noteField()).controller!.text,
      note,
      reason: 'the note stays, e.g. to copy',
    );
  });

  testWidgets("in Russian: the day's notes", (tester) async {
    ai.startError = noteLimit;
    await open(tester, '/pets/p1/note', language: 'ru');
    expect(find.text('Записать словами'), findsOneWidget);
    expect(
      find.text('Например: вчера прививка от бешенства, Нобивак; весит 4,2 кг'),
      findsOneWidget,
    );
    expect(
      find.text('Чтобы надиктовать, нажмите на микрофон на клавиатуре.'),
      findsOneWidget,
    );

    await tester.enterText(noteField(), 'Вчера прививка от бешенства');
    await tapAndWait(tester, find.text('Прочитать'));

    expect(
      find.text(
        'AI уже прочитал 30 заметок за сутки. Попробуйте завтра или '
        'добавьте запись вручную.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('AI turned off on the server (409): said, and "Read" is off', (
    tester,
  ) async {
    ai.startError = conflict;
    await open(tester, '/pets/p1/note');

    await read(tester, note);

    expect(
      find.text(
        "AI isn't set up on the server. Connect a model in the server "
        'configuration, then try again. Records can always be added by '
        'hand.',
      ),
      findsOneWidget,
    );
    expect(readButton(tester).onPressed, isNull);
  });

  testWidgets('too many AI requests in a minute (429 without a type): said '
      'as for a scan, and "Read" tries again', (tester) async {
    ai.startError = const ApiException(
      ApiErrorKind.tooManyRequests,
      statusCode: 429,
    );
    await open(tester, '/pets/p1/note');

    await read(tester, note);
    expect(
      find.text('Too many requests in a row. Try again in a minute.'),
      findsOneWidget,
    );

    ai.startError = null;
    await tapAndWait(tester, find.text('Read'));
    expect(ai.starts.single.text, note);
    expect(find.text('Reading the note…'), findsOneWidget);
  });

  testWidgets('the text refused by the server: said on the field until it '
      'changes', (tester) async {
    ai.startError = validationProblem({
      'text': ['Use 1000 characters or fewer.'],
    });
    await open(tester, '/pets/p1/note');

    await read(tester, note);
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
    expect(find.text("This value wasn't accepted. Check it."), findsOneWidget);

    await tester.enterText(noteField(), 'Rabies shot yesterday');
    // The error fades out.
    await tester.pumpAndSettle();
    expect(find.text("This value wasn't accepted. Check it."), findsNothing);
    ai.startError = null;
    await tapAndWait(tester, find.text('Read'));
    expect(ai.starts.single.text, 'Rabies shot yesterday');
  });

  testWidgets('typed text is not lost without asking; an empty note, or one '
      'sent, leaves at once', (tester) async {
    await open(tester, '/pets/p1?tab=health');

    // Nothing typed: Back just goes back.
    await tapVisible(tester, noteEntry);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);

    await tapVisible(tester, noteEntry);
    await tester.enterText(noteField(), note);
    // A frame passes between typing and Back, as on a phone.
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    expect(
      find.text('What you entered on this screen will be lost.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(noteField()).controller!.text, note);

    // The tab bar doesn't drop it quietly either.
    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);

    // Sent: the note waits on the server, and on the Health tab.
    await tapAndWait(tester, find.text('Read'));
    expect(find.text('Reading the note…'), findsOneWidget);
    await tapAndWait(tester, find.byTooltip('Back'));
    expect(find.text('Leave without saving?'), findsNothing);
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.textContaining('Note from'), findsOneWidget);
    expect(find.text('“$note”'), findsOneWidget);
  });

  testWidgets('a note that failed: why, the note, and "Try again" reads the '
      'same text as a new note', (tester) async {
    ai.scans['failed'] = testNote(
      'failed',
      status: ScanStatus.failed,
      error: ScanError.unexpected,
    );
    await open(tester, '/pets/p1/scans/failed');

    expect(find.text("Couldn't be read"), findsOneWidget);
    expect(
      find.text('Something went wrong while reading the note. Try again.'),
      findsOneWidget,
    );
    expect(find.text('“$note”'), findsOneWidget);
    expect(find.text('Scan again'), findsNothing, reason: 'no photos');

    ai.scriptForStart = readyNote;
    await tapAndWait(tester, find.text('Try again'));

    final start = ai.starts.single;
    expect((start.source, start.text), (ScanSource.note, note));
    expect(start.retryOf, 'failed', reason: 'it takes the failed one\'s place');
    expect(
      ai.scans['failed']!.status,
      ScanStatus.discarded,
      reason: 'the server drops the failed note read again',
    );
    expect(find.text('Reading the note…'), findsOneWidget);
    await nextCheck(tester);
    expect(find.text('Check the note'), findsOneWidget);
  });

  testWidgets('a failed note read again: when sending fails, the note is '
      'there to send again, with the same request id', (tester) async {
    ai
      ..scans['failed'] = testNote(
        'failed',
        status: ScanStatus.failed,
        error: ScanError.busy,
      )
      ..loseNextStartResponse = true;
    await open(tester, '/pets/p1/scans/failed?again=1');

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(tester.widget<TextFormField>(noteField()).controller!.text, note);
    await tapAndWait(tester, find.text('Read'));
    expect(ai.starts, hasLength(2));
    expect(ai.starts.map((s) => s.requestId).toSet(), hasLength(1));
    expect(ai.starts.map((s) => s.retryOf).toSet(), {'failed'});
    expect(find.text('Reading the note…'), findsOneWidget);
  });

  testWidgets('a failed note read again that could not be sent: unchanged, '
      'it leaves at once (the server has it); changed, it asks first', (
    tester,
  ) async {
    ai
      ..scans['failed'] = testNote(
        'failed',
        status: ScanStatus.failed,
        error: ScanError.busy,
      )
      ..startError = networkError;
    await open(tester, '/pets/p1/scans/failed?again=1');
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );

    await tester.enterText(noteField(), '$note, and dewormed');
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.enterText(noteField(), note);
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Leave without saving?'), findsNothing);
    expect(find.byType(ScanScreen), findsNothing);
  });

  testWidgets('a text sent before keeps its request id when it comes back '
      '(A, then B, then A again): the server reads A once', (tester) async {
    const changed = 'Yesterday the rabies shot, Nobivac; weighs 4.3 kg';
    await open(tester, '/pets/p1/note');

    // A goes through on the server; its answer is lost.
    ai.loseNextStartResponse = true;
    await read(tester, note);
    // B, still without a connection.
    ai.startError = networkError;
    await read(tester, changed);
    // Back to A, sent again.
    ai.startError = null;
    await read(tester, note);

    final idsOfA = {
      for (final start in ai.starts)
        if (start.text == note) start.requestId,
    };
    expect(idsOfA, hasLength(1));
    expect(
      [
        for (final scan in ai.scans.values)
          if (scan.text == note) scan.id,
      ],
      hasLength(1),
      reason: 'one note of this text on the server',
    );
    expect(find.text('Reading the note…'), findsOneWidget);
  });

  testWidgets('a note without a letter or a digit is caught before sending, '
      'with what to write', (tester) async {
    await open(tester, '/pets/p1/note');

    for (final text in ['?!… 😺😺', '​​​', '- - -']) {
      await read(tester, text);
      expect(
        find.text('Write what was done, in words.'),
        findsOneWidget,
        reason: text,
      );
      expect(find.text("This value wasn't accepted. Check it."), findsNothing);
    }
    expect(ai.starts, isEmpty, reason: 'checked here, as the server would');

    // A digit, or a letter of any alphabet, is something to read.
    await read(tester, '4,2 кг');
    expect(ai.starts.single.text, '4,2 кг');
  });

  testWidgets('the counter counts as the length check does: an emoji counts '
      '2, as on the server', (tester) async {
    await open(tester, '/pets/p1/note');

    await tester.enterText(noteField(), 'Weighs 4.2 ${'🐾' * 500}');
    await tester.pump();
    expect(find.text('1011/1000'), findsOneWidget);
    await tapAndWait(tester, find.text('Read'));
    expect(find.text('Use 1000 characters or fewer'), findsOneWidget);
    expect(ai.starts, isEmpty);

    await tester.enterText(noteField(), 'Weighs 4.2 ${'🐾' * 494}');
    await tester.pumpAndSettle();
    expect(find.text('999/1000'), findsOneWidget);
    expect(find.text('Use 1000 characters or fewer'), findsNothing);
    await tapAndWait(tester, find.text('Read'));
    expect(ai.starts, hasLength(1));
  });

  testWidgets("the day's notes used up: the limit the server gives", (
    tester,
  ) async {
    ai.startError = const ApiException(
      ApiErrorKind.tooManyRequests,
      statusCode: 429,
      problem: ProblemDetails(
        type: ProblemTypes.textLimit,
        status: 429,
        extensions: {'limit': 25},
      ),
    );
    await open(tester, '/pets/p1/note');

    await read(tester, note);

    expect(
      find.text(
        'AI has already read 25 notes in the last 24 hours. Try again '
        'tomorrow or add the record by hand.',
      ),
      findsOneWidget,
    );
  });

  group('iOS', () {
    Future<void> swipeBack(WidgetTester tester) async {
      final gesture = await tester.startGesture(const Offset(4, 400));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the back swipe leaves an empty note and a note sent, never a note '
      'typed and not sent',
      (tester) async {
        await open(tester, '/pets/p1?tab=health');
        await tapVisible(tester, noteEntry);

        await swipeBack(tester);
        expect(find.byType(ScanScreen), findsNothing, reason: 'nothing typed');

        await tapVisible(tester, noteEntry);
        await tester.enterText(noteField(), note);
        await tester.pump();
        await swipeBack(tester);
        expect(find.byType(ScanScreen), findsOneWidget, reason: 'typed');
        expect(
          tester.widget<TextFormField>(noteField()).controller!.text,
          note,
        );

        await tapAndWait(tester, find.text('Read'));
        expect(find.text('Reading the note…'), findsOneWidget);
        await swipeBack(tester);
        expect(find.byType(ScanScreen), findsNothing, reason: 'sent');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });
}
