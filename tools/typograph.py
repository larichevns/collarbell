#!/usr/bin/env python3
"""Keeps short Russian words off the end of a line (no "hanging prepositions").

    python3 tools/typograph.py           # fixes the files in place
    python3 tools/typograph.py --check   # exits 1 if a file still needs it (CI)

A non-breaking space (U+00A0) replaces the ordinary space:
  * after a short word: any word of one or two Cyrillic letters ("в", "на",
    "не", "и") and the three-letter prepositions and "или";
  * before "ли", "же", "бы" (they belong to the word before them);
  * between a number and the word after it ("2 дня", "40 г"), also after a
    placeholder ("{count} дня", "# дней", "${days} дн.");
  * before a dash ("Мурка — кошка"), so a line never starts with one.

In page markup (.astro, .tsx) a line break between words is a space too, so a
short word at the end of a source line joins the next line with U+00A0 when
that line starts with a word or a number.

Only the ordinary space U+0020 is replaced, so a second run changes nothing.
Russian text only: the rules need a Cyrillic word, so code, English text and
identifiers stay as they are. The files are the Russian texts of the app
(ARB), the web app, the admin and the site; their tests use the same words.

Standard library only.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Russian texts. Globs are relative to the repository root.
FILES = [
    "mobile/lib/l10n/app_ru.arb",
    "web/src/i18n/ru.ts",
    "admin/src/**/*.ts",
    "admin/src/**/*.tsx",
    "landing/src/**/*.astro",
    "landing/src/**/*.ts",
]

NBSP = " "
CYR = "а-яёА-ЯЁ"

# Words that stick to the next word: one or two letters, and the longer
# prepositions and conjunctions that read as one with the word after them.
LONG_SHORT_WORDS = {"без", "для", "над", "под", "при", "про", "обо", "ото", "изо", "или"}
# Particles that belong to the word before them instead.
PARTICLES = {"ли", "ль", "же", "ж", "бы", "б"}

_word_then_space = re.compile(rf"(?<![\w\-])([{CYR}]{{1,3}}) (?=\S)")
_space_then_particle = re.compile(rf"(?<=\S) ({'|'.join(sorted(PARTICLES, key=len, reverse=True))})(?![\w])")
_number_then_word = re.compile(rf"(?<=[\d#}}]) (?=[{CYR}%№])")
_space_then_dash = re.compile(r"(?<=\S) (?=[—–] )")
_number_sign = re.compile(r"№ (?=\d)")


# Markup only: a short word or a number at the end of a source line, then the
# next line's indentation and a word (not a tag, comment or code).
_MARKUP = {".astro", ".tsx"}
_word_then_break = re.compile(rf"(?<![\w\-])([{CYR}]{{1,3}})\n[ \t]*(?=[{CYR}\d«])")
_number_then_break = re.compile(rf"(?<=\d)\n[ \t]*(?=[{CYR}])")


def _bind_short(match: re.Match[str]) -> str:
    word = match.group(1)
    if word.lower() in PARTICLES:
        return match.group(0)
    if len(word) <= 2 or word.lower() in LONG_SHORT_WORDS:
        return word + NBSP
    return match.group(0)


def typograph(text: str, markup: bool = False) -> str:
    """The text with non-breaking spaces where Russian typography wants them.

    [markup]: the text is page markup, where a line break is a space too.
    """
    if markup:
        # The match takes the line break and indentation, so binding drops them.
        text = _word_then_break.sub(_bind_short, text)
        text = _number_then_break.sub(NBSP, text)
    previous = None
    # A chain like "и в то" needs a second pass: the first one only sees words
    # that an ordinary space separates.
    while previous != text:
        previous = text
        text = _word_then_space.sub(_bind_short, text)
    text = _space_then_particle.sub(NBSP + r"\1", text)
    text = _number_then_word.sub(NBSP, text)
    text = _space_then_dash.sub(NBSP, text)
    return _number_sign.sub("№" + NBSP, text)


def files() -> list[Path]:
    found: list[Path] = []
    for pattern in FILES:
        found.extend(sorted(p for p in ROOT.glob(pattern) if p.is_file() and "node_modules" not in p.parts))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="only report, exit 1 if a file needs fixing")
    args = parser.parse_args()

    stale: list[str] = []
    for path in files():
        text = path.read_text(encoding="utf-8")
        fixed = typograph(text, markup=path.suffix in _MARKUP)
        if fixed == text:
            continue
        name = str(path.relative_to(ROOT))
        stale.append(name)
        if not args.check:
            path.write_text(fixed, encoding="utf-8")
            print(f"fixed {name}")
    if args.check and stale:
        print("Short words can end a line in:", *stale, sep="\n  ", file=sys.stderr)
        print("Run: python3 tools/typograph.py", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
