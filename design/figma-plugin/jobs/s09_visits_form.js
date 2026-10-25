// Screens: Visit form, new and edit (09_visits_form_new_full, 09_visits_form_edit_full).
await cbSetup();
const AREA = '09 Визиты';
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
  const words = value || hint || '';
  if (f.type === 'INSTANCE') prop(f, 'Value', words);
  else byName(f, 'value').characters = words;
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

// A Text field. `trail`: an icon at the end (date and time). The component has
// no icon slot, so such a field is a detached Text field.
async function field(label, value, hint, trail) {
  let f = await inst('Text field', { State: 'Default' }, { Label: label, 'Show hint': false });
  if (trail) f = f.detachInstance();
  f.name = label;
  setValue(f, value, hint);
  if (trail) {
    const row = byName(f, 'field');
    add(row, icon(trail, 24, 'ink-muted', trail === 'close' || trail === 'schedule'));
    row.setBoundVariable('paddingRight', CB.num['space-3']);
  }
  return sized(f, 'fill');
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

// A filter chip (Chip): when on, a check before the label.
async function chip(label, on) {
  const c = await inst('Chip', { Selected: on ? 'On' : 'Off' }, { Label: label });
  c.name = label;
  return c;
}

// A visit type chip with its icon (Chip has no icon). Chosen: mint, the icon
// under a grey disc with a check, the label in primary.
async function typeChip(glyph, label, on, filled) {
  let lead = icon(glyph, 18, 'primary', filled);
  if (on) {
    lead = box({ name: 'avatar', dir: 'none', w: 30, h: 30, radius: FULL, fill: 'ink-disabled' });
    const a = icon(glyph, 18, 'ink', filled);
    const b = icon('check', 24, 'primary', true);
    lead.appendChild(a);
    a.x = 6;
    a.y = 6;
    lead.appendChild(b);
    b.x = 3;
    b.y = 3;
  }
  return box({ name: label, dir: 'H', h: 36, pad: on ? [0, 16, 0, 10] : [0, 16], gap: on ? 8 : 16, align: 'center',
    radius: FULL, fill: on ? 'primary-soft' : 'surface', stroke: on ? null : 'line-strong' }, [
    lead, await text(label, 'label', on ? 'primary' : 'ink', { name: 'label' })]);
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

// --- Visit form: new ---
const types = [await typeChip('local_hospital', 'Ветеринар', true), await typeChip('content_cut', 'Грумер', false, true),
  await typeChip('sports', 'Дрессировка'), await typeChip('event', 'Другое')];
const pets = [await chip('Барсик'), await chip('Мурка'), await chip('Рекс')];
const reminders = [await chip('За неделю'), await chip('За сутки', true), await chip('За 2 часа', true), await chip('За час')];
const form = fitTo(screen('Визит — новый', [
  await appBar('Новый визит'),
  box({ name: 'content', dir: 'V', pad: [16, 16, 48, 16], gap: 20, w: 'fill' }, [
    await labeled('Куда', wrap('Куда · чипы', types)),
    await field('Зачем', '', 'Например, прививка от бешенства'),
    await field('Дата', '', 'Не указана', 'calendar_today'),
    await field('Время', '', 'Не указано', 'schedule'),
    await labeled('Питомцы', wrap('Питомцы · чипы', pets)),
    await field('Где', '', 'Клиника или адрес'),
    await labeled('Напомнить', chipRows('Напомнить · чипы', [reminders.slice(0, 2), reminders.slice(2)])),
    await field('Заметки', ''),
  ]),
  sized(await inst('Save bar'), 'fill'),
  await inst('Bottom navigation', { Tab: 'Today' }),
]), 1128);
await place(AREA, 1, form, '09_visits_form_new_full.png');

// --- Visit form: edit (a copy of the new form with the visit filled in) ---
const edit = form.clone();
edit.name = 'Визит — изменение';
prop(byName(edit, 'App bar'), 'Title', 'Изменить визит');
setValue(byName(edit, 'Зачем'), 'Осмотр и прививка от бешенства');
setValue(byName(edit, 'Дата'), '3 окт. 2026 г.'); // a visit always has a date: no clear button
const time = setValue(byName(edit, 'Время'), '10:30');
const clock = byName(time, 'icon/schedule');
clock.characters = 'close';
clock.name = 'icon/close';
prop(byName(edit, 'Мурка'), 'Selected', 'On');
setValue(byName(edit, 'Где'), 'Ветклиника «Айболит», ул. Лесная, 12');
setValue(byName(edit, 'Заметки'), 'Взять ветпаспорт. Не кормить за 2 часа до приёма.');
fitTo(edit, 1152);
await place(AREA, 2, edit, '09_visits_form_edit_full.png');
return { form: form.id, edit: edit.id };
