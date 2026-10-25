// Read-only: what sits at the top level of each page (to find strays left by jobs).
const out = {};
for (const page of figma.root.children) {
  await page.loadAsync();
  out[page.name] = page.children.map((n) => `${n.id} ${n.type} ${n.name} @${Math.round(n.x)},${Math.round(n.y)} ${Math.round(n.width)}x${Math.round(n.height)}`);
}
return out;
