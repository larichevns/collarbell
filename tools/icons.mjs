#!/usr/bin/env node
// Draws the icons of the web app, the admin and the site: Material Symbols Rounded, outlined, weight 400 at optical
// size 48, from Google's SVGs in the npm package @material-symbols/svg-400, pinned to one version (Apache License
// 2.0). The designer asked for icons a little thinner (2026-10-14): the size-48 drawing is just that at 20–24px,
// while weight 300 halved the stroke. The app draws the same (IconThemeData weight 400, opticalSize 48).
//
//     node tools/icons.mjs                # rewrites every path in the icon maps below
//     node tools/icons.mjs --check        # changes nothing; exits 1 if a map differs from the package
//     node tools/icons.mjs --from <dir>   # uses the package already installed in <dir>/node_modules
//
// The package (20 MB of SVG files) is not a dependency of any project: the first run installs it with npm into a
// folder of the system's temporary directory, outside the repo, and later runs reuse it.
//
// The maps keep their names, order and comments; only the path strings change. A new icon: add `name: '',` to a map
// and run the script, it fills the path in. A name the package doesn't have stops the script with an error, so no
// icon goes missing. Node's standard library only.

import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const PACKAGE = '@material-symbols/svg-400';
const VERSION = '0.47.5';
const STYLE = 'rounded';
const VIEW_BOX = '0 -960 960 960';

// The maps: `  name: 'path',` lines in TypeScript, and in CSS the icons drawn inside a data: URL, each marked with
// its name (<path id='expand_more' d='...'>, the arrow of a <select>).
const TS_MAPS = ['web/src/components/icons.ts', 'admin/src/components/icons.ts', 'landing/src/icons.ts'];
const CSS_FILES = ['web/src/styles/app.css'];

// Names our code keeps that Google has since renamed: the same drawings under their new names in the package.
const RENAMED = {
  expand_less: 'keyboard_arrow_up',
  expand_more: 'keyboard_arrow_down',
  phone_iphone: 'mobile_3',
  smartphone: 'mobile',
};

// Names drawn filled (<name>-fill.svg). None for now: every icon of the web, the admin and the site is outlined.
const FILLED = new Set([]);

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const check = args.includes('--check');
const fromAt = args.indexOf('--from');
const installDir =
  fromAt >= 0 ? args[fromAt + 1] : join(tmpdir(), `collarbell-${PACKAGE.slice(1).replace('/', '-')}-${VERSION}`);
if (!installDir) fail('--from needs a folder');
const packageDir = join(installDir, 'node_modules', ...PACKAGE.split('/'));

function fail(message) {
  console.error(`icons: ${message}`);
  process.exit(2);
}

function installedVersion() {
  const file = join(packageDir, 'package.json');
  return existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')).version : null;
}

if (installedVersion() !== VERSION) {
  if (fromAt >= 0) fail(`${packageDir} is not ${PACKAGE}@${VERSION}`);
  console.log(`Installing ${PACKAGE}@${VERSION} into ${installDir} ...`);
  execFileSync(
    'npm',
    ['install', '--prefix', installDir, '--no-save', '--no-audit', '--no-fund', '--ignore-scripts', '--loglevel=error',
      `${PACKAGE}@${VERSION}`],
    { stdio: 'inherit', shell: process.platform === 'win32' },
  );
  if (installedVersion() !== VERSION) fail(`npm did not install ${PACKAGE}@${VERSION}`);
}

// One icon's path, as the package draws it: each file is one <svg> with the 960-unit viewBox and one <path>, which the
// maps' <path d> takes unchanged. Anything else stops the script (it would need more than a path string).
const cache = new Map();
function iconPath(name) {
  if (cache.has(name)) return cache.get(name);
  const file = join(packageDir, STYLE, `${RENAMED[name] ?? name}${FILLED.has(name) ? '-fill' : ''}.svg`);
  if (!existsSync(file)) fail(`no icon "${name}" in ${PACKAGE}@${VERSION} (${relative(installDir, file)})`);
  const svg = readFileSync(file, 'utf8').trim();
  const shape = svg.match(/^<svg [^>]*viewBox="([^"]+)"[^>]*><path d="([^"]+)"\/><\/svg>$/);
  if (!shape) fail(`${file}: not one <path> in an <svg>`);
  if (shape[1] !== VIEW_BOX) fail(`${file}: viewBox "${shape[1]}", expected "${VIEW_BOX}"`);
  const d = shape[2];
  if (/['"\\]/.test(d)) fail(`${file}: unexpected characters in the path`);
  cache.set(name, d);
  return d;
}

let differs = 0;
function update(file, pattern, rebuild) {
  const absolute = join(root, file);
  const before = readFileSync(absolute, 'utf8');
  let count = 0;
  const changed = [];
  const after = before.replace(pattern, (...match) => {
    count += 1;
    const { text, name, old, path } = rebuild(match);
    if (old !== path) changed.push(name);
    return text;
  });
  if (count === 0) fail(`${file}: no icons found`);
  console.log(`${file}: ${count} icons, ${changed.length} redrawn${changed.length ? ` (${changed.join(', ')})` : ''}`);
  if (after === before) return;
  differs += 1;
  if (!check) writeFileSync(absolute, after);
}

for (const file of TS_MAPS) {
  update(file, /^( {2})([a-z0-9_]+)(: ')([^']*)(',)$/gm, ([, indent, name, colon, old, end]) => {
    const path = iconPath(name);
    return { text: `${indent}${name}${colon}${path}${end}`, name, old, path };
  });
}

for (const file of CSS_FILES) {
  update(file, /(%3Cpath id='([a-z0-9_]+)' d=')([^']*)(')/g, ([, start, name, old, end]) => {
    const path = iconPath(name);
    return { text: `${start}${path}${end}`, name, old, path };
  });
}

if (check && differs > 0) {
  console.error(`icons: ${differs} file(s) differ from ${PACKAGE}@${VERSION}; run: node tools/icons.mjs`);
  process.exit(1);
}
console.log(check ? 'The icons match the package.' : `Icons drawn from ${PACKAGE}@${VERSION} (${STYLE}).`);
