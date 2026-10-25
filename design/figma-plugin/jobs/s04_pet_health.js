// Screen: the pet's page, tab Здоровье (04_pet_2_health): the care plan by status and the history.
// Run as: bridge.py run jobs/_screens.js jobs/_pet_kit.js jobs/s04_pet_health.js
await cbSetup();
const AREA = '04 Страница питомца';

// When a plan is due: Status line, its words wrapping under the first line.
async function dueLine(status, words) {
  const line = sized(await inst('Status line', { Status: status }), 'fill');
  line.name = 'Срок';
  wrap(setText(line, 'text', words));
  try { line.counterAxisAlignItems = 'MIN'; } catch (e) { bridge.log('status align: ' + e.message); }
  return line;
}

// «Готово» on a plan: a ring (line-strong) with a tick (primary), 44.
function doneRing() {
  return box({ name: 'done', dir: 'H', w: 44, h: 44, radius: FULL(), stroke: 'line-strong', strokeW: 2,
    align: 'center', justify: 'center' }, [icon('check', 24, 'primary', true)]);
}

// One plan (PlanRow): kind icon, title, when it is due, how often and the last time, «Готово».
async function planRow(glyph, title, status, due, facts) {
  return box({ name: 'План · ' + title, dir: 'H', w: 'fill', pad: [12, 8, 12, 16], gap: 8 }, [
    box({ name: 'main', dir: 'H', w: 'fill', gap: 12 }, [
      kindDisc(glyph),
      box({ name: 'texts', dir: 'V', w: 'fill', gap: 4 }, [
        await text(title, 'subtitle', 'ink', { name: 'title', w: 'fill', lines: 2 }),
        box({ name: 'when', dir: 'V', w: 'fill' }, [
          await dueLine(status, due),
          await text(facts, 'body-sm', 'ink-muted', { name: 'facts', w: 'fill' }),
        ]),
      ]),
    ]),
    doneRing(),
  ]);
}

// A status group: its muted title, then the plans in a card.
async function planGroup(title, plans) {
  const rows = [];
  for (const plan of plans) {
    if (rows.length) rows.push(divider(68));
    rows.push(await planRow(...plan));
  }
  return box({ name: 'Группа · ' + title, dir: 'V', w: 'fill', gap: 8, pad: [0, 0, 16, 0] }, [
    await text(title, 'label', 'ink-muted', { name: 'title' }),
    card(rows, { name: 'Планы · ' + title }),
  ]);
}

const last = (often, date) => often + ' · Последний раз ' + nb(date);
const plans = section('План ухода',
  await head('План ухода', await linkButton('add', 'Добавить план', true)),
  box({ name: 'groups', dir: 'V', w: 'fill' }, [
    await planGroup('Просрочено', [['vaccines', 'Бешенство', 'Overdue',
      'Просрочено на 3 дня · ' + nb('29 сент. 2026 г.'), last('Раз в год', '29 сент. 2025 г.')]]),
    await planGroup('Скоро', [['medical_services', 'Осмотр у ветеринара', 'Soon',
      'Завтра · ' + nb('3 окт. 2026 г.'), last('Раз в год', '3 окт. 2025 г.')]]),
    await planGroup('По плану', [
      ['pest_control', 'Блохи и клещи', 'Planned', 'Через 25 дней · ' + nb('27 окт. 2026 г.'),
        last('Раз в месяц', '27 сент. 2026 г.')],
      ['medication', 'Обработка от глистов', 'Planned', 'Через 47 дней · ' + nb('18 нояб. 2026 г.'),
        last('Раз в 3 месяца', '18 авг. 2026 г.')],
      ['vaccines', 'Комплексная прививка', 'Planned', 'Через 12 месяцев · ' + nb('10 окт. 2027 г.'),
        last('Раз в 3 года', '10 окт. 2024 г.')],
    ]),
  ]));

// History: kind filter chips and the records (List row; a photo icon when it has photos).
const chips = [];
for (const [label, on] of [['Все', true], ['Прививка'], ['Обработка от глистов'], ['Блохи и клещи'], ['Осмотр']]) {
  chips.push(await inst('Chip', { Selected: on ? 'On' : 'Off' }, { Label: label }));
}
// Rows 56 apart, like the app's chips with their 48 tap area: 36 + 20.
const filter = box({ name: 'Фильтр', dir: 'H', w: 358, gap: 8, pad: [6, 0, 6, 0] }, chips);
filter.layoutWrap = 'WRAP';
bindNum(filter, 'counterAxisSpacing', 20, 'space-');
sized(filter, 'fill');

async function recordRow(glyph, title, sub, photo) {
  const row = sized(await inst('List row', { Leading: 'Icon', Trailing: photo ? 'None' : 'Chevron' },
    { Title: title, Subtitle: sub }), 'fill');
  setText(row, 'icon/vaccines', glyph);
  row.name = 'Запись · ' + title;
  if (!photo) return row;
  return box({ name: 'Запись · ' + title, dir: 'H', w: 'fill', pad: [0, 16, 0, 0], align: 'center' },
    [row, icon('photo', 18, 'ink-muted'), icon('chevron_right', 24, 'ink-muted', true)]);
}
const records = [
  ['pest_control', 'Блохи и клещи', nb('27 сент. 2026 г.') + ' · Frontline Combo'],
  ['medication', 'Обработка от глистов', nb('18 авг. 2026 г.') + ' · Мильбемакс'],
  ['medical_services', 'Осмотр у ветеринара', nb('3 окт. 2025 г.')],
  ['vaccines', 'Бешенство', nb('29 сент. 2025 г., 11:15') + ' · Nobivac Rabies', true],
  ['vaccines', 'Комплексная прививка', nb('10 окт. 2024 г.') + ' · Nobivac Tricat Trio'],
];
const recordRows = [];
for (const record of records) {
  if (recordRows.length) recordRows.push(divider(68));
  recordRows.push(await recordRow(...record));
}
const history = section('История',
  await head('История', [iconButton('document_scanner'), await linkButton('add', 'Добавить запись', true)]),
  box({ name: 'records', dir: 'V', w: 'fill', gap: 12 }, [filter, card(recordRows, { name: 'Записи' })]));

const health = await petPage('Питомец — здоровье', 'Health',
  box({ name: 'content', dir: 'V', w: 'fill', pad: [16, 16, 48, 16], gap: 32 }, [plans, history]));
await place(AREA, 1, health, '04_pet_2_health_full.png');
return { health: health.id };
