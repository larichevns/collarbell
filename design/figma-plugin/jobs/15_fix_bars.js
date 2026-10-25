// Fix from the screen builders' measurements: the app's top bar is 56 high
// with a muted back arrow (actions stay ink); the sheet handle is `line`.
await cbSetup();
const bar = await comp('App bar');
for (const v of bar.children) {
  v.resize(v.width, 56);
  v.findOne((n) => n.name === 'icon/arrow_back').fills = [paint('ink-muted')];
}
const sheet = await comp('Bottom sheet');
sheet.findOne((n) => n.name === 'handle').fills = [paint('line')];
// A selected filter chip writes its label in ink; only the tick is primary.
const chip = await comp('Chip');
const on = chip.children.find((v) => v.variantProperties.Selected === 'On');
on.findOne((n) => n.type === 'TEXT' && n.name === 'label').fills = [paint('ink')];
chip.description = chip.description.replace('галочка и текст primary', 'галочка primary, текст ink');
return { bar: bar.children.map((v) => v.height), handle: 'line', chip: chip.description };
