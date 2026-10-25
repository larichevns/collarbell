// lib.js: helpers shared by every job (bridge.py puts it before the job's code).
// A job starts with `await cbSetup();` and then builds with box/text/icon/inst.

const CB_IDS = {
  colors: ['paper', 'surface', 'sunken', 'line', 'line-strong', 'ink', 'ink-muted',
    'ink-disabled', 'primary', 'primary-strong', 'on-primary', 'primary-soft', 'accent',
    'accent-text', 'on-accent', 'accent-soft', 'danger', 'on-danger', 'danger-soft', 'success',
    'success-soft', 'warning', 'warning-soft', 'inverse-surface', 'on-inverse',
    'inverse-primary', 'coat-ginger', 'coat-fawn', 'coat-cocoa', 'coat-smoke', 'coat-lilac',
    'coat-ink', 'on-coat'], // VariableID:3:3 … 3:35, in this order
  other: {
    'space-1': '3:70', 'space-2': '3:71', 'space-3': '3:72', 'space-4': '3:73',
    'space-5': '3:74', 'space-6': '3:75', 'space-8': '3:76', 'space-12': '3:77',
    'radius-sm': '3:79', 'radius-md': '3:80', 'radius-lg': '3:81', 'radius-full': '3:82',
    'control-sm': '3:84', 'control-md': '3:85', 'control-lg': '3:86', check: '3:87',
    'avatar-sm': '3:88', 'avatar-md': '3:89', 'avatar-lg': '3:90',
  },
  text: ['display-xl', 'display-lg', 'numeral', 'title', 'subtitle', 'body', 'body-sm',
    'label', 'caption', 'overline', 'code'],
  effects: ['Light/shadow-card', 'Light/shadow-sm', 'Light/shadow-lg', 'Light/focus-ring'],
};
const CB = { color: {}, num: {}, numValue: {}, text: {}, effect: {}, comps: {}, pending: [], ready: false };
const ICON_FILLED = { family: 'Material Icons', style: 'Regular' };
const ICON_OUTLINED = { family: 'Material Symbols Rounded', style: 'Regular' };

async function cbSetup() {
  if (CB.ready) return;
  const fonts = [ICON_FILLED, ICON_OUTLINED,
    ...['Regular', 'Medium', 'SemiBold', 'Bold'].map((style) => ({ family: 'Golos Text', style })),
    ...['Medium', 'SemiBold'].map((style) => ({ family: 'Unbounded', style })),
    { family: 'JetBrains Mono', style: 'Medium' }];
  await Promise.all(fonts.map((f) => figma.loadFontAsync(f).catch(() => null)));
  for (let i = 0; i < CB_IDS.colors.length; i++) {
    CB.color[CB_IDS.colors[i]] = await figma.variables.getVariableByIdAsync('VariableID:3:' + (3 + i));
  }
  for (const [name, id] of Object.entries(CB_IDS.other)) {
    const v = await figma.variables.getVariableByIdAsync('VariableID:' + id);
    CB.num[name] = v;
    CB.numValue[name] = v.valuesByMode[Object.keys(v.valuesByMode)[0]];
  }
  for (const s of await figma.getLocalTextStylesAsync()) CB.text[s.name] = s;
  for (const s of await figma.getLocalEffectStylesAsync()) CB.effect[s.name] = s;
  CB.ready = true;
}

// A solid paint bound to a colour variable ('ink', 'primary', …).
function paint(name, opacity) {
  const v = CB.color[name];
  if (!v) throw new Error('no colour ' + name);
  // The paint also carries the token's real colour: an override that binds
  // the same variable as the main component is drawn with this raw colour.
  const value = v.valuesByMode[Object.keys(v.valuesByMode)[0]];
  const color = value && 'r' in value ? { r: value.r, g: value.g, b: value.b } : { r: 0, g: 0, b: 0 };
  return figma.variables.setBoundVariableForPaint(
    { type: 'SOLID', color, opacity: opacity == null ? 1 : opacity }, 'color', v);
}

// Binds a number field to the token with the same value (space-* for gaps and
// paddings, radius-* for corners), or sets the plain number.
function bindNum(node, field, value, prefix) {
  const token = Object.keys(CB.numValue).find((k) => k.startsWith(prefix) && CB.numValue[k] === value);
  if (token) node.setBoundVariable(field, CB.num[token]);
  else node[field] = value;
}

const pendingSize = new Map();
// Remembers how a node sizes inside its auto-layout parent; applied on add().
function sized(node, w, h) {
  pendingSize.set(node.id, { w, h });
  return node;
}
function applySize(node) {
  const s = pendingSize.get(node.id);
  if (!s) return;
  const axis = (v, field) => {
    if (v === 'fill') node[field] = 'FILL';
    else if (v === 'hug') node[field] = 'HUG';
  };
  axis(s.w, 'layoutSizingHorizontal');
  axis(s.h, 'layoutSizingVertical');
}
function add(parent, ...children) {
  for (const child of children.flat()) {
    if (!child) continue;
    parent.appendChild(child);
    applySize(child);
  }
  return parent;
}

// An auto-layout frame. Props: name, dir 'V'|'H'|'none', gap, pad (n | [v,h] |
// [t,r,b,l]), fill, stroke, strokeW, strokeSides {top,bottom,…}, radius (n or
// [tl,tr,br,bl]), align/justify ('start'|'center'|'end'|'between'), w/h
// (number = fixed, 'fill', 'hug'), effect (style name), clip, opacity.
function box(props, children) {
  props = props || {};
  const f = figma.createFrame();
  f.name = props.name || 'box';
  f.fills = props.fill ? [paint(props.fill, props.fillOpacity)] : [];
  f.clipsContent = !!props.clip;
  if (props.dir !== 'none') {
    f.layoutMode = props.dir === 'H' ? 'HORIZONTAL' : 'VERTICAL';
    f.primaryAxisSizingMode = 'AUTO';
    f.counterAxisSizingMode = 'AUTO';
    const map = { start: 'MIN', center: 'CENTER', end: 'MAX', between: 'SPACE_BETWEEN' };
    if (props.justify) f.primaryAxisAlignItems = map[props.justify];
    if (props.align) f.counterAxisAlignItems = map[props.align] || props.align;
    if (props.gap) bindNum(f, 'itemSpacing', props.gap, 'space-');
    if (props.pad != null) {
      const p = typeof props.pad === 'number' ? [props.pad, props.pad, props.pad, props.pad]
        : props.pad.length === 2 ? [props.pad[0], props.pad[1], props.pad[0], props.pad[1]] : props.pad;
      ['paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft']
        .forEach((field, i) => p[i] && bindNum(f, field, p[i], 'space-'));
    }
  }
  if (props.stroke) {
    f.strokes = [paint(props.stroke)];
    f.strokeAlign = 'INSIDE';
    // Like Flutter's borders: the line doesn't add to the frame's size.
    if (props.dir !== 'none') f.strokesIncludedInLayout = false;
    f.strokeWeight = props.strokeW || 1;
    if (props.strokeSides) {
      for (const side of ['Top', 'Right', 'Bottom', 'Left']) {
        f['stroke' + side + 'Weight'] = props.strokeSides[side.toLowerCase()] || 0;
      }
    }
  }
  if (props.radius != null) {
    const r = typeof props.radius === 'number' ? [props.radius, props.radius, props.radius, props.radius] : props.radius;
    ['topLeftRadius', 'topRightRadius', 'bottomRightRadius', 'bottomLeftRadius']
      .forEach((field, i) => bindNum(f, field, r[i], 'radius-'));
  }
  if (props.effect) CB.pending.push(f.setEffectStyleIdAsync(CB.effect[props.effect].id));
  if (props.opacity != null) f.opacity = props.opacity;
  const w = typeof props.w === 'number' ? props.w : null;
  const h = typeof props.h === 'number' ? props.h : null;
  if (w || h) {
    f.resize(w || f.width, h || f.height);
    if (props.dir !== 'none') {
      f.layoutSizingHorizontal = w ? 'FIXED' : 'HUG';
      f.layoutSizingVertical = h ? 'FIXED' : 'HUG';
    }
  }
  if (children) add(f, children);
  return sized(f, props.w, props.h);
}

// Text in a text style and colour (await it). Opts: w ('fill' | number), align
// ('LEFT'|'CENTER'|'RIGHT'), lines (max lines, cut with …), name.
async function text(chars, style, color, opts) {
  opts = opts || {};
  const t = figma.createText();
  const s = CB.text[style];
  if (!s) throw new Error('no text style ' + style);
  await t.setTextStyleIdAsync(s.id);
  t.characters = String(chars);
  t.fills = [paint(color || 'ink')];
  t.name = opts.name || String(chars).slice(0, 40);
  if (opts.align) t.textAlignHorizontal = opts.align;
  if (opts.lines) {
    // Truncation first: set the other way round, both are lost.
    t.textTruncation = 'ENDING';
    t.maxLines = opts.lines;
  }
  if (typeof opts.w === 'number') {
    t.resize(opts.w, t.height);
    t.textAutoResize = 'HEIGHT';
  }
  if (opts.w === 'fill') t.textAutoResize = 'HEIGHT';
  return sized(t, opts.w);
}

// A Material icon by its name (ligature): outlined by default, like the app's
// Icons.x_outlined; filled: true for Icons.x.
function icon(name, size, color, filled) {
  size = size || 24;
  const t = figma.createText();
  t.fontName = filled ? ICON_FILLED : ICON_OUTLINED;
  t.characters = name;
  t.fontSize = size;
  t.lineHeight = { unit: 'PIXELS', value: size };
  t.textAlignHorizontal = 'CENTER';
  t.textAlignVertical = 'CENTER';
  t.textAutoResize = 'NONE';
  t.resize(size, size);
  t.fills = [paint(color || 'ink')];
  t.name = 'icon/' + name;
  return t;
}

// A component or component set on any page, by name.
async function comp(name) {
  if (CB.comps[name]) return CB.comps[name];
  for (const page of figma.root.children) {
    await page.loadAsync();
    const found = page.findOne((n) => (n.type === 'COMPONENT_SET' ||
      (n.type === 'COMPONENT' && n.parent.type !== 'COMPONENT_SET')) && n.name === name);
    if (found) return (CB.comps[name] = found);
  }
  throw new Error('no component ' + name);
}

// An instance: variant picks the variant of a set ({Style: 'Primary'}), props
// sets component properties by their short names ({Label: 'Сохранить'}).
async function inst(name, variant, props) {
  const c = await comp(name);
  let target = c;
  if (c.type === 'COMPONENT_SET') {
    const want = Object.entries(variant || {});
    target = c.children.find((v) => want.every(([k, val]) => v.variantProperties[k] === val));
    if (!target) throw new Error(name + ': no variant ' + JSON.stringify(variant));
  }
  const i = target.createInstance();
  if (props && Object.keys(props).length) {
    const full = {};
    for (const [short, value] of Object.entries(props)) {
      const key = Object.keys(i.componentProperties).find((k) => k.split('#')[0] === short);
      if (!key) throw new Error(name + ': no property ' + short);
      full[key] = value;
    }
    i.setProperties(full);
  }
  return i;
}

// Changes a text layer inside an instance, found by layer name.
function setText(node, layerName, chars) {
  const t = node.findOne((n) => n.type === 'TEXT' && n.name === layerName);
  if (!t) throw new Error('no text layer ' + layerName);
  t.characters = String(chars);
  return t;
}

// A grey rectangle with a picture in it (photo stand-in or a screenshot).
function picture(image, w, h, radius) {
  const r = figma.createRectangle();
  r.resize(w, h);
  r.fills = [{ type: 'IMAGE', imageHash: image.hash, scaleMode: 'FILL' }];
  if (radius) r.cornerRadius = radius;
  return r;
}

// Waits for the style changes box() started (shadows). Call before return.
async function cbDone() {
  await Promise.all(CB.pending.splice(0));
}
