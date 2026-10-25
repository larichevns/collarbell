// _pet_kit.js: helpers for the pet page (s04), pet form (s05) and passport form (s07).
// Run as: bridge.py run jobs/_screens.js jobs/_pet_kit.js jobs/s0N_….js

const FULL = () => CB.numValue['radius-full'];
// Keeps a date or a count on one line ("29 сент. 2026 г."), as the app does.
const nb = (s) => s.replace(/ /g, '\u00A0');

// Sets a component property of an instance by its short name.
function setProp(node, short, value) {
  const key = Object.keys(node.componentProperties).find((k) => k.split('#')[0] === short);
  if (!key) throw new Error(node.name + ': no property ' + short);
  node.setProperties({ [key]: value });
  return node;
}

// Sets a node's fill to a colour token. Skipped when the fill already uses that
// token: re-binding the same variable shows paint()'s raw black instead.
function recolor(node, color) {
  const bound = node.fills.length && node.fills[0].boundVariables && node.fills[0].boundVariables.color;
  if (!bound || bound.id !== CB.color[color].id) node.fills = [paint(color)];
  return node;
}

// Recolours a text layer inside an instance.
function tint(node, layerName, color) {
  const t = node.findOne((n) => n.type === 'TEXT' && n.name === layerName);
  if (!t) throw new Error('no text layer ' + layerName);
  return recolor(t, color);
}

// Lets a text inside an instance wrap at its parent's width.
function wrap(t) {
  try { t.layoutSizingHorizontal = 'FILL'; t.textAutoResize = 'HEIGHT'; } catch (e) { bridge.log('wrap: ' + e.message); }
  return t;
}

// Borders drawn over the edge, as in the app: a card's line border takes no
// layout space (Figma counts strokes in auto layout by default).
function strokesOutside(root) {
  const walk = (n) => {
    if (n.type === 'INSTANCE') return;
    if (n.type === 'FRAME' && n.layoutMode !== 'NONE' && n.strokes.length) n.strokesIncludedInLayout = false;
    if ('children' in n) n.children.forEach(walk);
  };
  walk(root);
  return root;
}

// The pet's page: App bar «Мурка» with Edit + Menu, the tabs, the tab's content.
async function petPage(name, tab, content) {
  return fitScreen(strokesOutside(screen(name, [
    await inst('App bar', { Actions: 'Edit + Menu' }, { Title: 'Мурка' }),
    sized(await inst('Tab bar', { Tab: tab }), 'fill'),
    content,
    await inst('Bottom navigation', { Tab: 'Pets' }),
  ])));
}

// A form screen: App bar without actions, the fields, Save bar, the menu.
async function formPage(name, title, content) {
  return fitScreen(strokesOutside(screen(name, [
    await inst('App bar', { Actions: 'None' }, { Title: title }),
    content,
    await inst('Save bar'),
    await inst('Bottom navigation', { Tab: 'Pets' }),
  ])));
}

// For a ref taller than Figma's 4096 px image limit: places the frame with the
// ref scaled to fit (<name>_fit.png, made with magick -resize x4096).
async function placeTall(area, slot, frame, refName) {
  return place(area, slot, frame, refName.replace('.png', '_fit.png'));
}

// The title row of a section: the Section header component with its own text
// action ('Изменить'), or with local icon buttons beside it. With an action
// the row is 48 high (the button's tap area), else 44.
async function head(title, action) {
  const own = typeof action === 'string';
  const header = sized(await inst('Section header', { Style: 'Title' },
    { Title: title, 'Show action': own }), 'fill');
  if (own) setProp(header.findOne((n) => n.type === 'INSTANCE' && n.name === 'action'), 'Label', action);
  const extra = own || !action ? [] : [].concat(action);
  const row = box({ name: 'Заголовок · ' + title, dir: 'H', w: 'fill', align: 'center' }, [header, ...extra]);
  try { row.minHeight = action ? 48 : 44; } catch (e) { bridge.log('minHeight: ' + e.message); }
  return row;
}

// A long title with its text action under it (the app's OverflowBar): the
// title hugs its text here, without the header's 44 min height.
async function headBelow(title, action) {
  const header = sized(await inst('Section header', { Style: 'Title' },
    { Title: title, 'Show action': false }), 'fill');
  try { header.minHeight = null; } catch (e) { bridge.log('header minHeight: ' + e.message); }
  const button = await inst('Button', { Style: 'Text', State: 'Default' }, { Label: action });
  return box({ name: 'Заголовок · ' + title, dir: 'V', w: 'fill' },
    [header, box({ name: 'tap', dir: 'H', pad: [2, 0, 2, 0] }, [button])]);
}

// A titled block: title row, 8, content.
function section(name, ...children) {
  return box({ name, dir: 'V', w: 'fill', gap: 8 }, children);
}

// A text button with an icon (TextButton.icon): primary, 48 high.
async function linkButton(glyph, label, filled) {
  return box({ name: 'Кнопка · ' + label, dir: 'H', h: 48, pad: [0, 12, 0, 12], gap: 8, align: 'center' },
    [icon(glyph, 18, 'primary', filled), await text(label, 'label', 'primary', { name: 'label' })]);
}

// An outlined pill with an icon (OutlinedButton.icon), with its tap margin.
async function outlineButton(glyph, label, filled, full) {
  const pill = box({ name: 'pill', dir: 'H', h: 44, w: full ? 'fill' : undefined, pad: [0, 20, 0, 20], gap: 8,
    align: 'center', justify: 'center', radius: FULL(), stroke: 'line-strong' },
  [icon(glyph, 18, 'ink', filled), await text(label, 'label', 'ink', { name: 'label' })]);
  return box({ name: 'Кнопка · ' + label, dir: 'H', w: full ? 'fill' : undefined, pad: [2, 0, 2, 0] }, [pill]);
}

// An icon button: a 48 tap area with a 24 icon.
function iconButton(glyph, color, filled) {
  return box({ name: 'Кнопка · ' + glyph, dir: 'H', w: 48, h: 48, align: 'center', justify: 'center' },
    [icon(glyph, 24, color || 'ink-muted', filled)]);
}

// The kind of care on a grey disc (KindIcon).
function kindDisc(glyph) {
  return box({ name: 'icon disc', dir: 'H', w: 40, h: 40, radius: FULL(), fill: 'sunken',
    align: 'center', justify: 'center' }, [icon(glyph, 22, 'ink-muted')]);
}

// One fact of a details card: muted caption above the value (CbDetailRow).
async function detail(label, value, mono) {
  return box({ name: 'Строка · ' + label, dir: 'V', w: 'fill', pad: [8, 0, 8, 0], gap: 4 }, [
    await text(label, 'caption', 'ink-muted', { name: 'label', w: 'fill' }),
    await text(value, mono ? 'code' : 'body', 'ink', { name: 'value', w: 'fill' }),
  ]);
}

async function detailsCard(name, rows) {
  const items = [];
  for (const [label, value, mono] of rows) items.push(await detail(label, value, mono));
  return card(items, { name, pad: 16 });
}

// A muted line in a card, e.g. «Записей пока нет.».
async function mutedCard(words) {
  return card([await text(words, 'body', 'ink-muted', { w: 'fill' })], { name: 'Пусто', pad: 16 });
}

// The pet's photo slot: the avatar, 128 (Pet avatar 64 scaled ×2).
async function bigAvatar(coat, letter) {
  const a = await inst('Pet avatar', { Size: '64', Coat: coat }, { Initial: letter });
  a.name = 'Аватар';
  for (const side of ['width', 'height']) try { a.setBoundVariable(side, null); } catch (e) { /* not bound */ }
  try { a.rescale(2); if (Math.round(a.width) === 128) return a; } catch (e) { bridge.log('rescale: ' + e.message); }
  a.remove(); // Fallback: a local circle.
  const initial = await text(letter, 'numeral', 'on-coat', { name: 'initial' });
  initial.fontSize = 58;
  initial.lineHeight = { unit: 'PERCENT', value: 100 };
  return box({ name: 'Аватар', dir: 'H', w: 128, h: 128, radius: FULL(), fill: 'coat-' + coat.toLowerCase(),
    align: 'center', justify: 'center' }, [initial]);
}

// The avatar with «Добавить фото» under it.
async function photoSlot(coat, letter) {
  return box({ name: 'Фото', dir: 'V', w: 'fill', gap: 8, align: 'center' },
    [await bigAvatar(coat, letter), await linkButton('photo_camera', 'Добавить фото')]);
}

// A text field (Text field component). An empty value shows the hint, in the
// component's own ink-muted (re-setting the same colour as an override renders black).
async function field(label, value, opts) {
  opts = opts || {};
  const f = sized(await inst('Text field', { State: 'Default' },
    { Label: label, Value: value || opts.hint || ' ', 'Show hint': !!opts.help }), 'fill');
  f.name = 'Поле · ' + label;
  const v = value ? tint(f, 'value', 'ink') : f.findOne((n) => n.type === 'TEXT' && n.name === 'value');
  if (opts.mono) await v.setTextStyleIdAsync(CB.text.code.id);
  if (opts.help) setText(f, 'hint', opts.help);
  if (opts.wrap) wrap(v);
  return f;
}

// A field picked from a list (Select field), e.g. «Образец паспорта».
async function selectField(label, value) {
  const f = sized(await inst('Select field', {}, { Label: label, Value: value, 'Show icon': false }), 'fill');
  f.name = 'Выбор · ' + label;
  return f;
}

// A date field: Select field with the calendar icon, or a date with «×».
async function dateField(label, value) {
  const f = sized(await inst('Select field', {}, { Label: label, Value: value || 'Не указана', 'Show icon': false }), 'fill');
  f.name = 'Дата · ' + label;
  if (!value) tint(f, 'value', 'ink-muted');
  setDateIcon(f, !!value);
  return f;
}

function setDateIcon(f, filled) {
  const g = f.findOne((n) => n.type === 'TEXT' && n.name.startsWith('icon/') && n.name !== 'icon');
  try { g.fontName = filled ? ICON_FILLED : ICON_OUTLINED; } catch (e) { bridge.log('icon font: ' + e.message); }
  g.characters = filled ? 'close' : 'calendar_today';
  try { g.name = filled ? 'icon/close' : 'icon/calendar_today'; } catch (e) { /* keeps its name */ }
}

// A switch row without a subtitle (SwitchListTile).
async function switchRow(title, on) {
  const r = sized(await inst('Switch row', { Value: on ? 'On' : 'Off' }, { Title: title, 'Show subtitle': false }), 'fill');
  r.name = 'Переключатель · ' + title;
  return r;
}

// A label above any control (CbLabeled), with an optional muted line under it.
async function labeled(label, control, helper) {
  const under = helper ? box({ name: 'control', dir: 'V', w: 'fill', gap: 4 },
    [control, await text(helper, 'caption', 'ink-muted', { name: 'helper', w: 'fill' })]) : control;
  return box({ name: 'Поле · ' + label, dir: 'V', w: 'fill', gap: 8 },
    [await text(label, 'label', 'ink', { name: 'label', w: 'fill' }), under]);
}

// A bordered block inside a form (identifier, owner): line border, radius md, pad 12.
function formBlock(name, gap, children) {
  return box({ name, dir: 'V', w: 'fill', pad: 12, gap, radius: CB.numValue['radius-md'], stroke: 'line' }, children);
}
