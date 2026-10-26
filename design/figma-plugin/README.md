# Collarbell Bridge: building the Figma file from code

The designer's Figma file «Collarbell - основа дизайна» is built by scripts, not by hand.
Figma's free plan allows only a few remote calls a month, so a local plugin runs the
scripts inside the Figma app instead.

- `bridge.py`: a small server on this Mac (`localhost:8765`).
- `manifest.json`, `code.js`, `ui.html`: the "Collarbell Bridge" development plugin.
  While its window is open, it asks the server for jobs every second, runs them in the
  open file and sends back the result and PNGs.
- `lib.js` is put before every job. `jobs/_ds.js` holds component helpers, and
  `jobs/_screens.js` holds screen helpers.
- `jobs/1x_*.js` build the components on «Компоненты». `jobs/sNN_*.js` build the screens
  on «Экраны».
- `components.md` is the component catalogue: variants, properties and text layers.

## Running

1. Start the server:
   `python3 bridge.py serve --refs <app screenshots dir> --shots <output dir>`
2. Run the plugin: Figma app → open the file (owner account) → Plugins → Development →
   Collarbell Bridge. Import `manifest.json` once first (Plugins → Development → Import
   plugin from manifest). Keep the window open.
3. Run a job: `python3 bridge.py run jobs/_screens.js jobs/s03_pets.js`
   - It prints `{ok, value, error, stack, logs, ms}` and waits up to 10 minutes.
   - Jobs run one at a time in the order they arrive.
4. Syntax check without Figma: `node check.js jobs/_screens.js jobs/s03_pets.js`

The app screenshots (the refs) come from a widget test that renders every screen:
`render_screens_test.dart.txt`. Copy it into `mobile/test/` as a `.dart` file (it writes to `.refs`),
run `flutter test --no-pub` on that one file, then delete it (it isn't part of the suite).
`compare.sh REFS SHOTS OUT name.png` puts a ref and the Figma screen side by side.

## Writing a job

A job is the body of an async function, like a `use_figma` call:
- start with `await cbSetup();`;
- end with `return …` (JSON-friendly);
- `bridge.shot(node, name, scale)` saves a PNG to the shots dir;
- `bridge.ref(name)` gives an app screenshot as a Figma image;
- `bridge.log()` adds a line to the result.
- The file uses dynamic page loading: use async getters (`figma.getNodeByIdAsync`,
  `setTextStyleIdAsync`, `page.loadAsync()`).
- No endless loops: a stuck job blocks every job after it.

### lib.js

| Helper | What it does |
|---|---|
| `box(props, children)` | Auto-layout frame. Props: `name`, `dir` `'V'`/`'H'`/`'none'`, `gap`, `pad` (n, [v,h] or [t,r,b,l]), `fill`, `fillOpacity`, `stroke`, `strokeW`, `strokeSides {top,…}`, `radius` (n or [tl,tr,br,bl]), `align`/`justify` (`start`/`center`/`end`/`between`), `w`/`h` (number = fixed, `'fill'`, `'hug'`), `effect` (style name), `clip`, `opacity`. Gaps and paddings equal to a `space-*` token, and radii equal to a `radius-*` token, are bound to the variable. |
| `await text(chars, style, color, opts)` | Text in a text style (`title`, `body`, `body-sm`, `label`, `caption`, `subtitle`, `display-lg`, `numeral`, `code`, …) and colour token. Opts: `w` (`'fill'` or number), `align` (`'CENTER'`…), `lines` (max lines, cut with …), `name`. |
| `icon(name, size, color, filled)` | Material icon by ligature name. Outlined (Material Symbols Rounded) by default; `filled: true` uses Material Icons, the app's plain `Icons.x`. |
| `await inst(name, variant, props)` | Instance of a component (see `components.md`), e.g. `inst('Button', {Style: 'Primary', State: 'Default'}, {Label: 'Сохранить'})`. |
| `setText(node, layerName, chars)` | Changes a text layer inside an instance. |
| `sized(node, w, h)` | How a node sizes in its auto-layout parent (`'fill'`/`'hug'`), applied when added. |
| `add(parent, …children)` | Appends children and applies their sizing. |
| `paint(color, opacity)` | Paint bound to a colour variable. |
| `picture(image, w, h, radius)` | Rectangle filled with an image. |
| `await cbDone()` | Waits for shadows to apply. `place()` calls it. |

Colour tokens: `paper surface sunken line line-strong ink ink-muted ink-disabled primary
primary-strong on-primary primary-soft accent accent-text on-accent accent-soft danger
on-danger danger-soft success success-soft warning warning-soft inverse-surface on-inverse
inverse-primary coat-ginger coat-fawn coat-cocoa coat-smoke coat-lilac coat-ink on-coat`.

### _screens.js

| Helper | What it does |
|---|---|
| `screen(name, children, fill)` | 390-wide phone frame, children top to bottom. |
| `fitScreen(frame)` | Grows a short screen to 844; the child named `content` takes the spare height. |
| `float(frame, node, {left/right, top/bottom})` | Pins a node over the screen: FAB, sheet, dialog. |
| `scrim(frame)` | Dims the screen under a sheet or dialog. |
| `card(children, props)` | The app's card: surface, line border, radius lg, shadow-card. |
| `divider(indent)` | Line inside a card; 68 lines up with List row text. |
| `setAvatar(node, coat, letter)` | Sets the Pet avatar inside a row or instance. |
| `await place(area, slot, frame, refName)` | Puts the screen in its area section at column `slot`, with the app screenshot beside it and a caption above. Replaces an earlier version with the same frame name, and shoots the frame to `shots/<refName>`. |

Screens are named «Экран - состояние» (e.g. «Питомцы - список»). A scrolling screen is
built at its full height and placed with the `_full` screenshot.

## Rebuilding everything

Run these in order (each line is one `python3 bridge.py run …`). Later jobs depend on
the components; `s13_dialogs.js` copies the More screen from `s12_more.js`.

```
jobs/_ds.js jobs/10_avatar_status_switch.js     # then 11_bars, 12_rows, 13_overlays (with _ds.js)
jobs/14_fix_links.js … jobs/19_fix_strokes.js   # component fixes, in number order
jobs/_screens.js jobs/s01_auth.js               # likewise s02_today, s03_pets, s08_documents,
                                                # s09_visits_list, s09_visits_form, s10_feeding_form,
                                                # s12_more, s13_dialogs
jobs/_screens.js jobs/_pet_kit.js jobs/s04_pet_overview.js   # and s04_pet_health, s04_pet_passport,
                                                             # s05_pet_form, s07_passport_form
jobs/_screens.js jobs/s06_care_kit.js jobs/s06_care_presets.js   # and the other s06_care_*.js
jobs/_screens.js jobs/s11_kit.js jobs/s11_list.js                # and s11_detail, s11_form, s11_scan
jobs/91_remove_strays.js                        # loose icons left on other pages
```

Fresh component builds get new ids, so rebuild the screens after the components.
Images taller than 4096 px need a `_fit` copy (`magick x.png -resize x4096 x_fit.png`);
`place()` falls back to it.
