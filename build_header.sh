#!/usr/bin/env python3
"""
build_header.py
Usage:
  ./build_header.py "tag1,tag2|tag3" metadata.toml mappings.json
"""
import sys
import json
import difflib
import re
from pathlib import Path

def normalize(s):
    s = s.lower()
    s = s.replace('_', ' ').replace('-', ' ').strip()
    s = re.sub(r'\s+', ' ', s)
    return s

def load_mappings(path):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    entries = []
    for e in data.get("entries", []):
        # prepare normalized key forms
        keys = [normalize(k) for k in e.get("keys", [])]
        entries.append({
            "keys": keys,
            "label": e.get("label"),
            "priority": int(e.get("priority", 0))
        })
    return entries

def best_matches_for_tag(tag, mappings, cutoff=0.6):
    """
    Return list of (score, mapping) for the tag.
    Score uses difflib ratio over normalized strings.
    """
    tag_n = normalize(tag)
    results = []
    for m in mappings:
        # exact match via keys first
        for k in m["keys"]:
            if tag_n == k:
                results.append((1.0 + m["priority"]/100.0, m))
                break
        else:
            # fuzzy against each key
            scores = [difflib.SequenceMatcher(None, tag_n, k).ratio() for k in m["keys"]]
            best = max(scores) if scores else 0.0
            # augment score with priority
            score = best + m["priority"]/100.0
            if best >= cutoff:
                results.append((score, m))
    # sort by score desc
    results.sort(key=lambda x: x[0], reverse=True)
    return results

def select_phrases(tags, mappings, max_phrases=3):
    candidates = []
    for tag in tags:
        hits = best_matches_for_tag(tag, mappings)
        for score, m in hits:
            candidates.append((score, m["label"]))
    # dedupe by label keeping highest score
    seen = {}
    for score, label in candidates:
        if label not in seen or seen[label] < score:
            seen[label] = score
    # sort labels by score desc then by label
    sorted_labels = sorted(seen.items(), key=lambda x: (-x[1], x[0]))
    selected = [lbl for lbl, sc in sorted_labels[:max_phrases]]
    return selected

def update_metadata_toml(path, header_quote_value):
    text = Path(path).read_text(encoding='utf-8')
    lines = text.splitlines()
    out = []
    in_lang_de = False
    replaced = False
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        if re.match(r'^\s*\[lang\.de\]\s*$', line):
            in_lang_de = True
            i += 1
            # process following lines until next table or EOF
            # collect block
            block = []
            while i < len(lines) and not re.match(r'^\s*\[.+\]\s*$', lines[i]):
                block.append(lines[i])
                i += 1
            # attempt to replace header_quote inside block
            new_block = []
            found = False
            for b in block:
                if re.match(r'^\s*header_quote\s*=.*$', b):
                    new_block.append(f'    header_quote = "{header_quote_value}"')
                    found = True
                else:
                    new_block.append(b)
            if not found:
                # insert header_quote after [lang.de] (which we've already output)
                new_block.insert(0, f'    header_quote = "{header_quote_value}"')
            out.extend(new_block)
            if not found:
                replaced = True
            else:
                replaced = True
            continue
        i += 1

    if not replaced:
        # append at end
        out.append('')
        out.append('[lang.de]')
        out.append(f'    header_quote = "{header_quote_value}"')

    new_text = '\n'.join(out) + '\n'
    Path(path).write_text(new_text, encoding='utf-8')

def main():
    if len(sys.argv) < 4:
        print("Usage: build_header.py TAGS metadata.toml mappings.json", file=sys.stderr)
        sys.exit(2)
    tags_raw = sys.argv[1]
    metadata = Path(sys.argv[2])
    mapping_file = Path(sys.argv[3])
    if not metadata.exists():
        print("metadata.toml not found", file=sys.stderr); sys.exit(2)
    if not mapping_file.exists():
        print("mappings.json not found", file=sys.stderr); sys.exit(2)

    # normalize separators (comma/;/|/whitespace) -> split
    tags_norm = re.sub(r'[,;|]+', ' ', tags_raw)
    tags_norm = re.sub(r'\s+', ' ', tags_norm).strip()
    tags = [t for t in tags_norm.split(' ') if t]

    mappings = load_mappings(mapping_file)
    selected = select_phrases(tags, mappings, max_phrases=3)

    if not selected:
        body = "Allgemeine IT‑Kompetenzen"
    else:
        body = " · ".join(selected)

    headline = f"Analyst & Entwickler — {body}"
    # write to metadata.toml
    update_metadata_toml(metadata, headline)
    print("Updated", metadata, "with header_quote:")
    print(headline)

if __name__ == "__main__":
    main()
