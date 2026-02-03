#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

RELATION = {"usp.", "v.", "opr.", "izv."}

def parse_lines(text: str):
    out = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        # ignore obvious section headers
        if line.lower().startswith("and there is even more"):
            continue

        # split by TAB primarily; if not present, split by >=2 spaces
        if "\t" in line:
            parts = [p.strip() for p in line.split("\t") if p.strip()]
        else:
            parts = [p.strip() for p in re.split(r"\s{2,}", line) if p.strip()]

        if len(parts) < 2:
            continue

        abbr = parts[0]
        meaning = parts[1]

        # normalize abbr spacing (e.g. "pl. tantum  pluralia tantum" weirdness)
        abbr = re.sub(r"\s+", " ", abbr).strip()
        meaning = re.sub(r"\s+", " ", meaning).strip()

        out.append((abbr, meaning))
    return out

def classify(abbr: str, meaning: str, is_language_list: bool):
    if abbr in RELATION:
        return "relation"
    if is_language_list:
        return "language"
    return "label"

def main():
    if len(sys.argv) < 3:
        print("Usage: make_abbr_json.py OUT.json IN1.txt [IN2.txt ...]", file=sys.stderr)
        sys.exit(2)

    out_path = Path(sys.argv[1])
    in_paths = [Path(p) for p in sys.argv[2:]]

    merged = {}
    # heuristic: if filename contains "lang" treat as language list
    for p in in_paths:
        text = p.read_text(encoding="utf-8")
        is_lang = "lang" in p.name.lower() or "language" in p.name.lower()

        for abbr, meaning in parse_lines(text):
            kind = classify(abbr, meaning, is_lang)

            # If key already exists, keep the "relation" kind if any,
            # otherwise prefer "language" over "label".
            if abbr in merged:
                prev = merged[abbr]
                prev_kind = prev["kind"]
                # upgrade priority: relation > language > label
                prio = {"relation": 3, "language": 2, "label": 1}
                if prio[kind] > prio[prev_kind]:
                    prev_kind = kind
                # If meanings differ, keep both (rare but happens like "ant.")
                if meaning != prev["meaning"]:
                    # store as list to preserve information
                    if isinstance(prev["meaning"], list):
                        if meaning not in prev["meaning"]:
                            prev["meaning"].append(meaning)
                    else:
                        prev["meaning"] = [prev["meaning"], meaning]
                prev["kind"] = prev_kind
            else:
                merged[abbr] = {"kind": kind, "meaning": meaning}

    payload = {"abbr": merged}
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {out_path} with {len(merged)} entries")

if __name__ == "__main__":
    main()
