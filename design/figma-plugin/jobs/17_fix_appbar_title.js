// Fix: the App bar title stays on one line, cut with «…», and keeps 16 px
// before the actions (Flutter's middle spacing).
await cbSetup();
const bar = await comp('App bar');
const out = [];
for (const v of bar.children) {
  const wrap = v.findOne((n) => n.name === 'title wrap');
  wrap.paddingRight = 16;
  const title = wrap.findOne((n) => n.type === 'TEXT');
  title.textAutoResize = 'HEIGHT';
  title.maxLines = 1;
  title.textTruncation = 'ENDING';
  out.push([v.name, wrap.paddingRight, title.maxLines, v.height]);
}
return out;
