// The Health tab: plans grouped by status in traffic-light colours, the
// folded finished plans, the history with its filter, and records and plans
// with values this app doesn't know.
import 'package:collarbell/features/care/care.dart';
import 'package:collarbell/features/care/health_tab.dart';
import 'package:collarbell/features/care/widgets/plan_row.dart';
import 'package:collarbell/features/care/widgets/record_row.dart';
import 'package:collarbell/features/pets/pet.dart';
import 'package:collarbell/shared/widgets/cb_status_tag.dart';
import 'package:collarbell/theme/collarbell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump.dart';

const murka = Pet(id: 'p1', name: 'Murka', species: PetSpecies.cat);

/// "Oct 6, 2026" for the date [days] from today, as the rows show it.
String dateIn(int days) {
  final today = testToday();
  return DateFormat.yMMMd(
    'en',
  ).format(DateTime(today.year, today.month, today.day + days));
}

/// A line of a row: the parts joined by dots; dates never break inside.
String row(String first, String date) =>
    '$first · ${date.replaceAll(' ', '\u00A0')}';

/// Scrolls the Health tab until [finder] is built and on screen (being
/// built is not enough: the row may still be under the navigation bar).
Future<void> scrollHealthTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find
        .descendant(
          of: find.byType(HealthTab),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  late FakeCareRepository care;

  Future<void> openHealth(WidgetTester tester) => pumpApp(
    tester,
    location: '/pets/p1?tab=health',
    overrides: fakeRepositories(pets: FakePetsRepository([murka]), care: care),
  );

  setUp(() => care = FakeCareRepository());

  testWidgets('groups plans by status, with traffic-light colours', (
    tester,
  ) async {
    care.plans = [
      testPlan(
        'rabies',
        kind: CareKind.vaccination,
        title: 'Rabies',
        interval: const CareInterval(1, IntervalUnit.year),
        daysLeft: -3,
      ),
      testPlan('deworm', daysLeft: 5, lastDoneOn: DateTime(2026, 7, 6)),
      testPlan(
        'exam',
        kind: CareKind.vetExam,
        title: 'Check-up',
        interval: const CareInterval(1, IntervalUnit.year),
        daysLeft: 120,
      ),
      testPlan(
        'travel',
        kind: CareKind.echinococcus,
        title: 'Tapeworm treatment',
        interval: null,
        daysLeft: -20,
        active: false,
        lastDoneOn: DateTime(2026, 9, 10),
      ),
    ];
    await openHealth(tester);

    // Overdue, due soon, upcoming: in this order. Overdue and due soon are
    // status tags (red and yellow) with the date after them; later is calm.
    final overdue = find.text('3 days overdue');
    final soon = find.text('In 5 days');
    final later = find.text(row('In 4 months', dateIn(120)));
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    expect(top(find.text('Overdue')), lessThan(top(find.text('Due soon'))));
    Finder tagOf(Finder text) =>
        find.ancestor(of: text, matching: find.byType(CbStatusTag));
    expect(
      tester.widget<CbStatusTag>(tagOf(overdue)).tone,
      CbStatusTone.overdue,
    );
    expect(tester.widget<CbStatusTag>(tagOf(soon)).tone, CbStatusTone.soon);
    expect(find.text(dateIn(-3).replaceAll(' ', '\u00A0')), findsOneWidget);
    // Never colour alone: the overdue tag has its icon.
    expect(
      find.descendant(
        of: tagOf(overdue),
        matching: find.byIcon(Symbols.error_rounded),
      ),
      findsOneWidget,
    );
    await scrollHealthTo(tester, later);
    expect(top(find.text('Due soon')), lessThan(top(find.text('Upcoming'))));

    final colors = CbTokenColors.light;
    Color? colorOf(Finder finder) => tester.widget<Text>(finder).style?.color;
    expect(colorOf(later), colors.inkMuted);

    // The interval and the last time.
    expect(
      find.text(
        "Every 3 months · Last done ${'Jul 6, 2026'.replaceAll(' ', '\u00A0')}",
      ),
      findsOneWidget,
    );

    // Finished and paused plans are folded, and have no "Done".
    expect(find.text('Tapeworm treatment'), findsNothing);
    await scrollHealthTo(tester, find.text('Finished or paused (1)'));
    await tester.tap(find.text('Finished or paused (1)'));
    await tester.pumpAndSettle();
    await scrollHealthTo(tester, find.text('Tapeworm treatment'));
    expect(find.text('Finished'), findsOneWidget);
    final travelRow = find.widgetWithText(PlanRow, 'Tapeworm treatment');
    expect(
      find.descendant(of: travelRow, matching: find.byTooltip('Done')),
      findsNothing,
    );
    expect(find.byTooltip('Done'), findsNWidgets(3));
  });

  testWidgets('a pet without plans and records is invited to add them', (
    tester,
  ) async {
    await openHealth(tester);

    expect(
      find.text(
        'No plans yet. Add vaccinations and treatments to see when they are due.',
      ),
      findsOneWidget,
    );
    expect(find.text('Add plan'), findsOneWidget);
    await scrollHealthTo(tester, find.text('Add past record'));
    expect(
      find.text(
        'No records yet. Add past vaccinations and treatments from the '
        'paper passport.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('history: newest first, filtered by kind', (tester) async {
    care.records = [
      testRecord(
        'r2',
        kind: CareKind.deworming,
        title: 'Deworming',
        performedOn: DateTime(2026, 7, 6),
        product: 'Milbemax',
        files: [testFile('sticker')],
      ),
      testRecord(
        'r1',
        title: 'Rabies',
        targets: const [VaccineTarget.rabies],
        performedOn: DateTime(2025, 3, 1),
        product: 'Nobivac Rabies',
      ),
    ];
    await openHealth(tester);
    await scrollHealthTo(tester, find.byType(RecordRow).last);

    final rows = find.byType(RecordRow);
    expect(rows, findsNWidgets(2));
    expect(
      find.descendant(of: rows.first, matching: find.text('Deworming')),
      findsOneWidget,
      reason: 'newest first',
    );
    expect(
      find.text('${'Jul 6, 2026'.replaceAll(' ', '\u00A0')} · Milbemax'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rows.first,
        matching: find.byIcon(Symbols.photo_rounded),
      ),
      findsOneWidget,
      reason: 'a record with photos shows it',
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Vaccination'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordRow), findsOneWidget);
    expect(find.widgetWithText(RecordRow, 'Rabies'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordRow), findsNWidgets(2));
  });

  testWidgets('a record opens with its details; deleting it asks first', (
    tester,
  ) async {
    care.records = [
      testRecord(
        'r1',
        title: 'Rabies',
        targets: const [VaccineTarget.rabies],
        product: 'Nobivac Rabies',
        batchNumber: 'A123',
        validUntil: DateTime(2028, 2, 28),
        files: [testFile('sticker')],
      ),
    ];
    await openHealth(tester);
    await scrollHealthTo(tester, find.byType(RecordRow));
    await tester.tap(find.byType(RecordRow));
    await tester.pumpAndSettle();

    expect(find.text('Nobivac Rabies'), findsOneWidget);
    expect(find.text('A123'), findsOneWidget);
    expect(find.text('Feb 28, 2028'), findsOneWidget);
    expect(find.text('Added by hand'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete record'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Its photos will be deleted too. A plan it completed keeps its '
        "date. You can't undo this.",
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(care.deletedRecords, ['r1']);
    expect(find.byType(HealthTab), findsOneWidget);
    expect(find.byType(RecordRow), findsNothing);
  });

  testWidgets('plans and records from a newer app version are not editable', (
    tester,
  ) async {
    care.plans = [
      testPlan(
        'chip',
        kind: CareKind.other,
        title: 'Microchip check',
        interval: null,
        intervalUnknown: true,
        daysLeft: 3,
        hasUnknownValues: true,
      ),
    ];
    care.records = [
      testRecord('r1', title: 'Chip read', hasUnknownValues: true),
    ];
    await openHealth(tester);

    // The plan is shown, with "Repeats" for the unit this app doesn't know.
    expect(find.text('Microchip check'), findsOneWidget);
    expect(find.text('Repeats'), findsOneWidget);
    await tester.tap(find.text('Microchip check'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This plan was made in a newer version of Collarbell. Update the '
        'app to edit it.',
      ),
      findsOneWidget,
    );
    expect(find.text('Save'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await scrollHealthTo(tester, find.byType(RecordRow));
    await tester.tap(find.byType(RecordRow));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This record was made in a newer version of Collarbell. Update the '
        'app to edit it.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Edit'), findsNothing);
  });
}
