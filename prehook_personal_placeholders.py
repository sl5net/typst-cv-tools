#!/usr/bin/env python3
"""
prehook_personal_regex_all.py
Setzt in metadata.toml in allen TOML-Tabellen, deren Name mit "personal" endet oder startet,
jedes key = "..." auf key = "key".

Usage:
  ./prehook_personal_regex_all.py metadata.toml

Behavior:
  - Arbeitet zeilenorientiert (keine externen Pakete)
  - Sichert die Originaldatei als metadata.toml.bak
  - Findet Tabellen wie: [personal], [personal.info], [lang.de.personal], [lang.de.personal.info]
  - Ersetzt nur einfache key = "value" / key = 'value' Einträge (keine komplexen Mehrzeilen-Strings)
"""
import sys
import re
from pathlib import Path

KV_RE = re.compile(r'^(\s*)([A-Za-z0-9_\-]+)\s*=\s*([\'"])(.*?)(\3)(\s*(#.*)?)?$')
TABLE_RE = re.compile(r'^\s*\[([^\]]+)\]\s*$')

def is_personal_table(table_name):
    # Matches table names that are exactly 'personal' or end/start with personal segments.
    # Examples matched: "personal", "personal.info", "lang.de.personal", "lang.de.personal.info"
    parts = table_name.split('.')
    return any(part.strip().lower() == 'personal' for part in parts)

def process(path: Path):
    text = path.read_text(encoding='utf-8')
    lines = text.splitlines()
    out = []
    in_personal_scope = False

    for line in lines:
        m_table = TABLE_RE.match(line)
        if m_table:
            tbl = m_table.group(1).strip()
            in_personal_scope = is_personal_table(tbl)
            out.append(line)
            continue

        if in_personal_scope:
            m_kv = KV_RE.match(line)
            if m_kv:
                indent, key, quote, val, _closing_quote, trailing = m_kv.group(1), m_kv.group(2), m_kv.group(3), m_kv.group(4), m_kv.group(5), m_kv.group(6) or ""
                # Replace value with the key name (keep same quoting style and any trailing comment)
                out.append(f'{indent}{key} = {quote}{key}{quote}{trailing}')
                continue
            # If line is not a simple kv pair, keep as-is (handles comments, blank lines, subtables)
        out.append(line)

    # Backup and write
    bak = path.with_suffix(path.suffix + ".bak")
    bak.write_bytes(path.read_bytes())
    path.write_text("\n".join(out) + "\n", encoding='utf-8')
    print(f"Updated {path} (backup: {bak})")

def main():
    if len(sys.argv) < 2:
        print("Usage: prehook_personal_regex_all.py metadata.toml", file=sys.stderr)
        sys.exit(2)
    p = Path(sys.argv[1])
    if not p.exists():
        print("File not found:", p, file=sys.stderr)
        sys.exit(2)
    process(p)

if __name__ == "__main__":
    main()
