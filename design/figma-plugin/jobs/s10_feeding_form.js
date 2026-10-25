// Screens: Feeding schedule form, new and edit (10_feeding_form_new_full, 10_feeding_form_edit_full).
await cbSetup();
const AREA = '10 Кормление';
const FULL = CB.numValue['radius-full'];
const byName = (root, name) => root.findOne((n) => n.name === name);

// Sets a component property (text, boolean or variant) by its short name.
function prop(node, short, value) {
  const key = Object.keys(node.componentProperties).find((k) => k.split('#')[0] === short);
  node.setProperties({ [key]: value });
  return node;
}

// The App bar, its title ending 16 before the actions as in the app (long titles cut).
async function appBar(title) {
  const bar = await inst('App bar', { Actions: 'None' }, { Title: title });
  bar.name = 'App bar';
  bar.resize(PHONE_W, 56);
  bindNum(bar.findOne((n) => n.name === 'title wrap'), 'paddingRight', 16, 'space-'); // the app's 16 before actions
  const titleText = bar.findOne((n) => n.name === 'title');
  titleText.maxLines = 1; // one line, cut with …
  titleText.textTruncation = 'ENDING';
  return bar;
}

// Puts a value (ink) or a hint (ink-muted) into a Text field; long values wrap.
function setValue(f, value, hint) {
  prop(f, 'Value', value || hint || '');
  const v = byName(f, 'value');
  v.fills = [paint(value ? 'ink' : 'ink-muted')];
  v.textAutoResize = 'HEIGHT';
  try {
    v.layoutSizingHorizontal = 'FILL';
  } catch (e) { // if an instance refuses it: a fixed width that wraps
    const row = v.parent;
    v.resize(row.width - row.paddingLeft - row.paddingRight, v.height);
    bridge.log('fixed width for ' + f.name + ': ' + e.message);
  }
  return f;
}
async function field(label, value, hint) {
  const f = await inst('Text field', { State: 'Default' }, { Label: label, 'Show hint': false });
  f.name = label;
  return sized(setValue(f, value, hint), 'fill');
}

// A label above chips (or any control), like the app's CbLabeled.
async function labeled(label, child) {
  return box({ name: label, dir: 'V', gap: 8, w: 'fill' }, [await text(label, 'label', 'ink', { name: 'label' }), child]);
}

// Chips in rows like the app's Wrap: 48-high rows 8 apart, so 36-high chips
// get 6 above and below and 20 between rows.
function wrap(name, children) {
  const f = box({ name, dir: 'H', w: 358, gap: 8, pad: [6, 0, 6, 0] }, children);
  f.layoutWrap = 'WRAP';
  bindNum(f, 'counterAxisSpacing', 20, 'space-');
  return sized(f, 'fill');
}

// Chips in fixed rows, as the app lays them out: the Chip component is narrower
// than the app's chips, so a wrap would fit more chips into the first row.
function chipRows(name, groups) {
  return box({ name, dir: 'V', gap: 20, pad: [6, 0, 6, 0], w: 'fill' },
    groups.map((g, i) => box({ name: 'ряд ' + (i + 1), dir: 'H', gap: 8 }, g)));
}

// A chosen day (Chip): a check before the label.
async function dayChip(label) {
  const c = await inst('Chip', { Selected: 'On' }, { Label: label });
  c.name = label;
  return c;
}

// A chip with an icon (Chip has none): «+ Добавить время», or a time with ×.
async function iconChip(label, lead, trail) {
  return box({ name: label, dir: 'H', h: 36, pad: [0, 16], gap: 16, align: 'center', radius: FULL, fill: 'surface',
    stroke: 'line-strong' }, [lead && icon(lead, 18, 'primary', true), await text(label, 'label', 'ink', { name: 'label' }),
    trail && icon(trail, 18, 'ink-muted', true)]);
}

// The unit switch (a segmented button; no component for it): «г» chosen.
async function units() {
  const segments = [];
  for (const [i, label] of ['г', 'мл', 'шт.'].entries()) {
    segments.push(box({ name: label, dir: 'H', h: 40, w: 'fill', align: 'center', justify: 'center',
      fill: i ? 'surface' : 'primary-soft', stroke: i ? 'line-strong' : null, strokeSides: i ? { left: 1 } : null },
    [await text(label, 'label', i ? 'ink' : 'primary', { name: 'label' })]));
  }
  return sized(box({ name: 'Единица', dir: 'H', h: 40, radius: FULL, stroke: 'line-strong', clip: true }, segments), 'fill');
}

// The app's Switch is 60 wide with the track 4 in from the end: text column 282.
function appSwitch(row) {
  bindNum(row, 'paddingRight', 4, 'space-');
  bindNum(row.findOne((n) => n.name === 'texts'), 'paddingRight', 4, 'space-');
  return row;
}

// A long screen: hugs its content, and grows to the app's screenshot height.
function fitTo(frame, h) {
  const content = frame.findChild((n) => n.name === 'content');
  content.layoutGrow = 0;
  frame.primaryAxisSizingMode = 'AUTO';
  if (frame.height < h) {
    content.layoutGrow = 1;
    frame.resize(PHONE_W, h);
  }
  return frame;
}

// --- Feeding form: new ---
const days = [];
for (const day of ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс']) days.push(await dayChip(day));
// The food from supplies: the dropdown shows its choice in subtitle (Material's default).
const supply = await inst('Select field', {}, { Label: 'Корм из запасов', Value: 'Не из запасов', 'Show icon': false });
supply.name = 'Корм из запасов · список';
await byName(supply, 'value').setTextStyleIdAsync(CB.text.subtitle.id);
const amount = await inst('Text field', { State: 'Default' }, { Label: 'Порция', 'Show hint': false });
amount.name = 'Количество';
byName(amount, 'label').visible = false;
setValue(amount, '', '40');
amount.resize(112, 48);
const notice = await inst('Notice', { Kind: 'Info' });
notice.name = 'Напоминание';
setText(notice, 'message', 'В это время на телефоны семьи придёт напоминание. Выключить напоминания о кормлении можно в «Ещё → Уведомления».');
const form = fitTo(screen('Кормление — новое расписание', [
  await appBar('Новое расписание'),
  box({ name: 'content', dir: 'V', pad: [16, 16, 48, 16], gap: 20, w: 'fill' }, [
    await labeled('Время', wrap('Время · чипы', [await iconChip('Добавить время', 'add')])),
    await labeled('Дни', chipRows('Дни · чипы', [days.slice(0, 4), days.slice(4)])),
    box({ name: 'Корм из запасов', dir: 'V', gap: 4, w: 'fill' }, [sized(supply, 'fill'),
      await text('Порции этого кормления будут считаться расходом корма в запасах', 'caption', 'ink-muted',
        { w: 'fill', name: 'helper' })]),
    await field('Корм', '', 'Например, Royal Canin Sterilised'),
    await labeled('Порция', box({ name: 'Порция · поля', dir: 'H', gap: 8, align: 'center', w: 'fill' }, [amount, await units()])),
    await field('Заметки', ''),
    sized(notice, 'fill'),
  ]),
  sized(await inst('Save bar'), 'fill'),
  await inst('Bottom navigation', { Tab: 'Pets' }),
]), 1060);
await place(AREA, 0, form, '10_feeding_form_new_full.png');

// --- Feeding form: edit (a copy of the new form with the schedule filled in) ---
const edit = form.clone();
edit.name = 'Кормление — изменение';
const bar = prop(byName(edit, 'App bar'), 'Actions', 'Menu');
bar.resize(PHONE_W, 56);
bindNum(byName(bar, 'title wrap'), 'paddingRight', 16, 'space-');
prop(bar, 'Title', 'Изменить кормление');
const trash = byName(bar, 'icon/more_vert'); // the app bar's one action here: delete, in danger
trash.characters = 'delete_outline';
trash.fills = [paint('danger')];
const times = byName(edit, 'Время · чипы');
times.insertChild(0, await iconChip('8:00', null, 'close'));
times.insertChild(1, await iconChip('19:00', null, 'close'));
prop(byName(edit, 'Корм из запасов · список'), 'Value', 'Royal Canin Sterilised 37');
byName(edit, 'Корм').remove(); // a food from supplies needs no name
// The app keeps the removed field's gap: 40 above «Порция».
byName(edit, 'Порция').setBoundVariable('paddingTop', CB.num['space-5']);
setValue(byName(edit, 'Количество'), '40');
for (const unit of ['мл', 'шт.']) byName(byName(edit, unit), 'label').fills = [paint('ink-disabled')];
setValue(byName(edit, 'Заметки'), 'Вечером можно добавить ложку влажного корма.');
const active = await inst('Switch row', { Value: 'On' }, { Title: 'Действует',
  Subtitle: 'Расписание на паузе не напоминает и не показывается на «Сегодня».' });
active.name = 'Действует';
appSwitch(active);
const content = edit.findChild((n) => n.name === 'content');
content.insertChild(content.children.indexOf(byName(content, 'Напоминание')), active);
active.layoutSizingHorizontal = 'FILL';
fitTo(edit, 1174);
await place(AREA, 1, edit, '10_feeding_form_edit_full.png');
return { form: form.id, edit: edit.id };
