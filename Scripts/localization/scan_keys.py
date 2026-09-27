#!/usr/bin/env python3
"""Add SwiftUI/Foundation string-literal keys from the source tree to a String Catalog.

Usage: scan_keys.py <Localizable.xcstrings> [--check] [--roots LoopFollow Shared ...]
Reads Scripts/localization/localized_apis.txt: for every listed API, the first "…" literal
argument of `Api(` or `.api(` is a catalog key. Interpolated literals ("\\(") are skipped
with a warning (the compiler emits those with printf specifiers; add them from an
-exportLocalizations run). Keys added here carry extractionState "manual". With --check,
nothing is written and the exit code is 1 when keys are missing.
"""
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
API_LIST = HERE / "localized_apis.txt"


def literal_keys(roots):
    apis = [a.strip() for a in API_LIST.read_text().splitlines() if a.strip()]
    names = [re.escape(a.rstrip("(").rstrip(":")) for a in apis]
    pat = re.compile(r'(?<![\w.])\.?(' + "|".join(names) + r')\((?:localized:\s*)?"((?:[^"\\]|\\.)*)"')
    prompt = re.compile(r'prompt:\s*"((?:[^"\\]|\\.)*)"')
    keys, skipped = {}, []
    for root in roots:
        for f in sorted(pathlib.Path(root).rglob("*.swift")):
            src = f.read_text(encoding="utf-8")
            for m in pat.finditer(src):
                api, s = m.group(1), m.group(2)
                if api == "Text" and src[m.start():m.start() + 14].startswith("Text(verbatim"):
                    continue
                if not s.strip():
                    continue
                if src[m.end():m.end() + 8].lstrip().startswith("+"):
                    continue  # "a" + b: String concatenation, never looked up in the catalog
                if "\\(" in s:
                    skipped.append((f.name, s))
                    continue
                keys.setdefault(s.replace('\\"', '"').replace("\\n", "\n"), f.name)
            for m in prompt.finditer(src):
                s = m.group(1)
                if s.strip() and "\\(" not in s:
                    keys.setdefault(s, f.name)
    return keys, skipped


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__, file=sys.stderr)
        return 2
    path = pathlib.Path(args[0])
    check = "--check" in args
    roots = args[args.index("--roots") + 1:] if "--roots" in args else ["LoopFollow"]
    catalog = json.loads(path.read_text(encoding="utf-8"))
    strings = catalog["strings"]
    keys, skipped = literal_keys(roots)
    missing = sorted(k for k in keys if k not in strings)
    for f, s in skipped:
        print(f"skip (interpolated, needs compiler extraction): {f}: {s}", file=sys.stderr)
    if check:
        for k in missing:
            print(f"missing: {keys[k]}: {k!r}")
        print(f"{len(missing)} keys missing from {path}", file=sys.stderr)
        return 1 if missing else 0
    for k in missing:
        strings[k] = {"extractionState": "manual"}
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True, separators=(",", " : ")) + "\n", encoding="utf-8")
    print(f"added {len(missing)} keys", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
