// Syntax check of a job the way the plugin compiles it: node check.js jobs/_ds.js jobs/x.js
const fs = require('fs');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const code = ['lib.js', ...process.argv.slice(2)].map((f) => fs.readFileSync(f, 'utf8')).join('\n');
try { new AsyncFunction('bridge', code); console.log('ok'); } catch (e) { console.log(e.message); process.exit(1); }
