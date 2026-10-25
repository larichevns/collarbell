// Fix: in the app components, borders don't add to a frame's size (the
// Select field was 50 high instead of 48, the Save bar 85 instead of 84).
await cbSetup();
const frame = (await figma.getNodeByIdAsync('5:2')).children.find((n) => n.name === 'Компоненты приложения');
const changed = [];
for (const n of frame.findAll((n) => 'strokesIncludedInLayout' in n && n.strokesIncludedInLayout &&
  n.layoutMode && n.layoutMode !== 'NONE' && n.strokes.length)) {
  n.strokesIncludedInLayout = false;
  changed.push(n.name);
}
const select = await comp('Select field');
const save = await comp('Save bar');
return { changed: changed.length, names: [...new Set(changed)].slice(0, 20), select: select.height, save: save.height };
