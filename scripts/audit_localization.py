#!/usr/bin/env python3
"""Find (and optionally remove) unused localization keys.

The audit is KEY-based, not accessor-based. Two accessors can point at the same
key (`commonOK` and `commonOk` both resolve to "common.ok"), so counting
accessors would wrongly mark a live key dead.

It also resolves keys used as raw literals - `"settings.category.about".localized()`
in SettingsView never goes through a LocalizedString accessor, and an audit that
only greps for `LocalizedString.x` would delete four keys that are very much in use.

This matters because a wrongly deleted key fails *silently*: `.localized()`
returns the key name, so the user sees "about.reset.button" as visible UI text.

Usage:
    python3 scripts/audit_localization.py           # report only
    python3 scripts/audit_localization.py --apply   # prune accessors and keys
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "MouseGuide" / "Sources"
LOCALIZABLE = SOURCES / "Localizable.swift"
STRINGS = [
    ROOT / "MouseGuide" / "Resources" / "en.lproj" / "Localizable.strings",
    ROOT / "MouseGuide" / "Resources" / "da.lproj" / "Localizable.strings",
]

ACCESSOR_DECL = re.compile(r"^\s*static\s+(?:var|func)\s+(\w+)")
LOCALIZED_KEY = re.compile(r'"([^"\\]+)"\.localized\(\)')
STRINGS_KEY = re.compile(r'^\s*"([^"]+)"\s*=')


def parse_accessors():
    """Map accessor name -> {keys it references}, and -> (start, end) line span."""
    lines = LOCALIZABLE.read_text(encoding="utf-8").split("\n")
    keys, spans = {}, {}
    current, depth, start = None, 0, None

    for i, line in enumerate(lines):
        decl = ACCESSOR_DECL.match(line)
        if decl and current is None:
            current, start = decl.group(1), i
            keys.setdefault(current, set())
            depth = 0

        if current is not None:
            depth += line.count("{") - line.count("}")
            keys[current].update(LOCALIZED_KEY.findall(line))
            if depth <= 0 and "{" in "".join(lines[start : i + 1]):
                spans[current] = (start, i)
                current = None

    return keys, spans, lines


def used_accessors():
    names = set()
    for path in sorted(SOURCES.glob("*.swift")):
        if path == LOCALIZABLE:
            continue
        for match in re.finditer(r"LocalizedString\.(\w+)", path.read_text(encoding="utf-8")):
            names.add(match.group(1))
    return names


def raw_literal_keys():
    """Keys used directly as string literals, bypassing LocalizedString."""
    found = set()
    for path in sorted(SOURCES.glob("*.swift")):
        if path == LOCALIZABLE:
            continue
        found.update(LOCALIZED_KEY.findall(path.read_text(encoding="utf-8")))
    return found


def main():
    apply = "--apply" in sys.argv

    accessor_keys, accessor_spans, loc_lines = parse_accessors()
    used = used_accessors()
    raw_keys = raw_literal_keys()

    unused_accessors = sorted(set(accessor_keys) - used)
    used_keys = {k for name in used for k in accessor_keys.get(name, ())} | raw_keys

    all_keys = {}
    for path in STRINGS:
        all_keys[path] = [
            m.group(1) for m in (STRINGS_KEY.match(l) for l in path.read_text(encoding="utf-8").split("\n")) if m
        ]

    dead_keys = sorted(set(all_keys[STRINGS[0]]) - used_keys)

    print(f"Accessors:        {len(accessor_keys)} defined, {len(unused_accessors)} unused")
    print(f"Raw literal keys: {len(raw_keys)} ({', '.join(sorted(raw_keys)) or 'none'})")
    print(f"Keys:             {len(all_keys[STRINGS[0]])} in en.lproj, {len(dead_keys)} dead")

    if not apply:
        print("\nDead keys:")
        for k in dead_keys:
            print(f"  {k}")
        print("\nRe-run with --apply to prune.")
        return 0

    # Prune accessors (whole declaration, which may span several lines)
    drop = set()
    for name in unused_accessors:
        if name in accessor_spans:
            start, end = accessor_spans[name]
            drop.update(range(start, end + 1))
    kept = [l for i, l in enumerate(loc_lines) if i not in drop]
    # Collapse the runs of blank lines left behind by removed declarations
    collapsed = []
    for line in kept:
        if line.strip() == "" and collapsed and collapsed[-1].strip() == "":
            continue
        collapsed.append(line)
    LOCALIZABLE.write_text("\n".join(collapsed), encoding="utf-8")
    print(f"\nRemoved {len(unused_accessors)} accessors ({len(drop)} lines) from Localizable.swift")

    # Prune keys from both .strings files
    dead = set(dead_keys)
    for path in STRINGS:
        out = []
        for line in path.read_text(encoding="utf-8").split("\n"):
            m = STRINGS_KEY.match(line)
            if m and m.group(1) in dead:
                continue
            if line.strip() == "" and out and out[-1].strip() == "":
                continue
            out.append(line)
        path.write_text("\n".join(out), encoding="utf-8")
        print(f"Pruned {path.relative_to(ROOT)}")

    # The two files must stay in lockstep, or one language silently shows key names
    sets = []
    for path in STRINGS:
        sets.append({m.group(1) for m in (STRINGS_KEY.match(l) for l in path.read_text(encoding="utf-8").split("\n")) if m})
    if sets[0] != sets[1]:
        only_en = sorted(sets[0] - sets[1])
        only_da = sorted(sets[1] - sets[0])
        print(f"\nFAIL: key sets differ. Only en: {only_en}. Only da: {only_da}")
        return 1

    print(f"\nOK: both .strings files contain the same {len(sets[0])} keys")
    return 0


if __name__ == "__main__":
    sys.exit(main())
