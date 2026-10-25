// Screen: «Выберите план», the ready-made care plans for a cat (06_care_preset_picker_full).
// Run: python3 bridge.py run jobs/_screens.js jobs/s06_care_kit.js jobs/s06_care_presets.js
await cbSetup();

const VAX = 'vaccines';
const WORMS = 'medication';
const PESTS = 'pest_control';
const groups = [
  ['Прививки', [
    [VAX, 'Комплексная прививка (панлейкопения, герпес, калицивироз)', 'Раз в год',
      'После серии котёнка и ревакцинации в 6 месяцев. Домашним кошкам с низким риском — раз в 3 года.'],
    [VAX, 'Комплексная прививка, серия котёнка', 'Раз в 4 недели',
      'С 6–8 недель каждые 3–4 недели до 16–20 недель, затем ежегодный план.'],
    [VAX, 'Бешенство', 'Раз в год',
      'На этикетке вакцины срок 1 или 3 года: ориентируйтесь на дату «действует до».'],
    [VAX, 'Лейкоз кошек (FeLV)', 'Раз в год',
      'Сначала тест. Две дозы с интервалом 3–4 недели, затем раз в год, если кошка гуляет.'],
    [VAX, 'Хламидиоз', 'Раз в год', 'Только если кошка в группе риска.'],
  ]],
  ['Обработка от глистов', [
    [WORMS, 'Обработка от глистов', 'Раз в 3 месяца', 'Если риск неизвестен — не реже 4 раз в год.'],
    [WORMS, 'Обработка от глистов, домашняя кошка', 'Раз в 6 месяцев',
      'Кошкам, которые не выходят на улицу, — 1–2 раза в год.'],
    [WORMS, 'Обработка от глистов, кошка охотится', 'Раз в месяц',
      'Кошкам, которые гуляют и охотятся, — 4–12 раз в год.'],
    [WORMS, 'Обработка от глистов, котёнок', 'Раз в 2 недели',
      'С 3 недель каждые 2 недели до отъёма, затем раз в месяц до 6 месяцев.'],
  ]],
  ['Блохи, клещи и дирофиляриоз', [
    [PESTS, 'Блохи и клещи, раз в месяц', 'Раз в месяц',
      'Средства на месяц, например Frontline, Advantage или Revolution.'],
    [PESTS, 'Бравекто', 'Раз в 12 недель', 'Против некоторых клещей — 8 недель.'],
    [PESTS, 'Бравекто Плюс (также глисты и дирофиляриоз)', 'Раз в 12 недель', 'По этикетке для США — 2 месяца.'],
    [PESTS, 'Ошейник Seresto', 'Раз в 8 месяцев'],
  ]],
  ['Осмотры и уход', [
    ['medical_services', 'Осмотр у ветеринара', 'Раз в год', 'С 10 лет — раз в полгода.'],
    ['sentiment_satisfied', 'Осмотр зубов', 'Раз в год'],
    ['content_cut', 'Стрижка когтей', 'Раз в 3 недели'],
  ]],
];
// The app draws these two with plain (filled) icons, the rest outlined.
const FILLED = ['edit_note', 'content_cut'];

// A row to choose (the app's _ChoiceRow): icon disc, title, interval and note, chevron.
// Icon and chevron sit at the top; the lines are 4 apart.
async function choiceRow(glyph, title, lines) {
  const texts = [await text(title, 'subtitle', 'ink', { name: 'title', w: 'fill' })];
  for (const line of lines) texts.push(await text(line, 'body-sm', 'ink-muted', { name: 'line', w: 'fill' }));
  return box({ name: title, dir: 'H', pad: [12, 16, 12, 16], w: 'fill' }, [
    kindDisc(glyph, FILLED.includes(glyph)),
    box({ name: 'texts', dir: 'V', gap: 4, pad: [0, 0, 0, 12], w: 'fill' }, texts),
    icon('chevron_right', 24, 'ink-muted', true),
  ]);
}

const blocks = [card([await choiceRow('edit_note', 'Свой план', ['Тип и периодичность зададите сами.'])])];
for (const [title, presets] of groups) {
  const rows = [];
  for (const [glyph, name, interval, note] of presets) {
    if (rows.length) rows.push(divider(68));
    rows.push(await choiceRow(glyph, name, note ? [interval, note] : [interval]));
  }
  blocks.push(await section(title, card(rows)));
}

const frame = await careScreen('Выбор плана — список', 'Выберите план', 'None', careContent(24, blocks), false);
await place(CARE_AREA, 0, frame, '06_care_preset_picker_full.png');
return { picker: frame.id, height: frame.height };
