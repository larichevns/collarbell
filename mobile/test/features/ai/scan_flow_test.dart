// Starting a scan and waiting for it: the pages come from the scanner (or
// the photo library when there is none), are shrunk, upload once and are
// deleted from the phone, and the scan starts once per request id; the
// screen asks every 2 seconds until the draft is ready, and not while the
// app is in the background. Failures say what happened, and "Try again"
// reads the same photos as a new scan.
import 'dart:async';

import 'package:collarbell/features/ai/ai.dart';
import 'package:collarbell/features/ai/scan_screen.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/passport/passport_tab.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:flutter/material.dart'
    show
        AppLifecycleState,
        Offset,
        ScaffoldMessenger,
        ScaffoldMessengerState,
        TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

const pages = [
  PickedMedia(path: '/tmp/page-1.jpg', name: 'page-1.jpg'),
  PickedMedia(path: '/tmp/page-2.jpg', name: 'page-2.jpg'),
];

/// One check of the screen: the 2 seconds pass, the answer arrives.
Future<void> nextCheck(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
  await tester.pump();
}

void main() {
  late FakeAiRepository ai;
  late FakeFilesRepository files;
  late FakeMediaPicker picker;

  setUp(() {
    ai = FakeAiRepository(status: testAiStatus);
    files = FakeFilesRepository();
    picker = FakeMediaPicker()..scanned = pages;
  });

  Future<void> open(WidgetTester tester, String location) => pumpApp(
    tester,
    location: location,
    overrides: fakeRepositories(
      pets: FakePetsRepository([murka]),
      files: files,
      picker: picker,
      ai: ai,
    ),
  );

  /// The scan as the server has it after reading: a draft with one record.
  AiScan readyScan(AiScan started) => testScan(
    started.id,
    status: ScanStatus.ready,
    pages: started.pages,
    draft: ScanDraft(
      records: [
        DraftRecord(
          key: 0,
          kind: CareKind.vaccination,
          title: 'Rabies vaccination',
          performedOn: DateTime(2025, 3, 12),
        ),
      ],
    ),
  );

  testWidgets('scanned pages upload, the scan starts, and the draft opens '
      'once AI has read it', (tester) async {
    ai.scriptForStart = (started) => [
      testScan(started.id, pages: started.pages),
      readyScan(started),
    ];
    await open(tester, '/pets/p1/scan');
    expect(find.text('Scan passport pages'), findsOneWidget);
    expect(
      find.text(
        'Free Gemini tier: Google may use what is sent to improve its '
        'products, and human reviewers may read it. Scan only your own '
        'documents.',
      ),
      findsOneWidget,
    );

    await tapAndWait(tester, find.text('Scan with the camera'));

    // One page more than a scan takes: the scanner on iPhone drops pages
    // past its limit without a word.
    expect(picker.scanLimits, [11]);
    expect(picker.prepared.single, pages, reason: 'shrunk before upload');
    expect(files.uploads, pages);
    // On the server now: the copies on the phone go.
    expect(picker.deleted, [for (final page in pages) page.path]);
    final start = ai.starts.single;
    expect(start.petId, 'p1');
    expect(start.source, ScanSource.passportPages);
    expect(start.fileIds, ['upload-1', 'upload-2']);
    expect(find.text('Reading the pages…'), findsOneWidget);
    expect(find.text('Usually 10–60 seconds.'), findsOneWidget);

    // Still reading after 2 seconds, ready after 4.
    await nextCheck(tester);
    expect(find.text('Reading the pages…'), findsOneWidget);
    await nextCheck(tester);
    expect(find.text('Check the scan'), findsOneWidget);
    expect(find.text('Rabies vaccination'), findsOneWidget);
    expect(ai.getCalls, 2);
  });

  testWidgets('leaving while AI reads is allowed: the Passport tab offers to '
      'pick the scan up again', (tester) async {
    await open(tester, '/pets/p1?tab=passport');
    await tapVisible(tester, find.text('Scan pages'));
    await tapAndWait(tester, find.text('Scan with the camera'));
    expect(find.text('Reading the pages…'), findsOneWidget);

    await tapAndWait(tester, find.byTooltip('Back'));

    expect(find.byType(ScanScreen), findsNothing);
    expect(find.byType(PassportTab), findsOneWidget);
    expect(find.text('Waiting to be read'), findsOneWidget);
    // The card opens the same scan, still reading.
    await tapAndWait(tester, find.textContaining('Scan from'));
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(ai.starts, hasLength(1), reason: 'not started again');
  });

  testWidgets('a lost answer when starting: the retry sends the same request '
      'id and uploads nothing again', (tester) async {
    await open(tester, '/pets/p1/scan');
    ai.loseNextStartResponse = true;

    await tapAndWait(tester, find.text('Scan with the camera'));
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );

    await tapAndWait(tester, find.text('Try again'));

    expect(ai.starts, hasLength(2));
    expect(ai.starts.map((s) => s.requestId).toSet(), hasLength(1));
    expect(ai.scans, hasLength(1), reason: 'one scan on the server');
    expect(files.uploads, hasLength(2), reason: 'uploaded once');
    expect(find.text('Reading the pages…'), findsOneWidget);
  });

  testWidgets('an upload that fails is retried; pages that uploaded are '
      'reused', (tester) async {
    await open(tester, '/pets/p1/scan');
    files.error = networkError;

    await tapAndWait(tester, find.text('Scan with the camera'));
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(ai.starts, isEmpty);

    files.error = null;
    await tapAndWait(tester, find.text('Try again'));

    expect(files.uploads, pages);
    expect(ai.starts.single.fileIds, ['upload-1', 'upload-2']);
  });

  testWidgets('models busy: "Try again" reads the same photos as a new '
      'scan', (tester) async {
    ai.scriptForStart = (started) => [
      testScan(
        started.id,
        status: ScanStatus.failed,
        error: ScanError.busy,
        pages: started.pages,
      ),
    ];
    await open(tester, '/pets/p1/scan');
    await tapAndWait(tester, find.text('Scan with the camera'));
    await nextCheck(tester);

    expect(find.text("Couldn't be read"), findsOneWidget);
    expect(
      find.text(
        'The AI models are busy or out of free requests right now. Try '
        'again in a few minutes.',
      ),
      findsOneWidget,
    );

    ai.scriptForStart = readyScanScript;
    await tapAndWait(tester, find.text('Try again'));

    expect(ai.starts, hasLength(2));
    expect(ai.starts.last.fileIds, ai.starts.first.fileIds);
    expect(
      ai.starts.last.requestId,
      isNot(ai.starts.first.requestId),
      reason: 'a new scan',
    );
    expect(
      ai.starts.last.retryOf,
      'scan-new-1',
      reason: 'in place of the failed one',
    );
    expect(ai.starts.first.retryOf, isNull);
    expect(files.uploads, hasLength(2), reason: 'the photos are on the server');
    await nextCheck(tester);
    expect(find.text('Check the scan'), findsOneWidget);
  });

  testWidgets('photos gone: only scanning again helps', (tester) async {
    ai.scans['old'] = testScan(
      'old',
      status: ScanStatus.failed,
      error: ScanError.photosMissing,
      pages: const [],
    );
    await open(tester, '/pets/p1/scans/old');

    expect(
      find.text('The photos of this scan are gone. Scan the pages again.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);

    await tester.tap(find.text('Scan again'));
    await tester.pumpAndSettle();
    expect(find.text('Scan with the camera'), findsOneWidget);
  });

  testWidgets('AI not set up, or the key refused: explained; "Try again" '
      'works once the server is fixed', (tester) async {
    ai.scans['off'] = testScan(
      'off',
      status: ScanStatus.failed,
      error: ScanError.notConfigured,
      pages: [testFile('page-a')],
    );
    ai.scans['key'] = testScan(
      'key',
      status: ScanStatus.failed,
      error: ScanError.rejected,
      pages: [testFile('page-b')],
    );
    await open(tester, '/pets/p1/scans/off');
    expect(
      find.text(
        "AI isn't set up on the server. Connect a model in the server "
        'configuration, then scan again. Records can always be added by '
        'hand.',
      ),
      findsOneWidget,
    );
    // Still off: the server refuses the start, and says so.
    ai.startError = conflict;
    await tapAndWait(tester, find.text('Try again'));
    expect(
      find.textContaining("AI isn't set up on the server."),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Scan again'), findsOneWidget);

    // The key was fixed meanwhile: reading again works.
    ai.startError = null;
    await open(tester, '/pets/p1/scans/key');
    expect(
      find.text(
        'The AI service refused the request. The API key on the server may '
        'be wrong or expired.',
      ),
      findsOneWidget,
    );
    await tapAndWait(tester, find.text('Try again'));
    expect(ai.starts.single.fileIds, ['page-b']);
    expect(find.text('Reading the pages…'), findsOneWidget);
    expect(
      ai.scans['key']!.status,
      ScanStatus.discarded,
      reason: 'the server drops the failed scan read again',
    );
  });

  testWidgets('AI turned off before the start (409): said, and the start '
      'stays off', (tester) async {
    ai.startError = conflict;
    await open(tester, '/pets/p1/scan');

    await tapAndWait(tester, find.text('Scan with the camera'));

    expect(
      find.textContaining("AI isn't set up on the server."),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Scan again'), findsOneWidget);
  });

  testWidgets('without a scanner (a simulator) the photo library takes its '
      'place; cancelling just returns', (tester) async {
    picker
      ..scannerUnavailable = true
      ..library = [];
    await open(tester, '/pets/p1/scan');

    await tapAndWait(tester, find.text('Scan with the camera'));
    expect(
      find.text(
        "The scanner isn't available on this device. Choose photos of the "
        'pages instead.',
      ),
      findsOneWidget,
    );
    expect(picker.photoLimits, [10]);
    // Nothing picked: still choosing, nothing uploaded.
    expect(find.text('Scan with the camera'), findsOneWidget);
    expect(files.uploads, isEmpty);

    picker
      ..scannerUnavailable = false
      ..scanned = null;
    // The note goes, so the button can be reached.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pumpAndSettle();
    await tapAndWait(tester, find.text('Scan with the camera'));
    expect(picker.scanLimits, hasLength(2), reason: 'the scanner opened');
    expect(find.text('Scan with the camera'), findsOneWidget);
    expect(ai.starts, isEmpty);
  });

  testWidgets('a second tap while the scanner is open starts nothing more', (
    tester,
  ) async {
    picker.scanGate = Completer<void>();
    await open(tester, '/pets/p1/scan');

    await tester.tap(find.text('Scan with the camera'));
    await tester.pump();
    await tester.tap(find.text('Scan with the camera'));
    await tester.pump();
    await tester.tap(find.text('Choose from photos'));
    await tester.pump();
    picker.scanGate!.complete();
    await pumpFrames(tester);

    expect(picker.scanLimits, hasLength(1));
    expect(picker.photoLimits, isEmpty);
    expect(ai.starts, hasLength(1));
  });

  testWidgets('more scanned pages than a scan takes: the first ten are '
      'used, the rest deleted', (tester) async {
    final scanned = [
      for (var i = 1; i <= 11; i++)
        PickedMedia(path: '/tmp/s$i.jpg', name: 's$i.jpg'),
    ];
    picker.scanned = scanned;
    await open(tester, '/pets/p1/scan');

    await tapAndWait(tester, find.text('Scan with the camera'));

    expect(find.text('Only the first 10 pages are used.'), findsOneWidget);
    expect(files.uploads, scanned.take(10));
    expect(ai.starts.single.fileIds, hasLength(10));
    expect(
      picker.deleted,
      unorderedEquals([for (final page in scanned) page.path]),
    );
  });

  testWidgets('pages that never became a scan are deleted from the phone', (
    tester,
  ) async {
    files.error = networkError;
    await open(tester, '/pets/p1/scan');
    await tapAndWait(tester, find.text('Scan with the camera'));
    expect(find.text('Try again'), findsOneWidget);
    expect(picker.deleted, isEmpty, reason: 'kept for "Try again"');

    // Starting over drops them.
    await tapAndWait(tester, find.text('Scan again'));
    expect(picker.deleted, [for (final page in pages) page.path]);

    // So does leaving.
    picker.deleted.clear();
    await tapAndWait(tester, find.text('Scan with the camera'));
    await tapAndWait(tester, find.byTooltip('Back'));
    expect(find.byType(ScanScreen), findsNothing);
    expect(picker.deleted, [for (final page in pages) page.path]);
  });

  testWidgets('scanned pages are made ready before anything else can start', (
    tester,
  ) async {
    picker.prepareGate = Completer<void>();
    await open(tester, '/pets/p1/scan');

    await tester.tap(find.text('Scan with the camera'));
    await tester.pump();
    // Shrinking: the buttons wait.
    await tester.tap(find.text('Choose from photos'));
    await tester.pump();
    expect(picker.photoLimits, isEmpty);
    expect(files.uploads, isEmpty);

    picker.prepareGate!.complete();
    await pumpFrames(tester);
    expect(ai.starts, hasLength(1));
  });

  testWidgets('a scanner that never answers: back in the app, the buttons '
      'work again', (tester) async {
    picker.scanGate = Completer<void>();
    await open(tester, '/pets/p1/scan');

    await tester.tap(find.text('Scan with the camera'));
    await tester.pump();
    expect(picker.scanLimits, hasLength(1));

    // The scanner goes, its answer lost; the app is back in front.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 3));

    picker.scanGate = null;
    await tapAndWait(tester, find.text('Scan with the camera'));
    expect(picker.scanLimits, hasLength(2));
    expect(ai.starts, hasLength(1));
  });

  testWidgets('no asking while the app is in the background; back in front, '
      'it asks at once', (tester) async {
    ai.scriptForStart = (started) => [
      testScan(started.id, pages: started.pages),
      readyScan(started),
    ];
    await open(tester, '/pets/p1/scan');
    await tapAndWait(tester, find.text('Scan with the camera'));
    expect(find.text('Reading the pages…'), findsOneWidget);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(const Duration(seconds: 10));
    expect(ai.getCalls, 0);

    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    await tester.pump();
    expect(ai.getCalls, 1, reason: 'asked at once');
    expect(find.text('Reading the pages…'), findsOneWidget);
    await nextCheck(tester);
    expect(ai.getCalls, 2);
    expect(find.text('Check the scan'), findsOneWidget);
  });

  testWidgets('more photos than a scan takes: the first ten are used', (
    tester,
  ) async {
    picker.library = [
      for (var i = 1; i <= 12; i++)
        PickedMedia(path: '/tmp/p$i.jpg', name: 'p$i.jpg'),
    ];
    await open(tester, '/pets/p1/scan');

    await tapAndWait(tester, find.text('Choose from photos'));

    expect(find.text('Only the first 10 pages are used.'), findsOneWidget);
    expect(files.uploads, hasLength(10));
    expect(ai.starts.single.fileIds, hasLength(10));
  });

  testWidgets('a vet document is scanned as one', (tester) async {
    await open(tester, '/pets/p1/scan');

    await tester.tap(find.text('Vet document'));
    await tester.pumpAndSettle();
    expect(find.text('Scan a vet document'), findsOneWidget);
    await tapAndWait(tester, find.text('Scan with the camera'));

    expect(ai.starts.single.source, ScanSource.vetDocument);
  });

  testWidgets('no connection for a moment while waiting: said, and asked '
      'again', (tester) async {
    ai.scriptForStart = readyScanScript;
    await open(tester, '/pets/p1/scan');
    await tapAndWait(tester, find.text('Scan with the camera'));

    ai.getError = networkError;
    await nextCheck(tester);
    expect(find.text("Can't reach the server. Trying again…"), findsOneWidget);

    ai.getError = null;
    await nextCheck(tester);
    expect(find.text('Check the scan'), findsOneWidget);
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
      'the back swipe leaves a photo scan as before: choosing the pages, '
      'or done',
      (tester) async {
        ai.scans['s1'] = testScan(
          's1',
          status: ScanStatus.applied,
          result: const ScanResult(recordIds: ['r1']),
        );
        await open(tester, '/pets/p1?tab=passport');

        appRouter(tester).push('/pets/p1/scan');
        await tester.pumpAndSettle();
        expect(find.byType(ScanScreen), findsOneWidget);
        await swipeBack(tester);
        expect(find.byType(ScanScreen), findsNothing, reason: 'choosing');

        appRouter(tester).push('/pets/p1/scans/s1');
        await tester.pumpAndSettle();
        expect(find.text('Saved'), findsOneWidget);
        await swipeBack(tester);
        expect(find.byType(ScanScreen), findsNothing, reason: 'saved');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });
}

/// A new scan that is ready at the first check.
List<AiScan> readyScanScript(AiScan started) => [
  testScan(
    started.id,
    status: ScanStatus.ready,
    pages: started.pages,
    draft: ScanDraft(
      records: [
        DraftRecord(
          key: 0,
          kind: CareKind.deworming,
          title: 'Deworming',
          performedOn: DateTime(2025, 1, 5),
        ),
      ],
    ),
  ),
];
