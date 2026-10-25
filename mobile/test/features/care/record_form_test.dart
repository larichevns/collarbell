// Adding records by hand (history from the paper passport) and editing
// them: the fields of each kind, vaccine targets of the pet's species,
// photos added and removed one by one, retries that add nothing twice, and
// values the form keeps even when their field doesn't belong to the kind.
import 'package:collarbell/data/api/api_exception.dart';
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/care/widgets/kind_dropdown.dart';
import 'package:collarbell/features/care/widgets/record_row.dart';
import 'package:collarbell/features/files/stored_file.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/shared/widgets/cb_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);
const rex = Pet(id: 'p2', name: 'Rex', species: PetSpecies.dog);

Finder field(String label) => find.descendant(
  of: find.widgetWithText(CbTextField, label),
  matching: find.byType(TextFormField),
);

String textOf(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(field(label)).controller!.text;

void main() {
  late FakeCareRepository care;
  late FakeFilesRepository files;
  late FakeMediaPicker picker;

  setUp(() {
    care = FakeCareRepository();
    files = FakeFilesRepository();
    picker = FakeMediaPicker()
      ..library = const [
        PickedMedia(path: '/tmp/a.jpg', name: 'a.jpg'),
        PickedMedia(path: '/tmp/b.jpg', name: 'b.jpg'),
      ];
  });

  Future<void> open(WidgetTester tester, String location) => pumpApp(
    tester,
    location: location,
    overrides: fakeRepositories(
      pets: FakePetsRepository([murka, rex]),
      care: care,
      files: files,
      picker: picker,
    ),
  );

  Future<void> chooseKind(WidgetTester tester, String kind) async {
    await tapVisible(tester, find.byType(KindDropdown));
    await tester.tap(find.text(kind).last);
    await tester.pumpAndSettle();
  }

  Future<void> addPhotosFromLibrary(WidgetTester tester) async {
    await tapVisible(tester, find.text('Add photos'));
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
  }

  testWidgets('the fields follow the kind; a new title follows it too', (
    tester,
  ) async {
    await open(tester, '/pets/p1/records/new');

    expect(find.text('New record'), findsOneWidget);
    expect(textOf(tester, 'Title'), 'Vaccination');
    for (final label in [
      'Protects against',
      'Product',
      'Batch number',
      'Valid from',
      'Valid until',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final label in ['Laboratory', 'Weight, kg', 'Time']) {
      expect(find.text(label), findsNothing, reason: label);
    }

    await chooseKind(tester, 'Rabies antibody test');
    expect(textOf(tester, 'Title'), 'Rabies antibody test');
    for (final label in ['Laboratory', 'Report number', 'Result, IU/ml']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final label in ['Protects against', 'Product', 'Valid until']) {
      expect(find.text(label), findsNothing, reason: label);
    }

    await chooseKind(tester, 'Echinococcus treatment');
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Product'), findsOneWidget);

    await chooseKind(tester, 'Check-up');
    expect(find.text('Weight, kg'), findsOneWidget);
    expect(find.text('Fit to travel'), findsOneWidget);
    expect(find.text('Product'), findsNothing);

    // A title the user typed stays.
    await tester.enterText(field('Title'), 'Annual check');
    await chooseKind(tester, 'Dental care');
    expect(textOf(tester, 'Title'), 'Annual check');
  });

  testWidgets('vaccine targets are those of the pet species', (tester) async {
    await open(tester, '/pets/p1/records/new');
    expect(
      find.widgetWithText(FilterChip, 'Panleukopenia (FPV)'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilterChip, 'Distemper (CDV)'), findsNothing);

    await open(tester, '/pets/p2/records/new');
    expect(find.widgetWithText(FilterChip, 'Distemper (CDV)'), findsOneWidget);
    expect(
      find.widgetWithText(FilterChip, 'Panleukopenia (FPV)'),
      findsNothing,
    );
    expect(find.widgetWithText(FilterChip, 'Rabies'), findsOneWidget);
  });

  testWidgets('a past rabies vaccination with photos: the record first, then '
      'one request per photo', (tester) async {
    // As the passport's rabies section opens it.
    await open(tester, '/pets/p1/records/new?kind=vaccination&target=rabies');

    expect(textOf(tester, 'Title'), 'Rabies');
    final rabies = find.widgetWithText(FilterChip, 'Rabies');
    expect(tester.widget<FilterChip>(rabies).selected, isTrue);
    await tester.enterText(field('Product'), 'Nobivac Rabies');
    await tester.enterText(field('Batch number'), 'A123');
    await addPhotosFromLibrary(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final (petId, input) = care.createdRecords.single;
    expect(petId, 'p1');
    expect(input.kind, CareKind.vaccination);
    expect(input.title, 'Rabies');
    expect(input.targets, [VaccineTarget.rabies]);
    expect(input.product, 'Nobivac Rabies');
    expect(input.batchNumber, 'A123');
    expect(input.performedOn, testToday());
    expect(input.details.isEmpty, isTrue);
    expect(care.filesAdded, [
      ('rec-new-1', 'upload-1'),
      ('rec-new-1', 'upload-2'),
    ]);
    expect(find.text('New record'), findsNothing, reason: 'the form closed');
  });

  testWidgets('a retry after a photo failed updates the record it made', (
    tester,
  ) async {
    await open(tester, '/pets/p1/records/new?kind=deworming');
    expect(textOf(tester, 'Title'), 'Deworming');
    await addPhotosFromLibrary(tester);

    care.addFileError = const ApiException(ApiErrorKind.network);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "The record is saved, but some photos weren't attached. Save again "
        'to attach them.',
      ),
      findsOneWidget,
    );

    care.addFileError = null;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(care.createdRecords, hasLength(1), reason: 'not added twice');
    expect(care.updatedRecords.single.$1, 'rec-new-1');
    expect(files.uploads, hasLength(2), reason: 'nothing uploaded twice');
    expect(care.fileIds('rec-new-1'), ['upload-1', 'upload-2']);
  });

  testWidgets('a lost response: the retry sends the same request id and the '
      'record is added once', (tester) async {
    await open(tester, '/pets/p1/records/new?kind=deworming');

    // The record is added, but the answer never arrives.
    care.loseNextCreateResponse = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(care.createRequestIds, hasLength(2));
    expect(care.createRequestIds.toSet(), hasLength(1), reason: 'same id');
    expect(care.createdRecords, hasLength(1), reason: 'added once');
    expect(care.records.where((r) => r.title == 'Deworming'), hasLength(1));
    expect(find.text('New record'), findsNothing, reason: 'the form closed');
  });

  testWidgets('editing: photos are removed and added one by one; a value '
      'outside the kind is kept', (tester) async {
    care.records = [
      testRecord(
        'r1',
        kind: CareKind.deworming,
        title: 'Deworming',
        product: 'Milbemax',
        // Entered elsewhere (e.g. the web): a deworming has no weight field.
        weightKg: 4.2,
        files: [testFile('a'), testFile('b')],
      ),
    ];
    picker.library = const [PickedMedia(path: '/tmp/c.jpg', name: 'c.jpg')];
    await open(tester, '/pets/p1/records/r1/edit');

    expect(find.text('Edit record'), findsOneWidget);
    expect(textOf(tester, 'Weight, kg'), '4.2');
    // Another phone adds a photo while this form is open.
    await care.addRecordFile('r1', 'x');

    await tapVisible(tester, find.byTooltip('Remove photo 1'));
    await addPhotosFromLibrary(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final input = care.updatedRecords.single.$2;
    expect(input.weightKg, 4.2);
    expect(input.product, 'Milbemax');
    expect(care.filesRemoved, [('r1', 'a')]);
    expect(care.filesAdded.last, ('r1', 'upload-1'));
    expect(care.fileIds('r1'), ['b', 'x', 'upload-1']);
  });

  testWidgets('a full record can swap a photo: removed photos go first', (
    tester,
  ) async {
    // Review probe "photo_swap".
    care.records = [
      testRecord(
        'r1',
        title: 'Rabies',
        targets: const [VaccineTarget.rabies],
        files: [for (var i = 0; i < CareRecord.maxFiles; i++) testFile('f$i')],
      ),
    ];
    picker.library = const [PickedMedia(path: '/tmp/new.jpg', name: 'new.jpg')];
    await open(tester, '/pets/p1/records/r1/edit');

    await tapVisible(tester, find.byTooltip('Remove photo 1'));
    await addPhotosFromLibrary(tester);
    await tapVisible(tester, find.text('Save'));

    expect(care.filesRemoved, [('r1', 'f0')]);
    expect(care.fileIds('r1'), [
      for (var i = 1; i < CareRecord.maxFiles; i++) 'f$i',
      'upload-1',
    ]);
    expect(find.text('Edit record'), findsNothing, reason: 'saved and closed');
  });

  testWidgets('a lost response when adding, then Back: the history shows the '
      'record', (tester) async {
    await open(tester, '/pets/p1?tab=health');
    final add = find.text('Add past record');
    await tester.scrollUntilVisible(
      add,
      300,
      scrollable: find
          .descendant(
            of: find.byType(HealthTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapVisible(tester, add);

    care.loseNextCreateResponse = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.widgetWithText(RecordRow, 'Vaccination'), findsOneWidget);
  });

  testWidgets('a record deleted elsewhere: the form says so and closes', (
    tester,
  ) async {
    care.records = [testRecord('r1', title: 'Rabies')];
    await open(tester, '/pets/p1/records/r1/edit');

    // Another phone deletes the record.
    care.records.clear();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('This record has been deleted, probably on another device.'),
      findsOneWidget,
    );
    expect(find.text('Edit record'), findsNothing);
  });

  testWidgets('a validity that ends before the vaccination is refused', (
    tester,
  ) async {
    await open(tester, '/pets/p1/records/new');
    final today = testToday();
    await pickDate(
      tester,
      'Valid until',
      DateTime(today.year, today.month, today.day - 10),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Must be after the date of the vaccination and the start'),
      findsOneWidget,
    );
    expect(care.createdRecords, isEmpty);
  });

  testWidgets('a test result is a number from 0 to 1000, with a comma or a '
      'dot', (tester) async {
    await open(tester, '/pets/p1/records/new?kind=rabiesTiter');
    await tester.enterText(field('Result, IU/ml'), '5000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Use a number from 0 to 1000'), findsOneWidget);

    await tester.enterText(field('Result, IU/ml'), '2,5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(care.createdRecords.single.$2.details.titerIuPerMl, 2.5);
  });
}
