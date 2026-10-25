// Where scans start and are picked up again: the Passport tab and the
// Health tab offer a scan only when the server has AI (typing records in
// always works), and the Passport tab shows scans that wait to be checked,
// are still being read, or failed ("Try again" or "Dismiss"). Whether the
// server has AI is asked again after that failed, when the user comes back.
import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/scan_screen.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

/// "Scan from passport" on the Health tab: a card while the history is
/// empty, as in these tests.
final scanEntry = find.byKey(const ValueKey('historyScan'));

void main() {
  late FakeAiRepository ai;

  setUp(() => ai = FakeAiRepository());

  Future<void> open(WidgetTester tester, String location) => pumpApp(
    tester,
    location: location,
    overrides: fakeRepositories(pets: FakePetsRepository([murka]), ai: ai),
  );

  testWidgets('without AI on the server there is nothing to scan with', (
    tester,
  ) async {
    await open(tester, '/pets/p1?tab=passport');
    expect(find.byType(PassportTab), findsOneWidget);
    expect(find.text('Scan passport pages'), findsNothing);
    expect(find.text('Scan pages'), findsNothing);

    await open(tester, '/pets/p1?tab=health');
    expect(find.byType(HealthTab), findsOneWidget);
    expect(scanEntry, findsNothing);
    // Adding by hand is always there.
    expect(find.text('Add past record'), findsOneWidget);
  });

  testWidgets('with AI the Passport and Health tabs open a scan', (
    tester,
  ) async {
    ai.status = testAiStatus;
    await open(tester, '/pets/p1?tab=passport');
    expect(find.text('Scan passport pages'), findsOneWidget);
    await tapVisible(tester, find.text('Scan pages'));
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.text('Scan with the camera'), findsOneWidget);

    await open(tester, '/pets/p1?tab=health');
    await tapVisible(tester, scanEntry);
    expect(find.byType(ScanScreen), findsOneWidget);
  });

  testWidgets('a scan ready to check, still read, or failed can be picked '
      'up from the Passport tab; saved ones are not offered', (tester) async {
    ai.scans.addAll({
      'done': testScan('done', status: ScanStatus.applied),
      'failed': testScan(
        'failed',
        status: ScanStatus.failed,
        error: ScanError.busy,
        pages: [testFile('page-a')],
      ),
      'reading': testScan('reading'),
      'ready': testScan(
        'ready',
        status: ScanStatus.ready,
        draft: const ScanDraft(),
      ),
    });
    await open(tester, '/pets/p1?tab=passport');

    // Offered even without AI now: checking and saving need no AI.
    expect(find.text('Ready to check'), findsOneWidget);
    expect(
      find.textContaining('Continue checking the scan from'),
      findsOneWidget,
    );
    expect(find.text('Reading the pages…'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
    // A scan that failed after the user left doesn't just disappear.
    expect(find.text("Couldn't be read"), findsOneWidget);
    expect(
      find.text(
        'The AI models are busy or out of free requests right now. Try '
        'again in a few minutes.',
      ),
      findsOneWidget,
    );

    await tapVisible(
      tester,
      find.textContaining('Continue checking the scan from'),
    );
    expect(find.text('Check the scan'), findsOneWidget);
    expect(
      find.text(
        'AI found nothing to save on these photos. You can keep the '
        'photos or discard the scan.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('"Try again" on a failed scan reads its photos as a new scan', (
    tester,
  ) async {
    ai
      ..status = testAiStatus
      ..scans['failed'] = testScan(
        'failed',
        status: ScanStatus.failed,
        error: ScanError.busy,
        pages: [testFile('page-a'), testFile('page-b')],
      );
    await open(tester, '/pets/p1?tab=passport');

    await tapAndWait(tester, find.text('Try again'));

    expect(find.byType(ScanScreen), findsOneWidget);
    final start = ai.starts.single;
    expect(start.fileIds, ['page-a', 'page-b'], reason: 'the same photos');
    expect(start.source, ScanSource.passportPages);
    expect(start.retryOf, 'failed', reason: 'it takes the failed one\'s place');
    expect(find.text('Reading the pages…'), findsOneWidget);

    // Back on the Passport tab: the new scan is being read; the failed one
    // is gone (the server drops it once its photos are read again).
    await tapAndWait(tester, find.byTooltip('Back'));
    expect(find.byType(PassportTab), findsOneWidget);
    expect(find.text("Couldn't be read"), findsNothing);
    expect(find.text('Waiting to be read'), findsOneWidget);
  });

  testWidgets('"Try again" twice makes two scans, each with its own request '
      'id', (tester) async {
    ai
      ..status = testAiStatus
      ..scans['failed'] = testScan(
        'failed',
        status: ScanStatus.failed,
        error: ScanError.unexpected,
        pages: [testFile('page-a')],
      )
      ..scriptForStart = (started) => [
        testScan(
          started.id,
          status: ScanStatus.failed,
          error: ScanError.unexpected,
          pages: started.pages,
        ),
      ];
    await open(tester, '/pets/p1?tab=passport');
    await tapAndWait(tester, find.text('Try again'));
    await tester.pump(const Duration(seconds: 2));
    await pumpFrames(tester);
    expect(find.text("Couldn't be read"), findsOneWidget, reason: 'again');
    await tapAndWait(tester, find.text('Try again'));

    expect(ai.starts, hasLength(2));
    expect(ai.starts.map((s) => s.requestId).toSet(), hasLength(2));
  });

  testWidgets('"Dismiss" throws a failed scan away; one whose photos are gone '
      'offers to scan again', (tester) async {
    ai
      ..status = testAiStatus
      ..scans.addAll({
        'old': testScan(
          'old',
          status: ScanStatus.failed,
          error: ScanError.photosMissing,
          pages: const [],
        ),
      });
    await open(tester, '/pets/p1?tab=passport');

    expect(
      find.text('The photos of this scan are gone. Scan the pages again.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Scan again'), findsOneWidget);

    await tapVisible(tester, find.text('Dismiss'));
    expect(ai.discarded, ['old']);
    expect(find.text("Couldn't be read"), findsNothing);
    expect(find.text('Scan passport pages'), findsOneWidget);
  });

  testWidgets('AI status that failed to load is asked again when the app '
      'comes back', (tester) async {
    ai
      ..status = testAiStatus
      ..statusError = networkError;
    await open(tester, '/pets/p1?tab=health');
    expect(scanEntry, findsNothing);
    final calls = ai.statusCalls;

    ai.statusError = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(ai.statusCalls, greaterThan(calls));
    expect(scanEntry, findsOneWidget);
  });

  testWidgets('AI status that failed to load is asked again when another '
      'tab is shown', (tester) async {
    ai
      ..status = testAiStatus
      ..statusError = networkError;
    await open(tester, '/pets/p1?tab=health');
    expect(scanEntry, findsNothing);

    ai.statusError = null;
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();
    expect(find.text('Scan passport pages'), findsOneWidget);
  });
}
