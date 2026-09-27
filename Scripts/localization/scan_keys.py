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


def read_api_list():
    """Returns ({api_name: required_label_or_None}, ignored_labels).
    An entry like `String(localized:` means: calls to String( count, but only the literal
    carrying the `localized:` label is a key."""
    apis, ignored = {}, set()
    for line in API_LIST.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("!"):
            ignored.add(line[1:])
        elif "(" in line:
            name, label = line.split("(", 1)
            apis[name] = label.rstrip(":") or None
        else:
            apis[line] = None
    return apis, ignored


def call_literals(src, open_paren):
    """Yield (label, literal, interpolated) for direct string-literal arguments of the call whose
    "(" is at open_paren. Nested calls/arrays are skipped; interpolated literals are flagged."""
    i = open_paren + 1
    depth_paren, depth_bracket = 0, 0
    label = None
    expect_value = True  # right after "(" or ","
    n = len(src)
    while i < n:
        c = src[i]
        if c == '"':
            j = i + 1
            interpolated = False
            while j < n and src[j] != '"':
                if src[j] == "\\":
                    if j + 1 < n and src[j + 1] == "(":
                        interpolated = True
                    j += 2
                    continue
                j += 1
            lit = src[i + 1:j]
            if depth_paren == 0 and depth_bracket == 0 and expect_value:
                yield label, lit, interpolated
            expect_value = False
            i = j + 1
            continue
        if c == "(":
            depth_paren += 1
        elif c == ")":
            if depth_paren == 0:
                return
            depth_paren -= 1
        elif c == "[":
            depth_bracket += 1
        elif c == "]":
            depth_bracket -= 1
        elif c == "," and depth_paren == 0 and depth_bracket == 0:
            label = None
            expect_value = True
        elif c == ":" and depth_paren == 0 and depth_bracket == 0 and expect_value:
            m = re.search(r"(\w+)\s*$", src[max(0, i - 40):i])
            label = m.group(1) if m else None
        elif not c.isspace() and c not in ":" and expect_value:
            # an identifier/expression as the value (e.g. `title: route.title`) is not a literal
            m = re.match(r"\w+\s*:", src[i:i + 40])
            if not m:
                expect_value = False
        i += 1


def literal_keys(roots):
    apis, ignored = read_api_list()
    names = "|".join(re.escape(a) for a in apis)
    call = re.compile(r"(?<![\w.])\.?(" + names + r")\(")
    keys, skipped = {}, []
    for root in roots:
        for f in sorted(pathlib.Path(root).rglob("*.swift")):
            src = f.read_text(encoding="utf-8")
            for m in call.finditer(src):
                if m.group(1) == "Text" and src[m.start():m.start() + 14].startswith("Text(verbatim"):
                    continue
                required = apis.get(m.group(1))
                for label, lit, interpolated in call_literals(src, m.end() - 1):
                    if label in ignored or not lit.strip():
                        continue
                    if required is not None and label != required:
                        continue
                    if interpolated:
                        skipped.append((f.name, lit))
                        continue
                    keys.setdefault(lit.replace('\\"', '"').replace("\\n", "\n"), f.name)
            # "…" + x concatenation is never looked up: drop any key that only appears before a "+"
    # remove literals that are immediately followed by a "+" (String concatenation)
    for root in roots:
        for f in sorted(pathlib.Path(root).rglob("*.swift")):
            src = f.read_text(encoding="utf-8")
            for m in re.finditer(r'"((?:[^"\\]|\\.)*)"\s*\+', src):
                keys.pop(m.group(1).replace('\\"', '"').replace("\\n", "\n"), None)
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
