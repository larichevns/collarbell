// Overview PNGs of the «Экраны» page: every area small, one area larger.
const page = figma.root.children.find((p) => p.name === 'Экраны');
await page.loadAsync();
const sections = page.children.filter((n) => n.type === 'SECTION').sort((a, b) => a.name.localeCompare(b.name));
const out = [];
for (const s of sections) {
  const frames = s.children.filter((n) => n.type === 'FRAME' && !n.name.startsWith('Подпись'));
  out.push(s.name + ': ' + frames.length);
  await bridge.shot(s, 'overview_' + s.name.slice(0, 2) + '.png', 0.15);
}
const today = sections.find((s) => s.name.startsWith('04'));
await bridge.shot(today, 'overview_detail_04.png', 0.4);
return out;
