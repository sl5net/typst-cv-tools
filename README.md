README — typst-cv-tools
typst-cv-tools

Ein kleines Toolkit, das Typst‑CV‑Projekte automatisiert:

    Generiert eine lesbare Headline (header_quote) aus Tags (mapping + Fuzzy‑Match).
    Maskiert persönliche Daten in metadata.toml (alle personal*-Tabellen).
    Hilft bei der Team‑Verteilung von sprachlich gepflegten Labeln (mappings.json).

Inhalt des Repos (Beispiel)

    build_header.py — generiert eine Headline aus Tags und aktualisiert metadata.toml.
    prehook_personal_regex_all.py — ersetzt Werte in allen personal-Scopes durch ihre Schlüsselnamen (oder entfernt bestimmte Keys).
    mappings.json — menschengepflegte Mapping‑Datei (Tag → Label, Priority).
    hooks/pre-commit — optionaler Git‑Hook zum lokalen Ausführen.
    scripts/install-hooks.sh — installiert lokale Hooks.
    .gitignore — enthält u. a. * * (ignoriert Pfade mit Leerzeichen).
    README.md (diese Datei)

Quickstart — lokal

Voraussetzungen:

    Python 3.8+ (für die Python‑Skripte)
    optional: tomlkit falls du die tomlkit‑Variante nutzen willst (siehe weiter unten)

    Repository klonen:

bash
git clone git@github.com:youruser/typst-cv-tools.git
cd typst-cv-tools

    (Optional) virtuelle Umgebung & Abhängigkeiten:

bash
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install tomlkit   # nur falls du tomlkit-basierte Skripte verwenden willst

    Scripts ausführbar machen:

bash
chmod +x build_header.py prehook_personal_regex_all.py scripts/install-hooks.sh hooks/pre-commit

    Beispiel ausführen:

bash
# Generiere header_quote und schreibe es nach metadata.toml (benutze mappings.json)
./build_header.py "Python,Docker,CI/CD" metadata.toml mappings.json

# Maskiere persönliche Werte in allen personal-Scopes
./prehook_personal_regex_all.py metadata.toml

    Typst Build (wie üblich):

bash
typst compile resume.typst -o resume.pdf

oder:

typst_compile_cv.sh

recomandet
