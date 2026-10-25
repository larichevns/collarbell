// s06_care_kit.js: helpers for the «06 Уход» screens (jobs s06_care_*.js).
// Not a job by itself. Run a screen job with it:
//   python3 bridge.py run jobs/_screens.js jobs/s06_care_kit.js jobs/s06_care_….js

const CARE_AREA = '06 Уход';
const TARGETS = ['Бешенство', 'Панлейкопения (FPV)', 'Герпесвирус (FHV-1)', 'Калицивирус (FCV)',
  'Лейкоз (FeLV)', 'Хламидиоз'];
const TARGET_ROWS = [[0, 1], [2], [3, 4], [5]]; // how the app's Wrap lays them out at 390

// Sets a component property by its short name ('Title', 'Actions', …).
function setProp(node, short, value) {
  const key = Object.keys(node.componentProperties).find((k) => k.split('#')[0] === short);
  if (!key) throw new Error(node.name + ': no property ' + short);
  node.setProperties({ [key]: value });
  return node;
}

// The top bar of a nested screen (App bar).
async function appBar(title, actions) {
  const bar = await inst('App bar', { Actions: actions || 'None' }, { Title: title });
  bar.name = 'App bar';
  return bar;
}

// A nested screen of the Pets tab: app bar, content, the form's Save bar, bottom menu.
async function careScreen(name, title, actions, content, withSave) {
  const nav = await inst('Bottom navigation', { Tab: 'Pets' });
  nav.name = 'Bottom navigation';
  return strokesInside(screen(name, [
    await appBar(title, actions),
    content,
    withSave ? sized(await inst('Save bar'), 'fill') : null,
    nav,
  ]));
}

// New frames count their stroke in the layout; the app draws borders inside the box (a card is
// 92 high, its rows 358 wide), so this screen's own frames leave strokes out. Instances keep theirs.
function strokesInside(node) {
  if (node.type === 'INSTANCE') return node;
  if (node.type === 'FRAME' && node.strokes.length) node.strokesIncludedInLayout = false;
  if ('children' in node) node.children.forEach(strokesInside);
  return node;
}

// The scrolling body: 16 around and 48 at the bottom, like the app's lists and forms.
function careContent(gap, children) {
  return box({ name: 'content', dir: 'V', pad: [16, 16, 48, 16], gap, w: 'fill' }, children);
}

// Fixes the height of a node that is already in an auto-layout parent.
function fixH(node, h) {
  node.layoutSizingVertical = 'FIXED';
  node.resize(node.width, h);
  node.layoutSizingHorizontal = 'FILL';
  return node;
}

// The kind of care as an icon on a grey disc (the app's KindIcon).
function kindDisc(glyph, filled) {
  return box({ name: 'icon disc', dir: 'H', w: 40, h: 40, radius: R().full, fill: 'sunken',
    align: 'center', justify: 'center' }, [icon(glyph, 22, 'ink-muted', filled)]);
}

// A titled block (CbSection): the title row is 44 high, then 8, then the content.
async function section(title, child) {
  const header = await inst('Section header', { Style: 'Title' }, { Title: title, 'Show action': false });
  const block = box({ name: title, dir: 'V', gap: 8, w: 'fill' }, [sized(header, 'fill'), child]);
  fixH(header, 44);
  return block;
}

// An instance by type and layer name, e.g. the field «Дата» in a cloned form.
function byName(root, name) {
  const node = root.findOne((n) => n.type === 'INSTANCE' && n.name === name);
  if (!node) throw new Error('no instance ' + name);
  return node;
}

// The value of a field: words in ink, a placeholder («Не указана») in ink-muted.
function setValue(node, value, muted) {
  try {
    setProp(node, 'Value', value);
  } catch (e) {
    setProp(node, 'Value', ' '); // an empty value
  }
  const t = node.findOne((n) => n.type === 'TEXT' && n.name === 'value');
  t.fills = [paint(muted ? 'ink-muted' : 'ink')];
  return t;
}

// A long value (notes) wraps instead of growing the field sideways. The app's text area in a
// full-width field is 318 wide (the component leaves 326): 24 on the right gives the same lines.
function wrapValue(node) {
  const t = node.findOne((n) => n.type === 'TEXT' && n.name === 'value');
  t.layoutSizingHorizontal = 'FILL';
  t.textAutoResize = 'HEIGHT';
  bindNum(node.findOne((n) => n.type === 'FRAME' && n.name === 'field'), 'paddingRight', 24, 'space-');
  return node;
}

// The Select field's box counts its stroke in the layout (50 high); the app's fields are 48
// like the Text field, so the instance leaves the stroke out.
function flatField(node) {
  node.findOne((n) => n.type === 'FRAME' && n.name === 'field').strokesIncludedInLayout = false;
  return node;
}

// A text field (Text field). Opts: muted (placeholder), hint, mono (code style), noLabel, w (number).
async function field(label, value, opts) {
  opts = opts || {};
  const f = await inst('Text field', { State: 'Default' }, { Label: label, 'Show hint': !!opts.hint });
  f.name = label;
  const v = setValue(f, value, opts.muted);
  if (opts.mono) {
    // The code style is 20 high; the app's field stays 48 like the others.
    await v.setTextStyleIdAsync(CB.text.code.id);
    fixH(f.findOne((n) => n.type === 'FRAME' && n.name === 'field'), 48);
  }
  if (opts.hint) setText(f, 'hint', opts.hint);
  if (opts.noLabel) f.findOne((n) => n.type === 'TEXT' && n.name === 'label').visible = false;
  if (typeof opts.w === 'number') {
    f.resize(opts.w, f.height);
    return f;
  }
  return sized(f, 'fill');
}

// The trailing icon of a date field: a calendar, or a clear cross once a clearable date is set.
function setTrailing(node, clear) {
  const t = node.findOne((n) => n.type === 'TEXT' && n.name.startsWith('icon/') && n.name !== 'icon');
  t.fontName = clear ? ICON_FILLED : ICON_OUTLINED;
  t.characters = clear ? 'close' : 'calendar_today';
  t.name = 'icon/' + t.characters;
}

// A date or time field: the Select field (tap opens a picker) with its arrow swapped for the
// calendar or the clear cross. Opts: muted, clear, hint (starts at the field's edge, like the
// Text field's hint).
async function dateField(label, value, opts) {
  opts = opts || {};
  const f = flatField(await inst('Select field', {}, { Label: label, 'Show icon': false }));
  f.name = label;
  setValue(f, value, opts.muted);
  setTrailing(f, opts.clear);
  if (!opts.hint) return sized(f, 'fill');
  return box({ name: label, dir: 'V', gap: 4, w: 'fill' },
    [sized(f, 'fill'), await text(opts.hint, 'caption', 'ink-muted', { name: 'hint', w: 'fill' })]);
}

// «Тип»: the kind of care with its icon.
async function kindSelect() {
  const f = flatField(await inst('Select field', {}, { Label: 'Тип', Value: 'Прививка', 'Show icon': true }));
  f.name = 'Тип';
  return sized(f, 'fill');
}

// A label above any control (CbLabeled).
async function labeled(label, child) {
  return box({ name: label, dir: 'V', gap: 8, w: 'fill' }, [await text(label, 'label', 'ink', { name: 'label' }), child]);
}

// «От чего защищает»: the vaccine targets as chips; the chosen one is mint with a tick.
// The app's chips sit in 48-high tap rows 8 apart: 36-high chips 20 apart give the same rhythm.
async function targetChips(selected) {
  const rows = [];
  for (const row of TARGET_ROWS) {
    const chips = [];
    for (const i of row) chips.push(await chip(TARGETS[i], TARGETS[i] === selected));
    rows.push(box({ name: 'row', dir: 'H', gap: 8 }, chips));
  }
  return labeled('От чего защищает', box({ name: 'chips', dir: 'V', gap: 20, pad: [6, 0, 6, 0], w: 'fill' }, rows));
}

// One target chip (Chip): the chosen one is mint with a tick.
async function chip(label, on) {
  const c = await inst('Chip', { Selected: on ? 'On' : 'Off' }, { Label: label });
  c.name = 'Чип · ' + label;
  return c;
}

// A text button with an icon: the Button (Style Text) has no icon, so it is detached and gets one.
async function iconButton(glyph, label) {
  const b = (await inst('Button', { Style: 'Text', State: 'Default' }, { Label: label })).detachInstance();
  b.name = label;
  b.insertChild(0, icon(glyph, 18, 'primary'));
  bindNum(b, 'itemSpacing', 8, 'space-');
  return b;
}

// A photo tile (114 × 152, radius sm) with the vaccine sticker; in a form it has a remove button.
async function photoTile(removable) {
  const img = picture(await bridge.ref('crop_care_sticker.png'), 114, 152);
  img.name = 'Фото 1';
  for (const corner of ['topLeftRadius', 'topRightRadius', 'bottomRightRadius', 'bottomLeftRadius']) {
    bindNum(img, corner, R().sm, 'radius-');
  }
  if (!removable) return img;
  const tile = box({ name: 'Фото 1', dir: 'none', w: 114, h: 152 });
  tile.appendChild(img);
  const remove = box({ name: 'remove', dir: 'H', w: 44, h: 44, radius: R().full, fill: 'surface',
    align: 'center', justify: 'center' }, [icon('close', 24, 'ink', true)]);
  tile.appendChild(remove);
  remove.x = 114 - 2 - 44;
  remove.y = 2;
  return tile;
}

// «Фото» in a form: the title with «Добавить фото», then the hint or the photos.
async function photosField(tiles) {
  const title = await inst('Section header', { Style: 'Title' }, { Title: 'Фото', 'Show action': false });
  const head = box({ name: 'header', dir: 'H', h: 48, w: 'fill', align: 'center' },
    [sized(title, 'fill'), await iconButton('add_a_photo', 'Добавить фото')]);
  const body = tiles ? box({ name: 'photos', dir: 'H', gap: 8, w: 'fill' }, tiles)
    : await text('Сфотографируйте наклейку вакцины или заключение ветеринара.', 'body', 'ink-muted',
      { name: 'empty', w: 'fill' });
  return box({ name: 'Фото', dir: 'V', gap: 8, w: 'fill' }, [head, body]);
}
