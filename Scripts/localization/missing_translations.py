#!/usr/bin/env python3
"""List catalog keys that still lack a translation for a language, as TSV.

Usage: missing_translations.py <Localizable.xcstrings> <lang>
Output columns: key, comment, (empty translation column to fill in).
Cells escape backslash, tab and newline as \\, \t and \n. Keys marked
shouldTranslate=false are skipped.
"""
import json
import sys


def escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n")


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    path, lang = sys.argv[1], sys.argv[2]
    with open(path, encoding="utf-8") as f:
        strings = json.load(f)["strings"]
    count = 0
    for key in sorted(strings):
        entry = strings[key]
        if entry.get("shouldTranslate") is False:
            continue
        unit = entry.get("localizations", {}).get(lang, {}).get("stringUnit", {})
        if unit.get("state") == "translated" and unit.get("value", "").strip():
            continue
        print("\t".join([escape(key), escape(entry.get("comment", "")), ""]))
        count += 1
    print(f"{count} keys missing [{lang}]", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
