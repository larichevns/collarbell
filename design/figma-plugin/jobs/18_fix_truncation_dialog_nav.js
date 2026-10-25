// Fixes from the screen builders: cut texts with «…» (truncation before max
// lines), dialog actions 48 high like the app's touch targets, and no line
// above the bottom navigation (the app's NavigationBar covers its border).
await cbSetup();
const cut = [['List row', 'title', 1], ['List row', 'subtitle', 2], ['App bar', 'title', 1],
  ['Offline strip', 'message', 2]];
const out = [];
for (const [name, layer, lines] of cut) {
  const c = await comp(name);
  for (const v of c.type === 'COMPONENT_SET' ? c.children : [c]) {
    const t = v.findOne((n) => n.type === 'TEXT' && n.name === layer);
    t.textTruncation = 'ENDING';
    t.maxLines = lines;
  }
  out.push(name + '/' + layer);
}
const dialog = await comp('Dialog');
const actions = dialog.findOne((n) => n.name === 'actions');
actions.minHeight = 48;
actions.counterAxisAlignItems = 'CENTER';
const nav = await comp('Bottom navigation');
for (const v of nav.children) v.strokes = [];
nav.description = 'Нижнее меню: четыре вкладки. Выбранная — заливка primary-soft и закрашенная иконка primary. ' +
  'Линии сверху нет: в приложении NavigationBar закрывает рамку, заданную в home_shell.dart.';
return { cut: out, dialogHeight: dialog.height, navStroke: nav.children[0].strokes.length };
