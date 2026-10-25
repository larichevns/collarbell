// Smoke test: can the plugin run code, see the file, fonts and variables?
const pages = figma.root.children.map((p) => p.id + ' ' + p.name);
const fonts = (await figma.listAvailableFontsAsync())
  .map((f) => f.fontName.family + ' ' + f.fontName.style)
  .filter((f) => /Golos|Unbounded|JetBrains|Material/.test(f));
const collections = (await figma.variables.getLocalVariableCollectionsAsync())
  .map((c) => c.name + ': ' + c.variableIds.length);
const button = await figma.getNodeByIdAsync('7:23');
const shotBytes = button ? await bridge.shot(button, '00_smoke_button') : 0;
return { file: figma.root.name, pages, fonts, collections, shotBytes };
