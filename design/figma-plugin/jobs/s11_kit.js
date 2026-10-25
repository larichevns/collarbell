// s11_kit.js: helpers for the supplies screens (area «11 Запасы»). Not a job by itself:
// bridge.py run jobs/_screens.js jobs/s11_kit.js jobs/s11_<screens>.js
const AREA = '11 Запасы';
const FULL = () => CB.numValue['radius-full'];
const NAV_H = 80;

// Sets a component property of an instance by its short name.
function setProp(node, short, value) {
  const key = Object.keys(node.componentProperties).find((k) => k.split('#')[0] === short);
  if (!key) throw new Error(node.name + ': no property ' + short);
  node.setProperties({ [key]: value });
  return node;
}
// The same on the first nested instance that has it (the Button inside a List row).
function nestedProp(node, short, value) {
  const target = node.findOne((n) => n.type === 'INSTANCE' &&
    Object.keys(n.componentProperties).some((k) => k.split('#')[0] === short));
  if (!target) throw new Error(node.name + ': no nested property ' + short);
  return setProp(target, short, value);
}
const layer = (node, name) => node.findOne((n) => n.name === name);
// paint() for layers inside instances: the paint also carries the token's colour.
// An override bound to the variable the main component already uses is drawn with
// the paint's own colour, which paint() leaves black.
function tone(name) {
  const v = CB.color[name];
  const c = v.valuesByMode[Object.keys(v.valuesByMode)[0]];
  if (!c || c.r == null) return paint(name);
  return figma.variables.setBoundVariableForPaint({ type: 'SOLID', color: { r: c.r, g: c.g, b: c.b } }, 'color', v);
}
// Overrides a padding or gap, bound to a space token when one has this value.
function setNum(node, field, value) {
  if (node.boundVariables && node.boundVariables[field]) node.setBoundVariable(field, null);
  bindNum(node, field, value, 'space-');
}

// App bar; close: the scanner's × instead of the back arrow.
async function appBar(title, actions, close) {
  const bar = await inst('App bar', { Actions: actions || 'None' }, { Title: title });
  bar.name = 'App bar';
  const words = layer(bar, 'title');
  words.maxLines = 1;
  words.textTruncation = 'ENDING';
  if (close) layer(bar, 'icon/arrow_back').characters = 'close';
  return sized(bar, 'fill');
}
const nav = () => inst('Bottom navigation', { Tab: 'Supplies' });

// A titled block: Section header (44 high like CbSection, also without its action),
// 8, then its card.
async function section(title, child) {
  const header = await inst('Section header', { Style: 'Title' }, { Title: title, 'Show action': false });
  header.resize(header.width, CB.numValue['control-md']);
  return box({ name: title, dir: 'V', gap: 8, w: 'fill' }, [sized(header, 'fill'), child]);
}

// One fact of a details card: muted caption above the value.
async function fact(label, value) {
  return box({ name: label, dir: 'V', gap: 4, pad: [8, 0], w: 'fill' }, [
    await text(label, 'caption', 'ink-muted', { w: 'fill', name: 'label' }),
    await text(value, 'body', 'ink', { w: 'fill', name: 'value' }),
  ]);
}

// ListTile with a plain icon (List row only has the icon on a disc): 72 high with a
// subtitle, 56 without. filled: the app's plain Icons.x (not _outlined).
async function tile(glyph, title, subtitle, trailing, filled) {
  const texts = [await text(title, 'subtitle', 'ink', { w: 'fill', name: 'title' })];
  if (subtitle) texts.push(await text(subtitle, 'body-sm', 'ink-muted', { w: 'fill', name: 'subtitle' }));
  return box({ name: title, dir: 'H', w: 'fill', h: subtitle ? 72 : 56, pad: [0, 16], gap: 16, align: 'center' }, [
    icon(glyph, 24, 'ink-muted', filled),
    box({ name: 'texts', dir: 'V', w: 'fill' }, texts),
    trailing || null,
  ]);
}
// An icon button's 48 tap area.
const iconTap = (glyph, color, filled) => box({ name: glyph, dir: 'H', w: 48, h: 48, align: 'center', justify: 'center' },
  [icon(glyph, 24, color || 'ink-muted', filled)]);

// Pill button with an icon (the Button component has no icon): primary, outline or
// text. wrap: the label wraps beside the icon, as in a half-width button.
async function pill(kind, glyph, label, opts) {
  opts = opts || {};
  const look = { primary: { fill: 'primary', fg: 'on-primary' }, outline: { stroke: 'line-strong', fg: 'ink' },
    text: { fg: 'primary' } }[kind];
  return box({ name: 'Кнопка · ' + label, dir: 'H', h: opts.h || 44, w: opts.w, pad: [0, kind === 'text' ? 12 : 20],
    gap: 8, align: 'center', justify: opts.wrap ? 'start' : 'center', radius: FULL(), fill: look.fill,
    stroke: look.stroke }, [
    icon(glyph, 18, look.fg, opts.filled),
    await text(label, 'label', look.fg, { name: 'label', w: opts.wrap ? 'fill' : undefined }),
  ]);
}
// A Button instance across the width; tall = control-lg (52), the main button.
async function wideButton(style, label, tall) {
  const b = await inst('Button', { Style: style, State: 'Default' }, { Label: label });
  b.name = 'Кнопка · ' + label;
  if (tall) b.resize(b.width, CB.numValue['control-lg']);
  return sized(b, 'fill');
}

// Number with − and + (IconButton.outlined, 44 in a 48 tap area).
async function counter(label, value, canLess) {
  const round = (glyph, on) => box({ name: glyph, dir: 'H', w: 48, h: 48, align: 'center', justify: 'center' }, [
    box({ name: 'circle', dir: 'H', w: 44, h: 44, radius: FULL(), stroke: on ? 'line-strong' : 'line',
      align: 'center', justify: 'center' }, [icon(glyph, 24, on ? 'ink-muted' : 'ink-disabled', true)])]);
  return box({ name: 'counter', dir: 'H', w: 'fill', align: 'center' }, [
    await text(label, 'body', 'ink', { w: 'fill', name: 'label' }),
    round('remove', canLess),
    box({ name: 'value', dir: 'H', w: 48, justify: 'center' }, [await text(String(value), 'title', 'ink', { name: 'value' })]),
    round('add', true),
  ]);
}

// Material slider with 10 steps (value 0…1), 48 high: track 4 (active 6), thumb 20.
function slider(value, width) {
  const f = box({ name: 'slider', dir: 'none', w: width, h: 48 });
  const at = (node, x, y) => { f.appendChild(node); node.x = x; node.y = y; return node; };
  const x0 = 26;
  const span = width - 52;
  const thumbX = x0 + value * span;
  at(box({ name: 'track', w: width - 48, h: 4, radius: 2, fill: 'sunken' }), 24, 22);
  if (value > 0) at(box({ name: 'active track', w: thumbX - 24, h: 6, radius: 3, fill: 'primary' }), 24, 21);
  for (let i = 0; i <= 10; i++) {
    const x = x0 + (i * span) / 10;
    const on = x <= thumbX;
    at(box({ name: 'tick', w: 2, h: 2, radius: 1, fill: on ? 'on-primary' : 'ink-muted', fillOpacity: 0.38 }), x - 1, 23);
  }
  at(box({ name: 'thumb', w: 20, h: 20, radius: FULL(), fill: 'primary' }), thumbX - 10, 14);
  return f;
}

// A chip with a leading icon (ChoiceChip, ActionChip, InputChip), 34 high. selected:
// mint, primary label, the icon dimmed under a check; close: InputChip's delete icon.
async function chip(label, glyph, opts) {
  opts = opts || {};
  let lead = icon(glyph, 18, opts.iconColor || 'primary');
  if (opts.selected) {
    lead = box({ name: 'avatar', dir: 'none', w: 25, h: 25 });
    const disc = box({ name: 'disc', w: 25, h: 25, radius: FULL(), fill: 'ink-muted', fillOpacity: 0.55 });
    for (const n of [disc, icon(glyph, 18, 'ink'), icon('check', 18, 'primary', true)]) {
      lead.appendChild(n);
      n.x = n === disc ? 0 : 3.5;
      n.y = n === disc ? 0 : 3.5;
    }
  }
  return box({ name: 'Чип · ' + label, dir: 'H', h: 34, pad: [0, 16, 0, opts.selected ? 9 : 16],
    gap: opts.selected ? 15 : 16, align: 'center', radius: FULL(), fill: opts.selected ? 'primary-soft' : 'surface',
    stroke: opts.selected ? null : 'line-strong' }, [
    lead,
    await text(label, 'label', opts.selected ? 'primary' : 'ink', { name: 'label' }),
    opts.close ? icon('close', 18, 'ink-muted', true) : null,
  ]);
}
// Chips that wrap like Flutter's Wrap(spacing 8, runSpacing 8) with 48 tap areas.
function chipWrap(chips, width) {
  const w = box({ name: 'chips', dir: 'H', w: width, pad: [7, 0], gap: 8 }, chips);
  w.layoutWrap = 'WRAP';
  w.counterAxisSpacing = 22;
  return w;
}

// Segmented button (2 segments, the first selected), 40 high in a 48 tap area.
async function segmented(first, second) {
  const seg = async (label, on) => box({ name: label, dir: 'H', w: 'fill', h: 40, align: 'center', justify: 'center',
    fill: on ? 'primary-soft' : 'surface' }, [await text(label, 'label', on ? 'primary' : 'ink', { name: 'label' })]);
  return box({ name: 'segmented', dir: 'V', pad: [4, 0], w: 'fill' }, [
    box({ name: 'segments', dir: 'H', w: 'fill', h: 40, radius: FULL(), stroke: 'line-strong', clip: true }, [
      await seg(first, true), box({ name: 'divider', w: 1, h: 40, fill: 'line-strong' }), await seg(second, false)]),
  ]);
}

// Text field instance. hint: the helper under the field; placeholder: the value is a hint.
async function field(label, value, opts) {
  opts = opts || {};
  const f = await inst('Text field', { State: opts.state || 'Default' },
    { Label: label, Value: value, 'Show hint': !!opts.hint });
  f.name = opts.name || label;
  if (opts.hint) setText(f, 'hint', opts.hint);
  setValue(f, value, opts.placeholder);
  if (opts.noLabel) layer(f, 'label').visible = false;
  return sized(f, 'w' in opts ? opts.w : 'fill');
}
// Changes a field's value; placeholder: muted, like a hint inside the field. lines:
// the value spans the field and wraps (notes) or is cut at its edge (1, a link).
function setValue(f, value, placeholder, lines) {
  setProp(f, 'Value', value);
  const v = f.findOne((n) => n.type === 'TEXT' && n.name === 'value');
  v.fills = [tone(placeholder ? 'ink-muted' : 'ink')];
  if (lines) {
    v.layoutSizingHorizontal = 'FILL';
    v.textAutoResize = 'HEIGHT';
    if (lines === 1) {
      v.maxLines = 1;
      v.textTruncation = 'ENDING';
    }
  }
  return f;
}

// A Bottom sheet with own content over the screen, above the nav (the app opens it
// inside the tab, so the nav stays undimmed). No title: the sheet of options.
async function sheetOver(frame, title, content, bottomPad) {
  const sheet = (await inst('Bottom sheet', {}, { Title: title || '-' })).detachInstance();
  sheet.name = 'Нижний лист';
  const slot = layer(sheet, 'content');
  const body = slot.parent;
  body.insertChild(body.children.indexOf(slot), content);
  content.layoutSizingHorizontal = 'FILL';
  slot.remove();
  if (!title) {
    layer(body, 'title').remove();
    setNum(body, 'paddingLeft', 0);
    setNum(body, 'paddingRight', 0);
  }
  if (bottomPad != null) setNum(body, 'paddingBottom', bottomPad);
  const s = scrim(frame);
  s.resize(PHONE_W, frame.height - NAV_H);
  float(frame, sheet, { left: 0, bottom: NAV_H });
  return sheet;
}
