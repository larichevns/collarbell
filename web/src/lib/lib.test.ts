import { describe, expect, it } from 'vitest';
import { fileUrl } from '../api/files';
import type { FileLink } from '../api/types';
import { en } from '../i18n/en';
import { ru } from '../i18n/ru';
import { nb } from '../test/nb';
import { nextDueAfterDone, usesProduct, usesTime, usesValidity } from './care';
import { addInterval, addMonths, ageOn, apiTime, daysBetween, timeInputValue, todayIn } from './dates';
import { displayCode, identifierProblem, normalizeCode } from './identifiers';
import { formatInviteCode, impossibleInviteCode, inviteCodeOf, inviteDaysLeft, inviteLink } from './invites';
import { ageLabel, dueLabel, householdName, intervalLabel, supplyDaysLabel, visitReminderLabel } from './labels';

describe('dates', () => {
  it("knows today in the household's zone, not the browser's", () => {
    // 22:30 in UTC is already the next day in Moscow (UTC+3) and still the same day in New York.
    const late = new Date('2026-10-07T22:30:00Z');
    expect(todayIn('Europe/Moscow', late)).toBe('2026-10-08');
    expect(todayIn('America/New_York', late)).toBe('2026-10-07');
  });

  it('counts calendar days and months the way the server does', () => {
    expect(daysBetween('2026-10-07', '2026-10-09')).toBe(2);
    expect(daysBetween('2026-10-07', '2026-09-30')).toBe(-7);
    // A day with a clock change is still one day.
    expect(daysBetween('2026-03-28', '2026-03-30')).toBe(2);
    expect(addMonths('2026-01-31', 1)).toBe('2026-02-28');
    expect(addMonths('2028-01-31', 1)).toBe('2028-02-29');
    expect(addInterval('2026-10-07', 3, 'Month')).toBe('2027-01-07');
    expect(addInterval('2026-10-07', 2, 'Week')).toBe('2026-10-21');
    expect(addInterval('2024-02-29', 1, 'Year')).toBe('2025-02-28');
  });

  it('works out an age in whole years and months', () => {
    expect(ageOn('2020-10-08', '2026-10-07')).toEqual({ years: 5, months: 11 });
    expect(ageOn('2020-10-07', '2026-10-07')).toEqual({ years: 6, months: 0 });
    expect(ageOn('2026-09-20', '2026-10-07')).toEqual({ years: 0, months: 0 });
    expect(ageOn('2026-10-08', '2026-10-07')).toBeNull();
  });

  it('turns times between the API and the time input', () => {
    expect(timeInputValue('08:30:00')).toBe('08:30');
    expect(timeInputValue(null)).toBe('');
    expect(apiTime('08:30')).toBe('08:30:00');
  });
});

describe('identifiers', () => {
  it('checks microchip and tattoo codes by the server rules', () => {
    expect(normalizeCode('276 098-100.123*456')).toBe('276098100123456');
    expect(identifierProblem('IsoChip', '276 098 100 123 456')).toBeNull();
    expect(identifierProblem('IsoChip', '27609810012345')).toBe('isoLength');
    expect(identifierProblem('IsoChip', '999098100123456')).toBe('isoTestChip');
    expect(identifierProblem('LegacyChip', '0A1B2C3D4E')).toBeNull();
    expect(identifierProblem('LegacyChip', '123456789')).toBeNull();
    expect(identifierProblem('LegacyChip', '12345')).toBe('legacyFormat');
    expect(identifierProblem('Tattoo', 'ABC 123')).toBeNull();
    expect(identifierProblem('Tattoo', 'A'.repeat(21))).toBe('tattooLength');
    expect(identifierProblem('Tattoo', ' ')).toBe('empty');
    expect(identifierProblem('Tattoo', 'X'.repeat(41))).toBe('tooLong');
    expect(identifierProblem('IsoChip', '276098100123456', ['276098100123456'])).toBe('duplicate');
  });

  it('shows ISO numbers in groups of three', () => {
    expect(displayCode('IsoChip', '643094100000001')).toBe('643 094 100 000 001');
    expect(displayCode('Tattoo', 'ABC123')).toBe('ABC123');
  });
});

describe('care rules', () => {
  it('asks for the fields each kind of care has', () => {
    expect(usesProduct('Vaccination')).toBe(true);
    expect(usesProduct('VetExam')).toBe(false);
    expect(usesValidity('Vaccination')).toBe(true);
    expect(usesValidity('Deworming')).toBe(false);
    expect(usesTime('Echinococcus')).toBe(true);
  });

  it('works out the next date after "Done" like the server', () => {
    const interval = { value: 3, unit: 'Month' as const };
    expect(nextDueAfterDone({ interval, performedOn: '2026-10-07', validUntil: null, chosen: null })).toBe(
      '2027-01-07',
    );
    // A vaccine's "valid until" wins over the interval; a date the person chose wins over both.
    expect(nextDueAfterDone({ interval, performedOn: '2026-10-07', validUntil: '2027-10-01', chosen: null })).toBe(
      '2027-10-01',
    );
    expect(nextDueAfterDone({ interval, performedOn: '2026-10-07', validUntil: null, chosen: '2026-12-01' })).toBe(
      '2026-12-01',
    );
    // A one-off plan finishes.
    expect(nextDueAfterDone({ interval: null, performedOn: '2026-10-07', validUntil: null, chosen: null })).toBeNull();
  });
});

describe('labels', () => {
  it('says how far a due date is', () => {
    expect(dueLabel(en, -3)).toBe('3 days overdue');
    expect(dueLabel(en, 0)).toBe('Today');
    expect(dueLabel(en, 1)).toBe('Tomorrow');
    expect(dueLabel(en, 5)).toBe('In 5 days');
    expect(dueLabel(en, 334)).toBe('In 11 months');
    expect(dueLabel(ru, -1)).toBe(nb('Просрочено на~1~день'));
    expect(dueLabel(ru, 22)).toBe(nb('Через 22~дня'));
  });

  it('names intervals, reminders, ages and supplies in both languages', () => {
    expect(intervalLabel(en, 3, 'Month')).toBe('Every 3 months');
    expect(intervalLabel(en, 1, 'Year')).toBe('Every year');
    expect(intervalLabel(ru, 21, 'Day')).toBe(nb('Раз в~21~день'));
    expect(intervalLabel(ru, 5, 'Year')).toBe(nb('Раз в~5~лет'));
    expect(intervalLabel(ru, null, null)).toBe('Разовый');
    expect(visitReminderLabel(en, 1440)).toBe('A day before');
    expect(visitReminderLabel(en, 120)).toBe('2 hours before');
    expect(visitReminderLabel(ru, 2880)).toBe(nb('За~2~дня'));
    expect(ageLabel(en, '2020-10-07', false, '2026-10-07')).toBe('6 years');
    expect(ageLabel(ru, '2026-05-01', true, '2026-10-07')).toBe(nb('≈ 5~месяцев'));
    expect(supplyDaysLabel(en, 2.5)).toBe('about 2 days');
    expect(supplyDaysLabel(ru, 0.4)).toBe(nb('меньше чем на~день'));
  });

  it('calls the first household "My home" for its owner and "Home" for the others', () => {
    expect(householdName(en, 'Home', 'Owner')).toBe('My home');
    expect(householdName(ru, 'Home', 'Helper')).toBe('Дом');
    expect(householdName(en, 'Office', 'Owner')).toBe('Office');
  });
});

describe('file links', () => {
  const link = (url: string, minutes: number): FileLink => ({
    id: 'f1',
    contentType: 'image/jpeg',
    sizeBytes: 1,
    width: null,
    height: null,
    url,
    thumbnailUrl: `${url}/small`,
    expiresAt: new Date(Date.UTC(2026, 9, 7, 12, minutes)).toISOString(),
  });

  it('keeps showing a photo at the link it was first shown with while that link lives', () => {
    const noon = Date.UTC(2026, 9, 7, 12, 0);
    expect(fileUrl(link('https://files/a', 15), true, noon)).toBe('https://files/a/small');
    // The next answer brings a fresh link to the same photo: the browser keeps the picture it has.
    expect(fileUrl(link('https://files/b', 16), true, noon + 5 * 60_000)).toBe('https://files/a/small');
    // With less than a minute left, the fresh one takes over.
    expect(fileUrl(link('https://files/c', 30), true, noon + 14.5 * 60_000)).toBe('https://files/c/small');
    expect(fileUrl(link('https://files/c', 30), false, noon)).toBe('https://files/c');
  });
});

describe('invite codes', () => {
  it('takes a code as typed or pasted, writes it with its hyphen, and knows the letters codes never have', () => {
    expect(inviteCodeOf('abcd-2345')).toBe('ABCD2345');
    expect(inviteCodeOf('ab cd 23')).toBe('ABCD23');
    expect(inviteCodeOf('ABCD-2345-XYZ')).toBe('ABCD2345');
    // A message: its last code-like word, after the group's name.
    expect(inviteCodeOf('Join “Home Team” in Collarbell: code HKQM-7RTW, valid for 7 days.')).toBe('HKQM7RTW');
    expect(formatInviteCode('ABCD')).toBe('ABCD');
    expect(formatInviteCode('ABCD23')).toBe('ABCD-23');
    expect(impossibleInviteCode('ABCD2O45')).toBe(true);
    expect(impossibleInviteCode('ABCD2345')).toBe(false);
  });

  it("counts the days an invite still works upwards, and links to the web's join page with the code after #", () => {
    const now = Date.parse('2026-10-07T12:00:00Z');
    expect(inviteDaysLeft('2026-10-14T12:00:00Z', now)).toBe(7);
    expect(inviteDaysLeft('2026-10-07T13:00:00Z', now)).toBe(1);
    expect(inviteLink('ABCD-2345', '/app/join', 'https://collarbell.example')).toBe(
      'https://collarbell.example/app/join#ABCD-2345',
    );
  });
});

describe("invite codes after part 3's review", () => {
  it("takes the code from the phone's share text in both languages, a group name like a code before it", () => {
    expect(inviteCodeOf('Join “Home-2024” in Collarbell: code ABCD-2345, valid for 7 days.')).toBe('ABCD2345');
    expect(inviteCodeOf('Присоединяйтесь к группе «Building» в Collarbell: код HKQM-7RTW, действует 7 дней.')).toBe(
      'HKQM7RTW',
    );
    expect(inviteCodeOf('https://collarbell.example.com/app/join#ABCD-2345')).toBe('ABCD2345');
  });
});
