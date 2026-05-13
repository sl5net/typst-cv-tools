#!/usr/bin/env python3
# tools/translate_typst.py
#

TODO: Die Einrückungen fehlen in der Ausgabe. Sind in typst auch nicht sehr relevant.
Es benötigt noch ein bisschen manuelle Nacharbeit und die Warnungen stöhren sehr in der Konsole. Besser werg filtern
(s, 13.5.'26 12:01 Wed)



# Intelligenter Typst-Übersetzer — v3.4
# ======================================
# Architektur: translate_md.py (robust, klar strukturiert)
# Korrekturen: alle Fixes aus translate_typst.py v1 (99%)
# Neu in v3.2: Zeilenbasierter JSON-Übersetzungscache
# Neu in v3.3: tags:(...) mehrzeilig, *kursiv:*/**fett:** geschützt,
#              Placeholder-Repair für "TYPE" Variante
# Neu in v3.4: #link(...)[text] vollständig geschützt,
#              Cache-Selbstreinigung beim Start (purge_invalid)
#
# ANFORDERUNGEN:
#   - Python 3
#   - `translate-shell` muss im System-PATH installiert sein (`trans` Befehl)
#
# FUNKTIONSWEISE:
#   Jede übersetzte Datei landet in einem .i18n-Unterordner:
#   modules_de/teaching.typ  →  modules_de/teaching.i18n/teaching-enlang.typ
#
# CACHE:
#   Jede übersetzte Zeile wird in tools/translation-cache-{lang}.json gespeichert.
#   Format:  { "Originalzeile": "Übersetzte Zeile", ... }
#   Beim nächsten Lauf wird der Cache zuerst geprüft — kein trans-Aufruf nötig.
#   Der Cache ist manuell editierbar, um Übersetzungen zu korrigieren.
#
# PLATZHALTER-SYSTEM:
#   Geschützte Typst-Elemente werden durch "XTYPCMD{n}X" ersetzt, damit der
#   Übersetzer sie nicht verändert. Nach der Übersetzung werden sie wiederhergestellt.

import glob
import json
import logging
import re
import subprocess
import time
from pathlib import Path

# ==============================================================================
# KONFIGURATION
# ==============================================================================

SOURCE_LANG = "de"
TARGET_LANGS = ["en"]  # Erweitern nach Bedarf: ["en", "fr", "es"]

TYPST_CMD_PLACEHOLDER_FORMAT = "XTYPCMD{}X"

script_dir = Path(__file__).resolve().parent

# ==============================================================================
# LOGGING
# ==============================================================================

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger()


# ==============================================================================
# CACHE
# ==============================================================================

class TranslationCache:
    """
    Zeilenbasierter JSON-Cache für Übersetzungen.

    Datei: tools/translation-cache-{lang}.json
    Format: { "Originalzeile": "Übersetzte Zeile", ... }

    Workflow:
      1. get(line)   → Treffer? Sofort zurück. Kein trans-Aufruf.
      2. set(line, translation) → Neuen Eintrag hinzufügen + sofort speichern.

    Der Cache ist bewusst einfach gehalten: ein flaches Dict, manuell editierbar,
    git-freundlich (eine Zeile pro Eintrag durch json.dumps mit indent=2).
    """

    def __init__(self, lang: str) -> None:
        self.lang = lang
        self.path = script_dir / f"translation-cache-{lang}.json"
        self._data: dict[str, str] = {}
        self._load()

    def _load(self) -> None:
        """Lädt den Cache aus der JSON-Datei. Erstellt eine leere Datei falls nötig."""
        if self.path.exists():
            try:
                with open(self.path, "r", encoding="utf-8") as f:
                    self._data = json.load(f)
                logger.info(f"   Cache geladen: {self.path.name} ({len(self._data)} Einträge)")
            except (json.JSONDecodeError, OSError) as e:
                logger.warning(f"   Cache-Datei beschädigt, starte leer: {e}")
                self._data = {}
        else:
            logger.info(f"   Kein Cache gefunden, wird neu erstellt: {self.path.name}")
            self._data = {}

    def _save(self) -> None:
        """Schreibt den gesamten Cache auf Disk. Wird nach jedem neuen Eintrag aufgerufen."""
        try:
            with open(self.path, "w", encoding="utf-8") as f:
                json.dump(self._data, f, ensure_ascii=False, indent=2)
        except OSError as e:
            logger.error(f"   [FEHLER] Cache konnte nicht gespeichert werden: {e}")

    def get(self, source_line: str) -> str | None:
        """Gibt die gecachte Übersetzung zurück, oder None bei Cache-Miss."""
        return self._data.get(source_line)

    def set(self, source_line: str, translated_line: str) -> None:
        """Speichert eine neue Übersetzung und persistiert den Cache sofort."""
        self._data[source_line] = translated_line
        self._save()

    def purge_invalid(self) -> int:
        """
        Entfernt Cache-Einträge die bekannte Fehler enthalten:
        - Wert enthält nicht wiederhergestellte Platzhalter (XTYPCMD...X)
        - Key enthält 'tags:' — diese Zeilen wurden vor dem mehrzeiligen
          tags-Fix falsch zerstückelt gecacht und müssen neu übersetzt werden.
        Gibt die Anzahl gelöschter Einträge zurück.
        """
        bad_keys = [
            key for key, val in self._data.items()
            if re.search(r"X\s*TYP(?:E)?\s*CMD\s*\d+\s*X", val, re.IGNORECASE)
            or "tags:" in key
        ]
        for key in bad_keys:
            del self._data[key]
        if bad_keys:
            self._save()
            logger.info(f"   Cache bereinigt: {len(bad_keys)} ungültige Einträge entfernt.")
        return len(bad_keys)

    def __len__(self) -> int:
        return len(self._data)


# ==============================================================================
# SCHRITT 1: SCHÜTZE TYPST-SYNTAX VOR DER ÜBERSETZUNG
# ==============================================================================

def protect_typst_syntax(content: str) -> tuple[str, list[str]]:
    """
    Ersetzt alle Typst-spezifischen Elemente durch Platzhalter,
    damit der Übersetzer sie nicht verändert.

    Reihenfolge ist entscheidend:
    1. Kommentare zuerst (verhindert Doppel-Match von auskommentierten Imports)
    2. Import/Include-Zeilen komplett bis Zeilenende — schützt auch Export-Namen
       wie `: cv`, `: *`, `: cv-entry as org-entry, h-bar`
    3. Links, Tags, Bilder, Metadaten
    4. Parameter-Keys (z.B. title:)
    """
    protected_elements: list[str] = []

    def replacer(match: re.Match) -> str:
        placeholder = TYPST_CMD_PLACEHOLDER_FORMAT.format(len(protected_elements))
        protected_elements.append(match.group(0))
        return placeholder

    # 1. Kommentare (// einzeilig und /* ... */ mehrzeilig)
    content = re.sub(r"(//.*|/\*[\s\S]*?\*/)", replacer, content)

    # 2. Imports und Includes KOMPLETT — inklusive aller Export-Namen nach dem ':'
    #    Beispiele die alle abgedeckt sein müssen:
    #      #import "helpers.typ": *
    #      #import "@preview/brilliant-cv:3.1.2": cv
    #      #import "@preview/brilliant-cv:3.1.2": cv-entry as org-entry, h-bar, cv-skill
    #      #include "modules_de/teaching.typ"
    #    Strategie: Alles bis zum Zeilenende schützen, da Export-Listen nie über
    #    mehrere Zeilen gehen.
    content = re.sub(r"#(?:import|include)\s+.*$", replacer, content, flags=re.MULTILINE)

    # 3. Links — komplett schützen: URL-Klammer + optionaler Linktext-Block
    #    Beispiele:
    #      #link("https://stackoverflow.com/users/...")[stackoverflow.com/sl5net]
    #      #link("https://example.com")
    # content = re.sub(r"#link\([^)]+\)(?:\[[^\]]*\])?", replacer, content)
    content = re.sub(r'#link\(".*?"\)(\[.*?\])?', replacer, content)

    # 4. Tags-Listen — komplett schützen, auch mehrzeilig
    #    Beispiel: tags: ("KI", "Python", "RegEx")
    content = re.sub(r"tags:\s*\([\s\S]*?\)", replacer, content)

    # 5. Bilder und Metadaten
    content = re.sub(r'image\("[^"]+"\)', replacer, content)
    content = re.sub(r"metadata\.[a-zA-Z0-9._]+", replacer, content)


    # 6. Typst-Inline-Markup: *kursiv:* und **fett:** — das angehängte ':' darf
    #    nicht als Parameter-Key erkannt werden (würde Markup zerstückeln).
    #    Muster: *Wort:* oder **Wort:** am Zeilenanfang oder nach '['.
    content = re.sub(r"\*{1,2}[^*\n]+:\*{1,2}", replacer, content)
    content = re.sub(r"\*\*(.*?)\*\*", r"*\1*", content)

    # Jetzt schützen wir das gültige Typst-Markup *Wort:*
    content = re.sub(r"\*[^*\n]+:\*", replacer, content)

    # 7. Parameter-Keys (z.B. title:, date:, author:) — NACH Markup-Schutz
    content = re.sub(r"([a-zA-Z0-9_-]+:)\s*", replacer, content)

    return content, protected_elements


# ==============================================================================
# SCHRITT 2: ÜBERSETZEN — MIT CACHE
# ==============================================================================

def translate_with_cache(text: str, lang: str, cache: TranslationCache) -> str:
    """
    Übersetzt einen Text zeilenweise. Jede Zeile wird einzeln gecacht.

    Für jede Zeile:
      - Cache-Treffer → sofort verwenden, kein trans-Aufruf
      - Cache-Miss    → trans aufrufen, Ergebnis cachen, 1s Pause

    Leerzeilen und reine Platzhalter-Zeilen werden nicht übersetzt
    (sie sind sprachunabhängig).
    """
    lines = text.split("\n")
    translated_lines: list[str] = []
    cache_hits = 0
    api_calls = 0

    for line in lines:
        stripped = line.strip()

        # Leerzeilen und reine Platzhalter-Zeilen direkt übernehmen
        if not stripped or re.fullmatch(r"XTYPCMD\d+X", stripped, re.IGNORECASE):
            translated_lines.append(line)
            continue

        # Cache-Treffer?
        cached = cache.get(line)
        if cached is not None:
            translated_lines.append(cached)
            cache_hits += 1
            continue

        # Cache-Miss → trans aufrufen
        try:
            process = subprocess.run(
                ["trans", "-brief", f"{SOURCE_LANG}:{lang}"],
                input=line,
                capture_output=True,
                text=True,
                encoding="utf-8",
                check=True,
            )
            translated_line = process.stdout.strip()
        except subprocess.CalledProcessError as e:
            logger.error(f"      [FEHLER] trans bei Zeile '{line[:40]}': {e.stderr.strip()}")
            translated_lines.append(line)  # Original behalten bei Fehler
            continue
        except FileNotFoundError:
            logger.error("      [FEHLER] 'trans' nicht gefunden. Bitte translate-shell installieren.")
            raise  # Kritischer Fehler → abbrechen

        cache.set(line, translated_line)
        translated_lines.append(translated_line)
        api_calls += 1
        time.sleep(1)  # Pause nach jedem API-Aufruf

    logger.info(f"      Cache-Treffer: {cache_hits}, API-Aufrufe: {api_calls}")
    return "\n".join(translated_lines)


# ==============================================================================
# SCHRITT 3: WIEDERHERSTELLUNG NACH DER ÜBERSETZUNG
# ==============================================================================

def restore_typst_syntax(translated_content: str, protected_elements: list[str]) -> str:
    """
    Stellt alle geschützten Typst-Elemente anhand ihrer Platzhalter wieder her.
    Der Regex ist tolerant gegenüber Leerzeichen und Groß-/Kleinschreibung,
    die der Übersetzer in den Platzhalter eingebaut haben könnte.
    """
    for i, element in enumerate(protected_elements):
        # pattern = fr"X\s*TYP(?:E)?\s*CMD\s*{i}\s*X"
        pattern = fr"X\s*TYP(?:E)?\s*CMD\s*{i}\s*X(?!\d)"
        translated_content = re.sub(
            pattern,
            lambda m, e=element: e,  # lambda-Binding verhindert Backslash-Probleme
            translated_content,
            count=1,
            flags=re.IGNORECASE,
        )
    return translated_content


# ==============================================================================
# SCHRITT 4: PFADE FÜR .i18n-UNTERORDNER ANPASSEN
# ==============================================================================

def fix_paths_for_i18n(content: str, target_lang: str) -> str:
    """
    Da jede übersetzte Datei genau eine Ebene tiefer liegt (.i18n/),
    wird vor jeden relativen Pfad '../' gesetzt.

    Außerdem wird die Sprach-Variable hart auf die Zielsprache gesetzt,
    damit Typst weiß, in welcher Sprache es rendert.
    """
    # 1. Imports und Includes: '../' voranstellen (ignoriert @preview und absolute Pfade)
    content = re.sub(r'(#(?:import|include)\s+)"(?![@/])', r'\1"../', content)

    # 2. Bilder: '../' voranstellen
    content = re.sub(r'image\("(?![/])', r'image("../', content)

    # 3. Modul-Schleife in der Hauptdatei (cv.typ o.ä.) umbiegen
    old_loop = 'include "modules_" + lang + "/" + name + ".typ"'
    new_loop = f'include "../modules_de/" + name + ".i18n/" + name + "-{target_lang}lang.typ"'
    content = content.replace(old_loop, new_loop)

    # Fallback: falls 'long' statt 'lang' verwendet wurde
    old_loop_long = 'include "modules_" + long + "/" + name + ".typ"'
    content = content.replace(old_loop_long, new_loop)

    # 4. Sprach-Variable hard-coden
    content = re.sub(
        r"#let\s+(lang|long)\s*=\s*metadata\.language",
        f'#let lang = "{target_lang}"',
        content,
    )

    return content


# ==============================================================================
# SCHRITT 5: SANITIZE — TYPISCHE ÜBERSETZUNGSFEHLER KORRIGIEREN
# ==============================================================================

def sanitize_translation(text: str) -> str:
    """
    Korrigiert typische Fehler, die translate-shell/Google Translate einführt:
    - Typografische Anführungszeichen → gerade
    - .type → .typ  (kritischer Typst-Bug)
    - Leerzeichen vor Satzzeichen
    - Leerzeichen innerhalb von **fettgedrucktem** Text
    - Zerstückelte Platzhalter wieder zusammenfügen
    """
    # Typografische Anführungszeichen
    text = text.replace("\u201c", '"').replace("\u201d", '"')
    text = text.replace("\u201e", '"').replace("\u201f", '"')

    # .type → .typ  (Übersetzer verwandelt manchmal .typ in .type)
    text = text.replace('.type"', '.typ"')

    # Leerzeichen vor Satzzeichen
    # text = text.replace(" :", ":").replace(" ,", ",")

    # Leerzeichen um Kommas in Listen fixen (wichtig für tags: (...))
    # Macht aus "Regex" , "Linux" -> "Regex", "Linux"
    text = re.sub(r'\s*,\s*(?=[^[]*["\)])', ', ', text)

    # Leerzeichen innerhalb von **fett**
    text = re.sub(r"\*\*\s+", "**", text)
    text = re.sub(r"\s+\*\*", "**", text)

    # Zerstückelten Platzhalter reparieren.
    # Der Übersetzer kann aus "XTYPCMD10X" machen:
    #   "X TYPE CMD 10X" (TYPE statt TYP, Leerzeichen)
    #   "X TYP CMD 10 X" (Leerzeichen um Zahl)
    # Regex deckt alle Varianten ab: TYP oder TYPE, beliebig viele Leerzeichen.
    text = re.sub(
        r"X\s*TYP(?:E)?\s*CMD\s*(\d+)\s*X",
        lambda m: f"XTYPCMD{m.group(1)}X",
        text,
        flags=re.IGNORECASE,
    )

    return text


# ==============================================================================
# DATEI VERARBEITEN
# ==============================================================================

def process_file(filename: str, caches: dict[str, TranslationCache]) -> None:
    """
    Verarbeitet eine einzelne .typ-Datei:
      Schritt 1 — Typst-Syntax schützen
      Schritt 2 — Zeilenweise übersetzen (Cache → trans)
      Schritt 3 — Sanitize
      Schritt 4 — Platzhalter wiederherstellen
      Schritt 5 — Pfade für .i18n-Unterordner anpassen
      Schritt 6 — Abschließendes Sanitize
      Schritt 7 — Speichern
    """
    source_path = Path(filename)
    logger.info(f"Bearbeite Datei: {source_path.name}")

    with open(source_path, "r", encoding="utf-8") as f:
        original_content = f.read()

    # --- Schritt 1: Syntax schützen ---
    protected_content, protected_elements = protect_typst_syntax(original_content)
    logger.info(f"   Geschützte Elemente: {len(protected_elements)}")

    base_name = source_path.stem  # Dateiname ohne .typ
    i18n_dir = source_path.parent / f"{base_name}.i18n"

    for lang in TARGET_LANGS:
        output_file = i18n_dir / f"{base_name}-{lang}lang.typ"

        # Freshness-Check
        if output_file.exists() and output_file.stat().st_mtime > source_path.stat().st_mtime:
            logger.info(f"   -> {lang}: aktuell, überspringe.")
            continue

        logger.info(f"   -> Übersetze nach '{lang}'...")
        cache = caches[lang]

        try:
            # --- Schritt 2: Zeilenweise übersetzen ---
            translated_raw = translate_with_cache(protected_content, lang, cache)
        except FileNotFoundError:
            return  # trans fehlt → alle weiteren Sprachen/Dateien abbrechen

        # --- Schritt 3: Sanitize vor Wiederherstellung ---
        translated_raw = sanitize_translation(translated_raw)

        # --- Schritt 4: Platzhalter wiederherstellen ---
        final_content = restore_typst_syntax(translated_raw, protected_elements)

        # --- Schritt 5: Pfade anpassen ---
        final_content = fix_paths_for_i18n(final_content, lang)

        # --- Schritt 6: Abschließendes Sanitize ---
        final_content = sanitize_translation(final_content)

        # --- Schritt 7: Speichern ---
        i18n_dir.mkdir(parents=True, exist_ok=True)
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(final_content)

        logger.info(f"      [OK] Gespeichert: {output_file}")


# ==============================================================================
# MAIN
# ==============================================================================

def main() -> None:
    logger.info("Starte Typst-Übersetzung...")
    logger.info(f"Quellsprache : {SOURCE_LANG}")
    logger.info(f"Zielsprachen : {TARGET_LANGS}")

    # Caches einmalig laden — ein Cache-Objekt pro Zielsprache
    # Sofort bereinigen: Einträge mit nicht wiederhergestellten Platzhaltern entfernen
    caches: dict[str, TranslationCache] = {}
    for lang in TARGET_LANGS:
        cache = TranslationCache(lang)
        cache.purge_invalid()
        caches[lang] = cache

    search_path = script_dir.parent / "**" / "*.typ"
    all_files = glob.glob(str(search_path), recursive=True)

    skip_count = 0

    for filename in all_files:
        path = Path(filename)
        parts = path.parts

        # 1. Versteckte Ordner überspringen (beginnen mit '.')
        if any(p.startswith(".") for p in parts if p not in (".", "..")):
            continue

        # 2. .i18n-Ausgabe-Ordner überspringen
        if ".i18n" in parts:
            continue

        # 3. Bekannte System-Ordner überspringen
        if any(ignored in parts for ignored in ("packages", "venv", "__pycache__", "node_modules")):
            continue

        # 4. Freshness-Check auf Dateiebene: alle Sprachen bereits aktuell?
        base_name = path.stem
        i18n_dir = path.parent / f"{base_name}.i18n"

        def is_fresh(lang: str, p: Path = path, d: Path = i18n_dir, b: str = base_name) -> bool:
            tr = d / f"{b}-{lang}lang.typ"
            return tr.exists() and tr.stat().st_mtime > p.stat().st_mtime

        if all(is_fresh(lang) for lang in TARGET_LANGS):
            skip_count += 1
            continue

        process_file(filename, caches)

    logger.info(f"Fertig. Übersprungen (aktuell): {skip_count}")
    for lang, cache in caches.items():
        logger.info(f"Cache '{lang}': {len(cache)} Einträge gesamt → {cache.path}")


if __name__ == "__main__":
    main()
