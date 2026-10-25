// Fix: a subtitle/caption layer keeps both its text and visibility links;
// list and switch rows have no gap between title and subtitle (like ListTile).
await cbSetup();
const fixes = [['List row', 'subtitle', 'Subtitle', 'Show subtitle'], ['Switch row', 'subtitle', 'Subtitle', 'Show subtitle'],
  ['Screen header', 'caption', 'Caption', 'Show caption']];
const done = [];
for (const [name, layerName, textProp, boolProp] of fixes) {
  const c = await comp(name);
  const keys = Object.keys(c.componentPropertyDefinitions);
  const textKey = keys.find((k) => k.split('#')[0] === textProp);
  const boolKey = keys.find((k) => k.split('#')[0] === boolProp);
  for (const v of c.type === 'COMPONENT_SET' ? c.children : [c]) {
    const layer = v.findOne((n) => n.name === layerName && n.type === 'TEXT');
    layer.componentPropertyReferences = { characters: textKey, visible: boolKey };
    const texts = v.findOne((n) => n.name === 'texts');
    if (texts && name !== 'Screen header') texts.itemSpacing = 0;
  }
  done.push(name);
}
const frame = (await figma.getNodeByIdAsync('5:2')).children.find((n) => n.name === 'Компоненты приложения');
frame.layoutSizingHorizontal = 'HUG';
const list = await figma.getNodeByIdAsync('26:618');
await bridge.shot(list, '03_pets_list.png');
return done;
