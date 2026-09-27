#!/usr/bin/env python3
"""Write translations from a TSV (key<TAB>comment<TAB>value) into a String Catalog.

Usage: apply_translations.py <Localizable.xcstrings> <lang> <translations.tsv>
Cells use the escapes written by missing_translations.py (\\, \t, \n). Rows with an
empty value are skipped. Keys not present in the catalog are reported and skipped.
The catalog is rewritten in Xcode's own style (2-space indent, " : " separator, sorted keys).
"""
import json
import sys


def unescape(s: str) -> str:
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            nxt = s[i + 1]
            out.append({"n": "\n", "t": "\t", "\\": "\\"}.get(nxt, "\\" + nxt))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    path, lang, tsv = sys.argv[1:4]
    with open(path, encoding="utf-8") as f:
        catalog = json.load(f)
    strings = catalog["strings"]
    applied, unknown = 0, []
    with open(tsv, encoding="utf-8") as f:
        for line in f.read().split("\n"):
            cells = line.split("\t")
            if len(cells) < 3 or not cells[2].strip():
                continue
            key, value = unescape(cells[0]), unescape(cells[2])
            if key not in strings:
                unknown.append(key)
                continue
            strings[key].setdefault("localizations", {})[lang] = {"stringUnit": {"state": "translated", "value": value}}
            applied += 1
    with open(path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : "))
        f.write("\n")
    print(f"applied {applied} [{lang}] translations", file=sys.stderr)
    if unknown:
        print("unknown keys (not in catalog):\n  " + "\n  ".join(unknown), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
