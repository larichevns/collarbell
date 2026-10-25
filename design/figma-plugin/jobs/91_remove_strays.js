// Removes loose icon texts that jobs left at the top level of «Основа» and
// «Компоненты» (icons are made on the current page before being placed).
const removed = [];
for (const page of figma.root.children.filter((p) => p.name !== 'Экраны')) {
  await page.loadAsync();
  for (const n of page.children.filter((n) => n.type === 'TEXT' && n.name.startsWith('icon/'))) {
    removed.push(page.name + ': ' + n.id + ' ' + n.name);
    n.remove();
  }
}
return removed;
