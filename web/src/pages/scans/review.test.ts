// The rules of checking a scan (review.ts, the phone's scan_review.dart): what starts ticked, the AI's doubts until a
// value is changed, ticking after an edit, the passport against what is saved, the pet's five microchips, what a save
// sends, the server's errors back on their entries, the problems that keep a ticked entry from being saved.
import { describe, expect, it } from 'vitest';
import type { CarePlan } from '../../api/types';
import { en } from '../../i18n/en';
import { ru } from '../../i18n/ru';
import { draft, draftIdentifier, draftPassport, draftRecord, draftWeight } from '../../test/ai';
import { nb } from '../../test/nb';
import { plan } from '../../test/server';
import { noteHasWords, noteLength, scanDefaultTitle, scanResultSummary } from './labels';
import {
  afterEdit,
  canSelect,
  codesBefore,
  fieldWarnings,
  identifierProblems,
  markPassportChanges,
  markRecordChanges,
  overLimit,
  passportChanges,
  passportProblems,
  placeServerErrors,
  planChoices,
  recordProblems,
  reviewFromDraft,
  selectedCount,
  sending,
  swapDayAndMonth,
  weightProblems,
  withDate,
  type ReviewRecord,
  type Review,
} from './review';

const TODAY = '2026-10-07';
const NO_PASSPORT = { passportNumber: null, issuingCountry: null, issuedOn: null };
const review = (change: Parameters<typeof draft>[0], options: Partial<Parameters<typeof reviewFromDraft>[1]> = {}) =>
  reviewFromDraft(draft(change), {
    planIds: new Set(['plan-rabies']),
    savedPassport: NO_PASSPORT,
    savedCodes: [],
    ...options,
  });
const defaultTitle = (kind: Parameters<typeof scanDefaultTitle>[1], targets: Parameters<typeof scanDefaultTitle>[2]) =>
  scanDefaultTitle(en, kind, targets);

describe('what starts ticked', () => {
  it("as the server suggests (a duplicate comes unticked), when it has what it needs to be saved", () => {
    const made = review({
      records: [
        draftRecord({ performedOn: '2026-09-01' }),
        draftRecord({ performedOn: '2026-09-01', selected: false, warnings: [{ field: 'record', issue: 'AlreadySaved' }] }),
        // No date read: can't be saved yet, whatever the server says.
        draftRecord({ performedOn: null }),
      ],
      identifiers: [draftIdentifier({ code: '276098100123456' }), draftIdentifier({ code: null })],
      weights: [draftWeight({ measuredOn: '2026-09-01', weightKg: 4.2 }), draftWeight({ measuredOn: null, weightKg: 4.2 })],
    });
    expect(made.records.map((entry) => entry.selected)).toEqual([true, false, false]);
    expect(made.identifiers.map((entry) => entry.selected)).toEqual([true, false]);
    expect(made.weights.map((entry) => entry.selected)).toEqual([true, false]);
    expect(selectedCount(made)).toBe(3);
  });

  it("drops the link to a plan deleted since the scan was read", () => {
    const made = review({
      records: [
        draftRecord({ performedOn: '2026-09-01', planId: 'plan-rabies' }),
        draftRecord({ performedOn: '2026-09-01', planId: 'plan-gone' }),
      ],
    });
    expect(made.records.map((entry) => entry.planId)).toEqual(['plan-rabies', null]);
  });

  it('ticks passport details that fill in an empty header, and leaves a different saved value to the person', () => {
    const fills = review({ passport: draftPassport({ passportNumber: 'de 0123', selected: false }) });
    expect(fills.passport!.selected).toBe(true);
    expect(passportChanges(fills.passport!)).toEqual(['passportNumber']);

    const saved = { passportNumber: 'DE0123', issuingCountry: 'DE', issuedOn: '2024-01-10' };
    const differs = review(
      {
        passport: draftPassport({
          passportNumber: 'DE0128',
          issuingCountry: 'de',
          issuedOn: '2024-01-10',
          selected: false,
          warnings: [{ field: 'passportNumber', issue: 'DiffersFromSaved' }],
        }),
      },
      { savedPassport: saved },
    );
    const entry = differs.passport!;
    expect(entry.selected).toBe(false);
    expect(canSelect(entry)).toBe(true);
    // Nothing changes until the person says to replace the number.
    expect(passportChanges(entry)).toEqual([]);
    expect(passportChanges({ ...entry, replace: ['passportNumber'] })).toEqual(['passportNumber']);
    // The same as saved: nothing to save.
    const same = review({ passport: draftPassport({ issuingCountry: 'DE' }) }, { savedPassport: saved }).passport!;
    expect(canSelect(same)).toBe(false);
  });
});

describe('doubts and edits', () => {
  it("shows the AI's doubts about a value until it is changed; doubts about the entry stay as badges", () => {
    const [entry] = review({
      records: [
        draftRecord({
          performedOn: '2026-03-04',
          warnings: [
            { field: 'performedOn', issue: 'Ambiguous' },
            { field: 'validUntil', issue: 'EndsBeforeStart' },
            { field: 'record', issue: 'Repeated' },
          ],
        }),
      ],
    }).records;
    expect(fieldWarnings(entry!).map((warning) => warning.field)).toEqual(['performedOn', 'validUntil']);
    // Day and month swapped: the date is the person's now.
    const swapped = withDate(entry!, 'performedOn', swapDayAndMonth(entry!.performedOn!)!);
    expect(swapped.performedOn).toBe('2026-04-03');
    expect(fieldWarnings(swapped).map((warning) => warning.field)).toEqual(['validUntil']);
    // An edit marks what it changed.
    const edited = markRecordChanges(entry!, { ...entry!, validUntil: '2027-03-04' });
    expect(fieldWarnings(edited).map((warning) => warning.field)).toEqual(['performedOn']);
  });

  it('swaps day and month only where both readings are dates and differ', () => {
    expect(swapDayAndMonth('2025-03-04')).toBe('2025-04-03');
    expect(swapDayAndMonth('2025-03-14')).toBeNull();
    expect(swapDayAndMonth('2025-05-05')).toBeNull();
  });

  it('after an edit: unticked when it can no longer be saved, ticked when it now can (unless it repeats something)', () => {
    const [missing, repeated] = review({
      records: [
        draftRecord({ performedOn: null }),
        draftRecord({ performedOn: null, warnings: [{ field: 'record', issue: 'AlreadySaved' }] }),
      ],
    }).records;
    expect(afterEdit(missing!, { ...missing!, performedOn: '2026-09-01' }).selected).toBe(true);
    expect(afterEdit(repeated!, { ...repeated!, performedOn: '2026-09-01' }).selected).toBe(false);
    const ticked: ReviewRecord = { ...missing!, performedOn: '2026-09-01', selected: true };
    expect(afterEdit(ticked, { ...ticked, performedOn: null }).selected).toBe(false);
  });

  it('server errors go when their field is changed; any change answers an error about the whole record', () => {
    const [entry] = review({ records: [draftRecord({ performedOn: '2026-09-01' })] }).records;
    const refused = { ...entry!, serverErrors: ['product', 'record'] };
    const edited = markRecordChanges(refused, { ...refused, product: 'Nobivac' });
    expect(edited.serverErrors).toEqual([]);
    const passport = review({ passport: draftPassport({ passportNumber: 'X1' }) }).passport!;
    // A value typed by hand replaces the saved one.
    expect(markPassportChanges(passport, { ...passport, issuedOn: '2024-01-01' }).replace).toEqual(['issuedOn']);
  });
});

describe('microchips', () => {
  it("counts the pet's five: numbers it has take no place, and the second of two equal numbers is the one refused", () => {
    const made = review(
      {
        identifiers: [
          draftIdentifier({ code: '276098100000001' }),
          draftIdentifier({ code: '276098100000002' }),
          draftIdentifier({ code: '276 098 100 000 001' }),
        ],
      },
      { savedCodes: ['276098100000009', '276098100000008', '276098100000007', '276098100000006', '276098100000001'] },
    );
    const [first, second, third] = made.identifiers;
    // Five saved, one of them read again (it takes no place): a new number is one too many.
    expect(overLimit(made, first!)).toBe(false);
    expect(overLimit(made, second!)).toBe(true);
    expect(codesBefore(made, third!)).toEqual(['276098100000001', '276098100000002']);
    expect(identifierProblems(en, third!, TODAY, codesBefore(made, third!)).code).toBe(en.identifierDuplicate);
    expect(identifierProblems(en, second!, TODAY, [], true).entry).toBe(en.scanTooManyIdentifiers(5));
  });
});

describe('what a save sends', () => {
  function full(): Review {
    return review({
      records: [
        draftRecord({ kind: 'Vaccination', performedOn: '2026-09-01', targets: ['Rabies'], product: ' Nobivac ', planId: 'plan-rabies' }),
        draftRecord({ kind: 'Deworming', performedOn: '2026-08-01', targets: ['Rabies'], weightKg: 4 }),
        draftRecord({ kind: 'VetExam', title: 'Check-up', performedOn: '2026-07-01', weightKg: 4.456 }),
        draftRecord({ kind: 'Other', performedOn: '2026-06-01', selected: false }),
      ],
      identifiers: [draftIdentifier({ code: ' 276 098 100 123 456 ', location: '  ' })],
      weights: [draftWeight({ measuredOn: '2026-09-02', weightKg: 4.2350000001 })],
      passport: draftPassport({ passportNumber: 'de 12', issuingCountry: 'de' }),
    });
  }

  it('the ticked entries as the server takes them', () => {
    const sent = sending(full(), { keepPhotos: true, defaultTitle });
    const { records, identifiers, passport, weights, keepPhotos } = sent.input;
    expect(records).toHaveLength(3);
    // A record without a title of its own goes under its kind's name, in the person's language.
    expect(records[0]).toMatchObject({
      planId: 'plan-rabies',
      record: { kind: 'Vaccination', title: 'Rabies vaccination', product: 'Nobivac', targets: ['Rabies'], requestId: null },
    });
    // Only vaccinations protect against diseases; only a check-up keeps a weight.
    expect(records[1]!.record).toMatchObject({ title: 'Deworming', targets: [], weightKg: null });
    expect(records[2]!.record).toMatchObject({ title: 'Check-up', weightKg: 4.456 });
    expect(identifiers).toEqual([
      { type: 'IsoChip', code: '276 098 100 123 456', appliedOn: null, readOn: null, location: null },
    ]);
    expect(passport).toEqual({ passportNumber: 'DE12', issuingCountry: 'DE', issuedOn: null });
    expect(weights).toEqual([{ measuredOn: '2026-09-02', weightKg: 4.235 }]);
    expect(keepPhotos).toBe(true);
    expect(sent.passportFields).toEqual(['passportNumber', 'issuingCountry']);
  });

  it("in Russian, a record without a title goes under the kind's Russian name", () => {
    const sent = sending(full(), { keepPhotos: false, defaultTitle: (kind, targets) => scanDefaultTitle(ru, kind, targets) });
    expect(sent.input.records[0]!.record.title).toBe('Вакцинация против бешенства');
    expect(sent.input.keepPhotos).toBe(false);
  });

  it("puts the server's field errors back on the entries they name; one naming no entry says so", () => {
    const made = full();
    const sent = sending(made, { keepPhotos: true, defaultTitle });
    const placed = placeServerErrors(
      made,
      {
        'records[1].record.performedOn': ['Use a date that has come.'],
        'records[0].planId': ['Not this plan.'],
        'identifiers[0].code': ['Not a valid number.'],
        'passport.issuingCountry': ['Use a two-letter code.'],
        'weights[0].weightKg': ['Use a weight above 0.'],
      },
      sent,
    );
    expect(placed.placedAll).toBe(true);
    expect(placed.review.records[1]!.serverErrors).toEqual(['performedOn']);
    expect(placed.review.records[0]!.serverErrors).toEqual(['planId']);
    expect(placed.review.identifiers[0]!.serverErrors).toEqual(['code']);
    expect(placed.review.passport!.serverErrors).toEqual(['issuingCountry']);
    expect(placed.review.weights[0]!.serverErrors).toEqual(['weightKg']);
    expect(recordProblems(en, placed.review.records[1]!, TODAY).performedOn).toBe(en.formServerFieldError);
    expect(placeServerErrors(made, { records: ['Save 50 records or fewer at once.'] }, sent).placedAll).toBe(false);
  });
});

describe('problems', () => {
  it("of a record: its date (not in the future, from 1990), protection that ends before it starts, a check-up's weight", () => {
    const [entry] = review({ records: [draftRecord({ kind: 'VetExam', performedOn: '2026-10-08' })] }).records;
    expect(recordProblems(en, entry!, TODAY).performedOn).toBe(en.scanDateInFuture);
    expect(recordProblems(en, { ...entry!, performedOn: '1989-12-31' }, TODAY).performedOn).toBe(en.dateTooEarly);
    expect(recordProblems(en, { ...entry!, performedOn: null }, TODAY).performedOn).toBe(en.dateRequired);
    const vaccination = { ...entry!, kind: 'Vaccination' as const, performedOn: '2026-09-01', validUntil: '2026-09-01' };
    expect(recordProblems(en, vaccination, TODAY).validUntil).toBe(en.recordValidUntilInvalid);
    expect(recordProblems(en, { ...entry!, performedOn: '2026-09-01', weightKg: 201 }, TODAY).weightKg).toBe(
      en.weightInvalid,
    );
    // Another kind sends no weight: it isn't checked.
    expect(recordProblems(en, { ...vaccination, validUntil: null, weightKg: 201 }, TODAY)).toEqual({});
  });

  it("of passport details and weighings: the server's formats, and no weighing before the pet was born", () => {
    const passport = review({ passport: draftPassport({ issuingCountry: 'DEU' }) }).passport!;
    expect(passportProblems(en, passport, TODAY).issuingCountry).toBe(en.passportCountryInvalid);
    const [weight] = review({ weights: [draftWeight({ measuredOn: '2024-01-01', weightKg: 0.0004 })] }).weights;
    const problems = weightProblems(en, weight!, TODAY, '2025-02-01');
    expect(problems.measuredOn).toBe(en.weightDateBeforeBirth);
    expect(problems.weightKg).toBe(en.weightInvalid);
  });
});

describe('plans a record can be the "Done" of', () => {
  it('the active ones of its kind, a vaccination only against the same diseases when both say', () => {
    const plans: CarePlan[] = [
      plan('rabies', 'pet', TODAY, { kind: 'Vaccination', targets: ['Rabies'], daysLeft: 9 }),
      plan('fvrcp', 'pet', TODAY, { kind: 'Vaccination', targets: ['Fpv'], daysLeft: 9 }),
      plan('any-vaccine', 'pet', TODAY, { kind: 'Vaccination', daysLeft: 9 }),
      plan('paused', 'pet', TODAY, { kind: 'Vaccination', targets: ['Rabies'], daysLeft: 9, active: false }),
      plan('worms', 'pet', TODAY, { kind: 'Deworming', daysLeft: 9 }),
    ];
    const [rabies] = review({ records: [draftRecord({ performedOn: '2026-09-01', targets: ['Rabies'] })] }).records;
    expect(planChoices(rabies!, plans).map((each) => each.id)).toEqual(['rabies', 'any-vaccine']);
    // The paused one it is linked to stays a choice.
    expect(planChoices({ ...rabies!, planId: 'paused' }, plans).map((each) => each.id)).toContain('paused');
  });
});

describe('notes', () => {
  it('has words when it has a letter or a digit, as the server counts them (one UTF-16 unit at a time)', () => {
    expect(noteHasWords('вчера прививка')).toBe(true);
    expect(noteHasWords('4.2')).toBe(true);
    expect(noteHasWords(' !? … ')).toBe(false);
    expect(noteHasWords('😺🐾')).toBe(false);
    // Trimmed, and an emoji counts two.
    expect(noteLength('  ok 😺  ')).toBe(5);
  });
});

describe('what saving did, in words', () => {
  it('lists what was saved, as one sentence, in both languages', () => {
    const result = {
      recordIds: ['a', 'b', 'c'],
      plansMoved: 1,
      identifiersAdded: 1,
      passportUpdated: true,
      documentId: 'doc',
      weightsAdded: 2,
    };
    expect(scanResultSummary(en, result, 'PassportPages', { passportFields: ['passportNumber'], identifiersSent: 2 })).toBe(
      'Saved 3 records · 1 plan updated · 2 weighings added · 1 microchip or tattoo added · 1 number was already on the pet · passport details updated: number · photos added to the passport pages',
    );
    expect(scanResultSummary(ru, { ...result, identifiersAdded: 0, passportUpdated: false }, 'VetDocument')).toBe(
      nb('Сохранены 3~записи · обновлён 1~план · добавлены 2~взвешивания · фото сохранены как документ'),
    );
    expect(
      scanResultSummary(en, { ...result, recordIds: [], plansMoved: 0, identifiersAdded: 0, passportUpdated: false, documentId: null, weightsAdded: 0 }, 'Text'),
    ).toBe('Nothing was saved');
  });
});
