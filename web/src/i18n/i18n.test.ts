import { afterEach, describe, expect, it } from 'vitest';
import { nb } from '../test/nb';
import { en } from './en';
import { formatDate, formatMomentTime, formatNumber, formatTime } from './format';
import { startingLanguage } from './i18n';
import { langOf } from './lang';
import { ru } from './ru';

/**
 * Every text of a dictionary as a path and what is there: a string, or what a function gives for sample arguments
 * (counts that pick every plural form, and words).
 */
function texts(messages: object, prefix = ''): Map<string, string[]> {
  const found = new Map<string, string[]>();
  for (const [key, value] of Object.entries(messages)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (typeof value === 'string') found.set(path, [value]);
    else if (typeof value === 'function') {
      const fn = value as (...args: unknown[]) => unknown;
      // Texts with more words than a count and a name get a word for each.
      const more = Array.from({ length: Math.max(0, fn.length - 2) }, (_, index) => `w${index}`);
      const samples =
        fn.length === 2 && key === 'intervalEvery'
          ? [1, 2, 5, 21].flatMap((count) => (['Day', 'Week', 'Month', 'Year'] as const).map((unit) => fn(count, unit)))
          : [0, 1, 2, 5, 11, 21, 22, 1.5].map((count) => fn(count, 'x', ...more));
      found.set(path, samples.map(String));
    } else if (value && typeof value === 'object') {
      for (const [inner, innerTexts] of texts(value, path)) found.set(inner, innerTexts);
    }
  }
  return found;
}

describe('the dictionaries', () => {
  it('have every key in both languages', () => {
    const english = texts(en);
    const russian = texts(ru);
    expect([...russian.keys()].sort()).toEqual([...english.keys()].sort());
  });

  it('have a text for every key and every count', () => {
    for (const [lang, messages] of [
      ['en', en],
      ['ru', ru],
    ] as const) {
      for (const [path, values] of texts(messages)) {
        for (const value of values) {
          expect(value.trim(), `${lang}: ${path}`).not.toBe('');
          expect(value, `${lang}: ${path}`).not.toMatch(/undefined|\{|\}/);
        }
      }
    }
  });

  it('pick the Russian plural forms', () => {
    expect([1, 2, 5, 21, 22, 25].map((days) => ru.dueInDays(days))).toEqual([
      nb('Через 1~день'),
      nb('Через 2~дня'),
      nb('Через 5~дней'),
      nb('Через 21~день'),
      nb('Через 22~дня'),
      nb('Через 25~дней'),
    ]);
    expect(ru.visitDoneSavedPlans(3)).toBe(nb('Сохранено. Перенесено 3~плана.'));
    expect(en.visitDoneSavedPlans(1)).toBe('Saved. One plan moved to its next date.');
    expect(en.formTooLong(60)).toBe('Use 60 characters or fewer');
  });

  it("pick the Russian forms of part 2's counts", () => {
    expect([1, 3, 5, 22].map((count) => ru.bulkSave(count))).toEqual([
      nb('Сохранить 1~запись'),
      nb('Сохранить 3~записи'),
      nb('Сохранить 5~записей'),
      nb('Сохранить 22~записи'),
    ]);
    expect([1, 2, 11].map((count) => ru.documentPageCount(count))).toEqual([
      nb('1~страница'),
      nb('2~страницы'),
      nb('11~страниц'),
    ]);
    expect([1, 4, 5].map((count) => ru.recordFileCount(count))).toEqual([nb('1~файл'), nb('4~файла'), nb('5~файлов')]);
    expect(ru.intervalUnitName.Year(5)).toBe('лет');
    expect(ru.intervalUnitName.Week(2)).toBe('недели');
    expect(ru.weightTooPrecise(3)).toBe(nb('Не~больше 3~знаков после запятой'));
    expect(ru.bulkNotSaved(1)).toBe(nb('Не~сохранилась 1~строка: причина~— под~ней. Нажмите «Сохранить» ещё раз.'));
    expect(en.bulkSaved(1)).toBe('1 record added to the history.');
    expect(en.intervalUnitName.Month(1)).toBe('month');
    // Every ready-made plan of the server has its words in both languages.
    expect(Object.keys(ru.presetTitles).sort()).toEqual(Object.keys(en.presetTitles).sort());
    expect(Object.keys(ru.presetNotes).sort()).toEqual(Object.keys(en.presetNotes).sort());
  });
});

describe("part 3's words", () => {
  it('pick the Russian forms of the counts of supplies, groups, invites and downloads', () => {
    expect([1, 3, 5, 21].map((count) => ru.supplyLeadTimeDays(count))).toEqual([
      nb('1~день'),
      nb('3~дня'),
      nb('5~дней'),
      nb('21~день'),
    ]);
    expect([1, 2, 5].map((count) => ru.supplyDoses(count))).toEqual([nb('1~доза'), nb('2~дозы'), nb('5~доз')]);
    expect([1, 2, 5].map((count) => ru.householdMemberCount(count))).toEqual([
      nb('1~человек'),
      nb('2~человека'),
      nb('5~человек'),
    ]);
    expect(en.householdMemberCount(1)).toBe('1 person');
    expect(en.householdMemberCount(3)).toBe('3 people');
    expect(ru.householdInviteCodeBody(7)).toBe(nb('Код сработает один раз и~действует 7~дней.'));
    expect(ru.householdInviteCodeBody(1)).toBe(nb('Код сработает один раз и~действует 1~день.'));
    expect(ru.dataExportTooOftenIn(25)).toBe(
      nb('Вы~уже несколько раз скачивали данные за~этот час. Попробуйте через 25~минут.'),
    );
    expect(en.dataExportTooOftenIn(1)).toBe(
      "You've downloaded your data several times this hour. Try again in 1 minute.",
    );
    expect(ru.joinPreview('Иван', 'Друзья', 'Helper')).toBe(nb('Иван~приглашает вас в~группу «Друзья» как помощника.'));
    expect(en.joinPreviewNoName('Friends', 'Member')).toBe("You're invited to “Friends” as a member.");
    // Every kind, unit, group of the list and theme has its word in both languages.
    expect(Object.keys(ru.supplyCategory)).toEqual(Object.keys(en.supplyCategory));
    expect(Object.keys(ru.supplyInputUnit)).toEqual(Object.keys(en.supplyInputUnit));
    expect(Object.keys(ru.supplyGroup)).toEqual(Object.keys(en.supplyGroup));
    expect(Object.keys(ru.themeNames)).toEqual(Object.keys(en.themeNames));
  });
});

describe("part 4's words", () => {
  it('pick the Russian forms of the counts of scans, notes, the AI limits and deleting the account', () => {
    expect([1, 3, 5, 21].map((count) => ru.scanSavedRecords(count))).toEqual([
      nb('сохранена 1~запись'),
      nb('сохранены 3~записи'),
      nb('сохранено 5~записей'),
      nb('сохранена 21~запись'),
    ]);
    expect([1, 2, 5].map((count) => ru.scanSavedWeights(count))).toEqual([
      nb('добавлено 1~взвешивание'),
      nb('добавлены 2~взвешивания'),
      nb('добавлено 5~взвешиваний'),
    ]);
    expect(ru.noteLimitReached(30)).toBe(
      nb('AI уже прочитал 30~заметок за~сутки. Попробуйте завтра или~добавьте запись вручную.'),
    );
    expect(ru.errorTooManyRequestsIn(21)).toBe(nb('Слишком много запросов подряд. Попробуйте через 21~секунду.'));
    expect(ru.scanTooManyPages(10)).toBe(nb('Взяты только первые 10~страниц.'));
    expect([0, 1, 2, 5].map((pets) => ru.deleteAccountFateDeleted(pets))).toEqual([
      nb('Удалится со~всем, что в~ней есть.'),
      nb('Удалится вместе с~1~питомцем и~всеми записями, фото и~документами.'),
      nb('Удалится вместе с~2~питомцами и~всеми записями, фото и~документами.'),
      nb('Удалится вместе с~5~питомцами и~всеми записями, фото и~документами.'),
    ]);
    expect(en.deleteAccountFateDeleted(1)).toBe('Will be deleted with its pet and all its records, photos and documents.');
    expect(ru.deleteAccountConfirmBody(2, nb('«Дом» и~«Дача»'))).toBe(
      nb('Удалятся группы «Дом» и~«Дача»~со~всем, что в~них есть. Отменить это нельзя.'),
    );
    expect(en.scanSaveSelected(0)).toBe('Nothing to save');
    expect(ru.scanSaveSelected(3)).toBe('Сохранить выбранное (3)');
    // Every status of a scan, and every passport field a scan fills, has its word in both languages.
    expect(Object.keys(ru.scanStatus)).toEqual(Object.keys(en.scanStatus));
    expect(Object.keys(ru.scanPassportField)).toEqual(Object.keys(en.scanPassportField));
  });
});

describe('formats', () => {
  it('shows calendar dates as they are, in the language', () => {
    expect(formatDate('en', '2026-10-07')).toBe('Oct 7, 2026');
    expect(formatDate('ru', '2026-10-07')).toBe(nb('7~окт. 2026~г.'));
    expect(formatDate('en', '2026-10-07', 'weekday')).toBe('Wednesday, October 7');
    expect(formatDate('ru', '2026-10-07', 'weekday')).toBe(nb('среда, 7~октября'));
    // A Russian date that ends a sentence keeps its own full stop: no second one.
    expect(ru.planResetsOn(formatDate('ru', '2026-11-01'))).toBe(nb('Счётчик обнулится 1~нояб. 2026~г.'));
  });

  it('shows times and moments the way the language writes them', () => {
    expect(formatTime('en', '08:00:00')).toBe('8:00 AM');
    expect(formatTime('ru', '19:30:00')).toBe('19:30');
    // A mark made at 05:02 UTC is 08:02 in the household's Moscow.
    expect(formatMomentTime('ru', '2026-10-07T05:02:00Z', 'Europe/Moscow')).toBe('08:02');
    expect(formatNumber('ru', 2.5)).toBe('2,5');
    expect(formatNumber('en', 1234.5)).toBe('1,234.5');
  });

  it('takes Russian for any Russian locale, English for the rest', () => {
    expect(langOf('ru-RU')).toBe('ru');
    expect(langOf('en-GB')).toBe('en');
    expect(langOf('de')).toBe('en');
    expect(langOf(null)).toBe('en');
  });
});

describe('the ready-made plans', () => {
  it('have their titles in the app for every code the server sends', async () => {
    const { PRESETS } = await import('../test/presets');
    for (const preset of PRESETS) {
      expect(en.presetTitles[preset.code], preset.code).toBeTruthy();
      expect(ru.presetTitles[preset.code], preset.code).toBeTruthy();
      // A note where the server has one.
      expect(!!en.presetNotes[preset.code], preset.code).toBe(!!preset.note);
    }
  });
});

describe('the language of a link', () => {
  afterEach(() => window.history.replaceState(null, '', '/'));

  it("takes the landing's language (?lang=ru) when none was picked here, and keeps it as picked", () => {
    window.history.replaceState(null, '', '/app/?lang=ru');
    expect(startingLanguage()).toBe('ru');
    expect(window.localStorage.getItem('collarbell.language')).toBe('ru');
    // Picked before: another link's language doesn't change it.
    window.history.replaceState(null, '', '/app/?lang=en');
    expect(startingLanguage()).toBe('ru');
  });

  it('has none without a link or a pick', () => {
    window.history.replaceState(null, '', '/app/?lang=de');
    expect(startingLanguage()).toBeNull();
    expect(window.localStorage.getItem('collarbell.language')).toBeNull();
  });
});
