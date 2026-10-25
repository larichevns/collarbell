// _ds.js: helpers for jobs that build components on the «Компоненты» page.
// Run as: bridge.py run jobs/_ds.js jobs/1x_….js

const DS_PAGE = '5:2';
const DS_FRAME = 'Компоненты приложения';

async function dsFrame() {
  const page = await figma.getNodeByIdAsync(DS_PAGE);
  await page.loadAsync();
  let f = page.children.find((n) => n.name === DS_FRAME);
  if (!f) {
    f = box({ name: DS_FRAME, dir: 'V', gap: 48, pad: 48, fill: 'paper', w: 1328 });
    page.appendChild(f);
    f.x = 1424;
    f.y = 0;
  }
  return f;
}

// A titled section of the frame; replaces an earlier one with the same title.
async function dsSection(title, note, nodes) {
  const f = await dsFrame();
  const old = f.children.find((c) => c.name === title);
  const section = box({ name: title, dir: 'V', gap: 12 }, [
    await text(title, 'title'),
    await text(note, 'body-sm', 'ink-muted', { w: 880 }),
    ...nodes,
  ]);
  if (old) {
    f.insertChild(f.children.indexOf(old), section);
    old.remove();
  } else {
    f.appendChild(section);
  }
  return section;
}

// Removes components with these names left by an earlier run (they live in
// sections that dsSection replaces, but a failed run may leave strays).
async function dsClean(names) {
  const page = await figma.getNodeByIdAsync(DS_PAGE);
  for (const n of page.findAll((n) => (n.type === 'COMPONENT_SET' || n.type === 'COMPONENT') &&
    names.includes(n.name) && n.parent.type !== 'COMPONENT_SET')) {
    n.remove();
  }
  for (const name of names) delete CB.comps[name];
}

// Builds a component the way box() builds a frame.
function component(name, props, children) {
  const { effect, ...rest } = props;
  const c = figma.createComponentFromNode(box(rest, children));
  c.name = name;
  // The frame is gone after the conversion: the shadow goes on the component.
  if (effect) CB.pending.push(c.setEffectStyleIdAsync(CB.effect[effect].id));
  return c;
}

// Combines variants ('Size=40, Coat=Ginger', …) into a set laid out in rows.
function variantSet(name, variants, description) {
  const set = figma.combineAsVariants(variants, figma.currentPage);
  set.name = name;
  set.layoutMode = 'HORIZONTAL';
  set.layoutWrap = 'WRAP';
  set.itemSpacing = 24;
  set.counterAxisSpacing = 24;
  set.paddingLeft = set.paddingRight = set.paddingTop = set.paddingBottom = 24;
  set.primaryAxisSizingMode = 'AUTO';
  set.counterAxisSizingMode = 'AUTO';
  set.fills = [];
  set.strokes = [paint('line-strong')];
  set.dashPattern = [6, 4];
  set.cornerRadius = 12;
  if (description) set.description = description;
  return set;
}

// Adds a property to a component or set and links layers to it in every
// variant: kind 'TEXT' links `characters`, 'BOOLEAN' links `visible`.
function linkProperty(target, prop, kind, value, layerName) {
  const key = target.addComponentProperty(prop, kind, value);
  const variants = target.type === 'COMPONENT_SET' ? target.children : [target];
  for (const v of variants) {
    for (const layer of v.findAll((n) => n.name === layerName && !inInstance(n, v))) {
      // Keep the layer's other link: a subtitle has both its text and its visibility.
      layer.componentPropertyReferences = Object.assign({}, layer.componentPropertyReferences,
        kind === 'TEXT' ? { characters: key } : { visible: key });
    }
  }
  return key;
}

function inInstance(node, top) {
  for (let p = node.parent; p && p !== top; p = p.parent) if (p.type === 'INSTANCE') return true;
  return false;
}

// Binds width and height to the size token with this value (avatar-md, …).
function bindSize(node, value, prefix) {
  const token = Object.keys(CB.numValue).find((k) => k.startsWith(prefix) && CB.numValue[k] === value);
  if (!token) return;
  node.setBoundVariable('width', CB.num[token]);
  node.setBoundVariable('height', CB.num[token]);
}
