// Where notes wait: on the Health tab, where they are written, not among
// the Passport tab's scans (and scans not on the Health tab), each kind
// listed apart so many of one never hide the other. A note being read,
// ready to check, or failed has a card there; a failed one can be read
// again ("Try again": the same text, as a new note in its place, whoever
// wrote it) or thrown away after asking. A note opens as a note. Helpers,
// who don't import, see none.
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/scan_screen.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/household/household.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

void main() {
  late FakeAiRepository ai;

  setUp(() => ai = FakeAiRepository(status: testAiStatus));

  Future<void> open(
    WidgetTester tester,
    String location, {
    FakeMeRepository? me,
  }) => pumpApp(
    tester,
    location: location,
    me: me,
    overrides: fakeRepositories(pets: FakePetsRepository([murka]), ai: ai),
  );

  testWidgets('notes wait on the Health tab, scans on the Passport tab', (
    tester,
  ) async {
    ai.scans.addAll({
      'reading': testNote('reading', text: 'Dewormed today, Milbemax'),
      'ready': testNote(
        'ready',
        text: 'Weighs 4.2',
        status: ScanStatus.ready,
        draft: const ScanDraft(),
      ),
      'failed': testNote(
        'failed',
        text: 'Rabies shot yesterday',
        status: ScanStatus.failed,
        error: ScanError.busy,
      ),
      'saved': testNote('saved', status: ScanStatus.applied),
      'scan': testScan('scan', status: ScanStatus.ready, draft: ScanDraft()),
    });
    await open(tester, '/pets/p1?tab=health');

    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.text('Reading the note…'), findsOneWidget);
    expect(find.text('“Dewormed today, Milbemax”'), findsOneWidget);
    expect(find.text('Ready to check'), findsOneWidget);
    expect(
      find.textContaining('Continue checking the note from'),
      findsOneWidget,
    );
    expect(find.text('“Weighs 4.2”'), findsOneWidget);
    expect(find.text("Couldn't be read"), findsOneWidget);
    expect(find.text('“Rabies shot yesterday”'), findsOneWidget);
    expect(
      find.text(
        'The AI models are busy or out of free requests right now. Try '
        'again in a few minutes.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Note from'), findsNWidgets(2));
    expect(find.text('Saved'), findsNothing);
    expect(find.textContaining('scan from'), findsNothing, reason: 'a scan');

    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    expect(find.byType(PassportTab), findsOneWidget);
    expect(
      find.textContaining('Continue checking the scan from'),
      findsOneWidget,
    );
    expect(find.textContaining('note from'), findsNothing);
    expect(find.textContaining('Note from'), findsNothing);
    expect(find.text("Couldn't be read"), findsNothing);
  });

  testWidgets('a note ready to check opens its review', (tester) async {
    ai.scans['ready'] = testNote(
      'ready',
      status: ScanStatus.ready,
      draft: const ScanDraft(),
    );
    await open(tester, '/pets/p1?tab=health');

    await tapVisible(
      tester,
      find.textContaining('Continue checking the note from'),
    );

    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.text('Check the note'), findsOneWidget);
    expect(
      find.text(
        'AI found nothing to save in this note. Discard it, or write it '
        'again in other words.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('"Try again" on a failed note reads the same text as a new '
      'note; the failed one goes', (tester) async {
    ai.scans['failed'] = testNote(
      'failed',
      text: 'Rabies shot yesterday',
      status: ScanStatus.failed,
      error: ScanError.busy,
    );
    await open(tester, '/pets/p1?tab=health');

    // In sight at the top of the tab: tapped where it is, so the list stays
    // at its top, where the new note will wait.
    await tester.tap(find.text('Try again'));
    await pumpFrames(tester);

    expect(find.byType(ScanScreen), findsOneWidget);
    final start = ai.starts.single;
    expect(start.source, ScanSource.note);
    expect(start.text, 'Rabies shot yesterday');
    expect(start.fileIds, isEmpty);
    expect(start.retryOf, 'failed', reason: 'it takes the failed one\'s place');
    expect(find.text('Reading the note…'), findsOneWidget);

    // Back on the Health tab: the new note waits to be read; the failed one
    // is gone (the server drops the note read again).
    await tapAndWait(tester, find.byTooltip('Back'));
    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.text("Couldn't be read"), findsNothing);
    expect(find.text('Waiting to be read'), findsOneWidget);
    expect(find.text('“Rabies shot yesterday”'), findsOneWidget);
  });

  testWidgets('"Try again" on a failed note another member wrote: it goes '
      'too, so it is not read a third time; the new note keeps its day', (
    tester,
  ) async {
    final written = DateTime.utc(2026, 10, 1, 21, 10);
    ai
      ..scans['theirs'] = testNote(
        'theirs',
        text: 'Rabies shot yesterday',
        status: ScanStatus.failed,
        error: ScanError.busy,
        createdAt: written,
      )
      ..othersNotes.add('theirs');
    await open(tester, '/pets/p1?tab=health');

    await tapAndWait(tester, find.text('Try again'));
    expect(ai.starts.single.retryOf, 'theirs');
    await tapAndWait(tester, find.byTooltip('Back'));

    expect(find.byType(HealthTab), findsOneWidget);
    expect(
      find.text("Couldn't be read"),
      findsNothing,
      reason: 'no "Try again" left to read the same note again',
    );
    final reading = [
      for (final scan in ai.scans.values)
        if (scan.text == 'Rabies shot yesterday' && scan.status.isReading) scan,
    ];
    expect(reading, hasLength(1));
    expect(
      reading.single.createdAt,
      written,
      reason: 'its "yesterday" is the day before it was written',
    );
  });

  testWidgets('"Dismiss" asks before it throws a note away with its text', (
    tester,
  ) async {
    ai.scans['failed'] = testNote(
      'failed',
      status: ScanStatus.failed,
      error: ScanError.unexpected,
    );
    await open(tester, '/pets/p1?tab=health');
    expect(
      find.text('Something went wrong while reading the note. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Scan again'), findsNothing, reason: 'no photos');

    await tapVisible(tester, find.text('Dismiss'));
    expect(find.text('Discard this note?'), findsOneWidget);
    expect(
      find.text('Nothing from it is saved, and its text is deleted.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(ai.discarded, isEmpty);
    expect(find.text("Couldn't be read"), findsOneWidget);

    await tapVisible(tester, find.text('Dismiss'));
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(ai.discarded, ['failed']);
    expect(find.text("Couldn't be read"), findsNothing);
    expect(find.textContaining('Note from'), findsNothing);
  });

  testWidgets('scans and notes are listed apart: a scan ready to check keeps '
      'its card however many notes wait, and the other way round', (
    tester,
  ) async {
    ai.scans['scan'] = testScan(
      'scan',
      status: ScanStatus.ready,
      draft: const ScanDraft(),
      createdAt: DateTime.utc(2026, 10, 1, 9),
    );
    ai.scans['note'] = testNote(
      'note',
      status: ScanStatus.ready,
      draft: const ScanDraft(),
      createdAt: DateTime.utc(2026, 10, 1, 9),
    );
    // 19 newer of each kind: with the ready ones, 20 notes and 20 scans,
    // which the server lists apart; listed together, the newest 20 would
    // leave both ready ones out.
    for (var i = 1; i < 20; i++) {
      ai.scans['note-$i'] = testNote(
        'note-$i',
        text: 'Note $i',
        status: ScanStatus.failed,
        createdAt: DateTime.utc(2026, 10, 2, 9, i),
      );
      ai.scans['scan-$i'] = testScan(
        'scan-$i',
        status: ScanStatus.failed,
        createdAt: DateTime.utc(2026, 10, 2, 9, i),
      );
    }

    await open(tester, '/pets/p1?tab=passport');
    expect(find.byType(PassportTab), findsOneWidget);
    expect(
      find.textContaining('Continue checking the scan from'),
      findsOneWidget,
    );
    await open(tester, '/pets/p1?tab=health');
    expect(find.byType(HealthTab), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Continue checking the note from'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(HealthTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.textContaining('Continue checking the note from'),
      findsOneWidget,
    );
    // Each tab asked for its own kind.
    expect(ai.listedNotes, containsAll([true, false]));
    expect(ai.listedNotes, isNot(contains(null)));
  });

  testWidgets('a note opened from its card speaks of a note while it loads, '
      'and when it can\'t load', (tester) async {
    ai.scans['ready'] = testNote(
      'ready',
      status: ScanStatus.ready,
      draft: const ScanDraft(),
    );
    await open(tester, '/pets/p1?tab=health');

    ai.getError = networkError;
    await tapVisible(
      tester,
      find.textContaining('Continue checking the note from'),
    );
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Write it in words'),
      ),
      findsOneWidget,
    );
    expect(find.text('Scan passport pages'), findsNothing);

    // Gone meanwhile (its pet deleted on another phone): a note that is.
    ai
      ..getError = null
      ..scans.remove('ready');
    await tapVisible(tester, find.text('Try again'));
    expect(find.text('This note no longer exists.'), findsOneWidget);
  });

  testWidgets('a helper sees no notes to pick up', (tester) async {
    ai.scans['ready'] = testNote(
      'ready',
      status: ScanStatus.ready,
      draft: const ScanDraft(),
    );
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
    expect(find.text('Ready to check'), findsNothing);
  });

  testWidgets("pulling the Health tab down asks again for the pet's notes", (
    tester,
  ) async {
    await open(tester, '/pets/p1?tab=health');
    expect(find.text('Ready to check'), findsNothing);

    // Written on another phone meanwhile.
    ai.scans['ready'] = testNote(
      'ready',
      status: ScanStatus.ready,
      draft: const ScanDraft(),
    );
    await tester.fling(find.byType(HealthTab), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Ready to check'), findsOneWidget);
  });
}
