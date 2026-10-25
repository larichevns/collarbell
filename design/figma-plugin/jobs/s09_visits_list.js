// Screens: Visits list, Visit detail (tomorrow, on the day) and the
// «Как прошёл визит?» sheet (09_visits_list, _detail, _detail_on_the_day, _took_place_sheet).
await cbSetup();
const AREA = '09 Визиты';
const FULL = CB.numValue['radius-full'];
const byName = (root, name) => root.findOne((n) => n.name === name);

// The App bar, its title ending 16 before the actions as in the app (long titles cut).
async function appBar(title, actions) {
  const bar = await inst('App bar', { Actions: actions || 'None' }, { Title: title });
  bar.name = 'App bar';
  bar.resize(PHONE_W, 56);
  bindNum(bar.findOne((n) => n.name === 'title wrap'), 'paddingRight', 16, 'space-'); // the app's 16 before actions
  const titleText = bar.findOne((n) => n.name === 'title');
  titleText.maxLines = 1; // one line, cut with …
  titleText.textTruncation = 'ENDING';
  return bar;
}

// A titled block: Section header (44 high, like the app's) and the content under it.
async function section(title, child) {
  const h = await inst('Section header', { Style: 'Title' }, { Title: title, 'Show action': false });
  h.name = 'Section header';
  return box({ name: title, dir: 'V', gap: 8, w: 'fill' }, [sized(h, 'fill'), child]);
}

// One visit in a list: type icon, title, when, pets and a chevron. Built here:
// List row has no bare leading icon and no third line.
async function visitRow(glyph, filled, color, title, when, pets) {
  return box({ name: title, dir: 'H', pad: 16, gap: 12, w: 'fill' }, [
    icon(glyph, 24, color, filled),
    box({ name: 'texts', dir: 'V', w: 'fill' }, [
      await text(title, 'subtitle', 'ink', { w: 'fill', name: 'title' }),
      await text(when, 'body-sm', 'ink-muted', { w: 'fill', name: 'when' }),
      await text(pets, 'body-sm', 'ink', { w: 'fill', name: 'pets', lines: 1 }),
    ]),
    icon('chevron_right', 24, 'ink', true),
  ]);
}

// One fact in a details card: a muted caption above its value.
async function detailRow(label, value) {
  return box({ name: label, dir: 'V', gap: 4, pad: [8, 0], w: 'fill' }, [
    await text(label, 'caption', 'ink-muted', { w: 'fill', name: 'label' }),
    await text(value, 'body', 'ink', { w: 'fill', name: 'value' })]);
}

// The app's Switch is 60 wide with the track 4 in from the end: text column 282.
function appSwitch(row) {
  bindNum(row, 'paddingRight', 4, 'space-');
  bindNum(row.findOne((n) => n.name === 'texts'), 'paddingRight', 4, 'space-');
  return row;
}

// --- Visits list ---
const fab = await inst('FAB', {}, { Label: 'Записать визит' });
const list = fitScreen(screen('Визиты — список', [
  await appBar('Визиты'),
  box({ name: 'content', dir: 'V', pad: 16, gap: 24, w: 'fill' }, [
    await section('Запланированные', card([await visitRow('local_hospital', false, 'primary',
      'Осмотр и прививка от бешенства', 'Завтра в 10:30', 'Мурка')])),
    await section('Прошедшие и отменённые', card([await visitRow('content_cut', true, 'ink-muted',
      'Груминг', 'сб, 12 сент. в 15:00 · Состоялся', 'Барсик')])),
  ]),
  await inst('Bottom navigation', { Tab: 'Today' }),
]));
float(list, fab, { right: 16, bottom: 96 });
await place(AREA, 0, list, '09_visits_list.png');

// --- Visit detail: a card with the facts; on the day, «Визит состоялся» under it ---
async function visitDetail(name, when, done) {
  const kids = [
    await appBar('Осмотр и прививка от бешенства', 'Edit + Menu'),
    box({ name: 'content', dir: 'V', pad: 16, w: 'fill' }, [card([
      box({ name: 'Куда', dir: 'H', gap: 12, pad: [0, 0, 8, 0], align: 'center', w: 'fill' }, [
        icon('local_hospital', 24, 'primary'), await text('Ветеринар', 'body-sm', 'ink-muted', { w: 'fill', name: 'type' })]),
      await text(when, 'subtitle', 'ink', { w: 'fill', name: 'Когда' }),
      await detailRow('Питомцы', 'Мурка'),
      await detailRow('Где', 'Ветклиника «Айболит», ул. Лесная, 12'),
      await detailRow('Напомнить', 'За сутки, За 2 часа'),
      await detailRow('Заметки', 'Взять ветпаспорт. Не кормить за 2 часа до приёма.'),
    ], { pad: 16 })]),
  ];
  if (done) {
    // A filled button with an icon: built here, Button has no icon.
    kids.push(box({ name: 'Визит состоялся', dir: 'V', pad: 16, w: 'fill' }, [
      box({ name: 'Button · Визит состоялся', dir: 'H', h: 52, w: 'fill', pad: [0, 20], gap: 8, align: 'center',
        justify: 'center', radius: FULL, fill: 'primary' }, [
        icon('check', 18, 'on-primary', true), await text('Визит состоялся', 'label', 'on-primary', { name: 'label' })]),
    ]));
  }
  kids.push(await inst('Bottom navigation', { Tab: 'Today' }));
  return fitScreen(screen(name, kids));
}
await place(AREA, 3, await visitDetail('Визит — карточка', 'Завтра в 10:30'), '09_visits_detail.png');
const day = await visitDetail('Визит — в день визита', 'Сегодня в 10:30', true);
await place(AREA, 4, day, '09_visits_detail_on_the_day.png');

// --- «Как прошёл визит?»: the sheet over the on-the-day detail, above the bottom menu ---
async function chip(label, on, color) {
  const c = await inst('Chip', { Selected: on ? 'On' : 'Off' }, { Label: label });
  c.name = label;
  if (on && color) byName(c, 'label').fills = [paint(color)];
  return c;
}
// Chips in the app's rows (48 high, 8 apart, so 20 between 36-high chips). Fixed
// rows: the Chip component is narrower than the app's chips, and a wrap would
// fit a third chip into the first row.
function chipRows(name, groups, pad) {
  return box({ name, dir: 'V', gap: 20, pad, w: 'fill' }, groups.map((g, i) => box({ name: 'ряд ' + (i + 1), dir: 'H', gap: 8 }, g)));
}
const kinds = [];
for (const [label, on] of [['Осмотр', true], ['Уход за зубами'], ['Груминг'], ['Процедура'], ['Другое']]) {
  kinds.push(await chip(label, on, on ? 'primary' : null)); // a single choice: the chosen label is primary
}
// A checked checkbox (no component for it).
const checkbox = box({ name: 'Checkbox', dir: 'H', w: 40, h: 40, align: 'center', justify: 'center' }, [
  box({ name: 'box', dir: 'H', w: 18, h: 18, radius: 2, fill: 'primary', align: 'center', justify: 'center' },
    [icon('check', 16, 'on-primary', true)])]);
const notes = await inst('Text field', { State: 'Default' }, { Label: 'Заметки', Value: 'Что сказал врач', 'Show hint': false });
byName(notes, 'value').fills = [paint('ink-muted')];
const doneButton = await inst('Button', { Style: 'Primary', State: 'Default' }, { Label: 'Визит состоялся' });
doneButton.resize(doneButton.width, CB.numValue['control-lg']);
const sheetContent = box({ name: 'content', dir: 'V', w: 'fill' }, [
  sized(appSwitch(await inst('Switch row', { Value: 'On' }, { Title: 'Записать в историю ухода',
    Subtitle: 'У каждого питомца визита появится запись этого вида.' })), 'fill'),
  chipRows('Вид записи', [kinds.slice(0, 2), kinds.slice(2)], [14, 0, 6, 0]),
  box({ name: 'Отметить план', dir: 'H', gap: 16, pad: [12, 0], align: 'center', w: 'fill' }, [
    box({ name: 'texts', dir: 'V', w: 'fill' }, [
      await text('Отметить «Осмотр у ветеринара» выполненным', 'body', 'ink', { w: 'fill', name: 'title' }),
      await text('Мурка', 'body-sm', 'ink-muted', { w: 'fill', name: 'subtitle' })]),
    checkbox]),
  box({ name: 'Заметки', dir: 'V', pad: [12, 0, 0, 0], w: 'fill' }, [sized(notes, 'fill')]),
  box({ name: 'Кнопка', dir: 'V', pad: [16, 0, 0, 0], w: 'fill' }, [sized(doneButton, 'fill')]),
]);

const took = day.clone();
took.name = 'Визит — как прошёл';
const dim = scrim(took); // over the screen, not the bottom menu
dim.resize(PHONE_W, took.height - 80);
const sheet = (await inst('Bottom sheet', {}, { Title: 'Как прошёл визит?' })).detachInstance();
sheet.name = 'Как прошёл визит?';
byName(sheet, 'handle area').visible = false; // the sheet can't be dragged: no handle
const body = byName(sheet, 'body');
body.setBoundVariable('itemSpacing', CB.num['space-2']);
const slot = byName(body, 'content');
body.insertChild(body.children.indexOf(slot), sheetContent);
sheetContent.layoutSizingHorizontal = 'FILL';
slot.remove();
float(took, sheet, { left: 0, bottom: 80 });
await place(AREA, 5, took, '09_visits_took_place_sheet.png');
return { list: list.id, day: day.id, took: took.id };
