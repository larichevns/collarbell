// _screens.js: helpers for jobs that build app screens on the «Экраны» page.
// Run as: bridge.py run jobs/_screens.js jobs/s…js

const SCREENS_PAGE = 'Экраны';
const PHONE_W = 390;
const PHONE_H = 844;
const R = () => ({
  sm: CB.numValue['radius-sm'], md: CB.numValue['radius-md'],
  lg: CB.numValue['radius-lg'], full: CB.numValue['radius-full'],
});

async function screensPage() {
  let page = figma.root.children.find((p) => p.name === SCREENS_PAGE);
  if (!page) {
    page = figma.createPage();
    page.name = SCREENS_PAGE;
  }
  await page.loadAsync();
  return page;
}

// A phone screen: 390 wide, children top to bottom. Name the child that
// should take spare height 'content'.
function screen(name, children, fill) {
  return box({ name, dir: 'V', w: PHONE_W, fill: fill || 'paper', clip: true }, children);
}

// At least a phone high: a short screen grows to 844 and 'content' takes the
// spare height, so the bottom navigation sits at the bottom.
function fitScreen(frame) {
  if (frame.height >= PHONE_H) return frame;
  const content = frame.children.find((n) => n.name === 'content');
  if (content) content.layoutGrow = 1;
  frame.resize(PHONE_W, PHONE_H);
  return frame;
}

// Puts a node on top of the screen at a fixed spot (FAB, sheet, dialog).
// Pass right/bottom or left/top in px from the screen's edges.
function float(frame, node, at) {
  frame.appendChild(node);
  node.layoutPositioning = 'ABSOLUTE';
  node.x = at.left != null ? at.left : frame.width - node.width - (at.right || 0);
  node.y = at.top != null ? at.top : frame.height - node.height - (at.bottom || 0);
  node.constraints = {
    horizontal: at.left != null ? 'MIN' : 'MAX',
    vertical: at.top != null ? 'MIN' : 'MAX',
  };
  return node;
}

// A dimmed screen under a sheet or dialog: the scrim covers the whole frame.
function scrim(frame) {
  const s = figma.createRectangle();
  s.name = 'scrim';
  s.resize(frame.width, frame.height);
  // Flutter's modal barrier: black at 54%.
  s.fills = [{ type: 'SOLID', color: { r: 0, g: 0, b: 0 }, opacity: 0.54 }];
  float(frame, s, { left: 0, top: 0 });
  s.constraints = { horizontal: 'STRETCH', vertical: 'STRETCH' };
  return s;
}

// A card like the app's CbCard: surface, line border, radius lg, soft shadow.
function card(children, props) {
  const c = box(Object.assign({ name: 'card', dir: 'V', w: 'fill', fill: 'surface', stroke: 'line',
    radius: R().lg, effect: 'Light/shadow-card', clip: true }, props || {}), children);
  c.strokesIncludedInLayout = false; // the border doesn't make the card taller, as in the app
  return c;
}

// A divider line, indented from the left (68 = under the text of a List row).
function divider(indent) {
  return box({ name: 'divider', dir: 'H', w: 'fill', pad: [0, 0, 0, indent || 0] },
    [box({ name: 'line', h: 1, w: 'fill', fill: 'line' })]);
}

// The nested Pet avatar of an instance (List row, …): sets coat and letter.
function setAvatar(node, coat, initial) {
  const a = node.type === 'INSTANCE' && 'Coat' in node.componentProperties ? node
    : node.findOne((n) => n.type === 'INSTANCE' && 'Coat' in n.componentProperties);
  const props = { Coat: coat };
  const key = Object.keys(a.componentProperties).find((k) => k.startsWith('Initial#'));
  if (initial && key) props[key] = initial;
  a.setProperties(props);
  return node;
}

// An area of the page (a section), e.g. '03 Питомцы'.
async function areaSection(title) {
  const page = await screensPage();
  let s = page.children.find((n) => n.type === 'SECTION' && n.name === title);
  if (!s) {
    s = figma.createSection();
    s.name = title;
    page.appendChild(s);
  }
  return s;
}

// Sections one under another, in the order of their numbers.
async function stackAreas() {
  const page = await screensPage();
  const sections = page.children.filter((n) => n.type === 'SECTION').sort((a, b) => a.name.localeCompare(b.name));
  let y = 0;
  for (const s of sections) {
    s.x = 0;
    s.y = y;
    y += s.height + 240;
  }
}

// Places a built screen in its area at column `slot`, with the app's own
// screenshot (refName in the refs folder) beside it, replacing an earlier
// version with the same name. Saves a 1x PNG of the screen as shots/<refName>.
async function place(areaTitle, slot, frame, refName) {
  const section = await areaSection(areaTitle);
  const name = frame.name;
  for (const n of section.children.filter((n) => [name, 'Снимок · ' + name, 'Подпись · ' + name].includes(n.name))) {
    n.remove();
  }
  const x = 80 + slot * 1000;
  const y = 200;
  section.appendChild(frame);
  frame.x = x;
  frame.y = y;
  // Figma takes images up to 4096 px: a taller screenshot has a shrunk
  // `_fit` copy next to it.
  let image;
  let size;
  try {
    image = await bridge.ref(refName);
    size = await image.getSizeAsync();
  } catch (error) {
    image = await bridge.ref(refName.replace(/\.png$/, '_fit.png'));
    size = await image.getSizeAsync();
  }
  const shot = picture(image, PHONE_W, Math.round(size.height * PHONE_W / size.width));
  shot.name = 'Снимок · ' + name;
  section.appendChild(shot);
  shot.x = x + PHONE_W + 40;
  shot.y = y;
  const label = box({ name: 'Подпись · ' + name, dir: 'H', gap: 40 }, [
    await text(name, 'title', 'ink', { w: PHONE_W }),
    await text('Снимок из приложения', 'body-sm', 'ink-muted', { w: PHONE_W }),
  ]);
  section.appendChild(label);
  label.x = x;
  label.y = y - label.height - 24;
  let right = 0;
  let bottom = 0;
  for (const n of section.children) {
    right = Math.max(right, n.x + n.width);
    bottom = Math.max(bottom, n.y + n.height);
  }
  section.resizeWithoutConstraints(Math.max(section.width, right + 80), Math.max(section.height, bottom + 120));
  await stackAreas();
  await cbDone();
  await bridge.shot(frame, refName);
  return frame.id;
}
