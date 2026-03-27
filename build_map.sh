#!/bin/bash
clear;

export LC_ALL=de_DE.UTF-8
export LANG=de_DE.UTF-8
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  build_map.sh  –  Vollständige Bewerbungsmappe in einem Schritt     ║
# ║                                                                      ║
# ║  Ablauf:                                                             ║
# ║  1. Buzzwords: Argument oder automatisch aus job_ad.txt (ollama)    ║
# ║  2. Lebenslauf kompilieren  (typst_compile_cv.sh)                   ║
# ║  3. Anschreiben kompilieren (build_letter.sh)                       ║
# ║  4. Anschreiben-Variante via ollama generieren + als PDF ablegen    ║
# ║  5. Alles in exports/YYYY-MM/Firmenname/ zusammenführen             ║
# ║                                                                      ║
# ║  Aufruf:                                                             ║
# ║  ./build_map.sh                        ← alles aus job_ad.txt       ║
# ║  ./build_map.sh "Java|React|Docker"    ← Buzzwords als Argument     ║
# ╚══════════════════════════════════════════════════════════════════════╝

# ── Konfiguration ──────────────────────────────────────────────────────
OLLAMA_MODEL="llama3.2"
OLLAMA_URL="http://localhost:11434/api/generate"
JOB_AD_FILE="job_ad.txt"
LETTER_TXT="Anschreiben_Lauffer.txt"
CV_FILENAME="Lebenslauf_Lauffer.pdf"
LETTER_FILENAME="Anschreiben_Lauffer.pdf"
LETTER_OLLAMA_TXT="Anschreiben_Lauffer_KI.txt"
LETTER_OLLAMA_PDF="Anschreiben_Lauffer_KI.pdf"
JOB_AD_MAX_DAYS=3

# ── Farben ─────────────────────────────────────────────────────────────
C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_GRAY='\033[0;90m'
C_BOLD='\033[1m'

log_step() { echo -e "\n${C_BOLD}${C_BLUE}━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"; }
log_ok()   { echo -e "${C_GREEN}  ✅ $1${C_RESET}"; }
log_warn() { echo -e "${C_YELLOW}  ⚠️  $1${C_RESET}"; }
log_err()  { echo -e "${C_RED}  ❌ $1${C_RESET}"; }
log_info() { echo -e "${C_GRAY}  →  $1${C_RESET}"; }



# Nach dem Bestimmen von BUZZWORDS, vor dem Export:
expand_buzzwords() {
  local raw="$1"
  local expanded="$raw"

  if [ ! -f "buzzword_map.json" ]; then
    echo "$raw"
    return
  fi

  # Jeden Buzzword gegen die Map-Keys prüfen
  IFS='|' read -ra WORDS <<< "$raw"
  for word in "${WORDS[@]}"; do
    # Prüfen ob $word ein Key in buzzword_map.json ist
    mapped=$(jq -r --arg w "$word" '.[$w] // empty | join("|")' buzzword_map.json 2>/dev/null)
    if [ -n "$mapped" ]; then
      expanded="${expanded}|${mapped}"
    fi
  done

  # Duplikate entfernen
  echo "$expanded" | tr '|' '\n' | sort -u | tr '\n' '|' | sed 's/|$//'
}


# ══════════════════════════════════════════════════════════════════════
# HILFSFUNKTION: ollama aufrufen
# ══════════════════════════════════════════════════════════════════════
ollama_query() {
  local prompt="$1"
  local max_time="${2:-30}"

  curl -sf --max-time "$max_time" "$OLLAMA_URL" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg model "$OLLAMA_MODEL" \
      --arg prompt "$prompt" \
      '{model: $model, prompt: $prompt, stream: false}')" \
    2>/dev/null \
  | jq -r '.response' 2>/dev/null
}

ollama_running() {
  curl -sf "http://localhost:11434" -o /dev/null 2>/dev/null
}

# ══════════════════════════════════════════════════════════════════════
# SCHRITT 0: Voraussetzungen prüfen
# ══════════════════════════════════════════════════════════════════════
log_step "Voraussetzungen"

ERRORS=0
for f in typst_compile_cv.sh build_letter.sh cover_letter.typ cv.typ; do
  if [ ! -f "$f" ]; then
    log_err "$f nicht gefunden!"
    (( ERRORS++ ))
  else
    log_ok "$f vorhanden"
  fi
done
[ ! -f "$LETTER_TXT" ] && { log_err "$LETTER_TXT nicht gefunden!"; (( ERRORS++ )); }
[ $ERRORS -gt 0 ] && { echo ""; log_err "Abbruch: fehlende Dateien."; exit 1; }

# ── job_ad.txt Alters-Check ───────────────────────────────────────────
if [ ! -f "$JOB_AD_FILE" ]; then
  log_warn "$JOB_AD_FILE nicht gefunden – Buzzword-Extraktion nicht möglich."
else
  FILE_AGE_DAYS=$(( ( $(date +%s) - $(stat -c %Y "$JOB_AD_FILE") ) / 86400 ))
  FILE_DATE=$(stat -c %y "$JOB_AD_FILE" | cut -d' ' -f1)
  if [ "$FILE_AGE_DAYS" -ge "$JOB_AD_MAX_DAYS" ]; then
    echo ""
    echo -e "${C_YELLOW}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_YELLOW}║  ⚠️  job_ad.txt ist ${FILE_AGE_DAYS} Tage alt (Stand: ${FILE_DATE})          ║${C_RESET}"
    echo -e "${C_YELLOW}║  Hast du vergessen, die Stellenanzeige zu aktualisieren?    ║${C_RESET}"
    echo -e "${C_YELLOW}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
    read -rp "  Trotzdem fortfahren? [j/N] " CONFIRM
    [[ "$CONFIRM" =~ ^[jJyY]$ ]] || { echo "Abgebrochen."; exit 0; }
  else
    log_ok "$JOB_AD_FILE aktuell (${FILE_AGE_DAYS} Tage alt, Stand: ${FILE_DATE})"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# SCHRITT 1: Buzzwords bestimmen
# Priorität: Argument $1 → ollama aus job_ad.txt → manuell
# ══════════════════════════════════════════════════════════════════════
log_step "Schritt 1: Buzzwords bestimmen"

FILTER_ARG="$1"

if [ -n "$FILTER_ARG" ]; then
  BUZZWORDS="$FILTER_ARG"
  log_ok "Buzzwords aus Argument übernommen"
  log_info "$BUZZWORDS"

elif [ -f "$JOB_AD_FILE" ] && ollama_running; then
  echo -e "  🤖 ollama extrahiert Buzzwords aus $JOB_AD_FILE …"
  JOB_AD_TEXT=$(cat "$JOB_AD_FILE")

  PROMPT_BUZZWORDS="Extract relevant technical and professional skill keywords from this job advertisement.
Return ONLY a pipe-separated list like: Java|Python|Docker|Scrum
No explanations, no numbering, no extra text. Only the keywords separated by |

Job advertisement:
${JOB_AD_TEXT}"

  RAW=$(ollama_query "$PROMPT_BUZZWORDS" 45)
  # Ersten | -separierten Block extrahieren, Zeilenumbrüche entfernen
  BUZZWORDS=$(echo "$RAW" \
    | tr '\n' '|' \
    | grep -oP '[A-Za-z0-9äöüÄÖÜß.+#/_-]+(\|[A-Za-z0-9äöüÄÖÜß.+#/_-]+)+' \
    | head -1)

  if [ -n "$BUZZWORDS" ]; then
    log_ok "Buzzwords via ollama extrahiert"
    log_info "$BUZZWORDS"
  else
    log_warn "ollama lieferte kein verwertbares Ergebnis."
    read -rp "  Buzzwords manuell eingeben (z.B. Java|React|Docker): " BUZZWORDS
  fi

else
  [ ! -f "$JOB_AD_FILE" ] && log_warn "$JOB_AD_FILE fehlt."
  ollama_running || log_warn "ollama nicht erreichbar."
  read -rp "  Buzzwords manuell eingeben (z.B. Java|React|Docker): " BUZZWORDS
fi

BUZZWORDS=$(expand_buzzwords "$BUZZWORDS")
log_info "Erweitert: $BUZZWORDS"



[ -z "$BUZZWORDS" ] && { log_err "Keine Buzzwords – Abbruch."; exit 1; }

# ══════════════════════════════════════════════════════════════════════
# SCHRITT 2: Lebenslauf kompilieren
# ══════════════════════════════════════════════════════════════════════
log_step "Schritt 2: Lebenslauf kompilieren"

echo -e "  ▶ typst_compile_cv.sh \"$BUZZWORDS\" (asynchron)"
CV_TMPLOG=$(mktemp /tmp/cv_build_XXXXXX.log)

# Asynchron starten
bash typst_compile_cv.sh "$BUZZWORDS" > "$CV_TMPLOG" 2>&1 &
CV_PID=$!
log_info "Lebenslauf-Kompilierung gestartet (PID $CV_PID) …"
log_ok "Lebenslauf kompiliert → exports/$TAGS_CLEAN/$CV_FILENAME"

# ══════════════════════════════════════════════════════════════════════
# SCHRITT 3: Firma + Jobtitel + Ansprechpartner – ein ollama-Aufruf
# (läuft parallel zur Lebenslauf-Kompilierung)
# ══════════════════════════════════════════════════════════════════════
log_step "Schritt 3: Metadaten extrahieren (1 ollama-Aufruf)"

COMPANY="Unbekannt"
DB_JOBTITEL=""
DB_KONTAKT="Unbekannt"

if ollama_running && [ -f "$JOB_AD_FILE" ]; then
  echo -e "  🤖 ollama liest job_ad.txt …"
  JOB_AD_HEAD=$(head -80 "$JOB_AD_FILE")

  META_RAW=$(ollama_query "Extract information from this job advertisement.
Return ONLY a JSON object, nothing else. No markdown, no backticks, no explanation.

Fields:
- company:   hiring company name
- job_title: exact job title, no ID numbers
- contact:   contact person full name, or empty string if unknown

Output exactly like this example:
{\"company\": \"Exclusive Associates\", \"job_title\": \"Softwareentwickler\", \"contact\": \"Mariama Drammeh\"}

Job advertisement:
${JOB_AD_HEAD}" 30)

  # Robust JSON extraction:
  # 1. Strip markdown code fences  2. Extract first valid JSON object via jq
  META_JSON=$(printf '%s' "$META_RAW" \
    | sed 's/```json//g; s/```//g' \
    | tr -d '\r' \
    | grep -oP '\{.+\}' \
    | head -1)

  # Fallback: let jq find valid JSON anywhere in the output
  if [ -z "$META_JSON" ]; then
    META_JSON=$(printf '%s' "$META_RAW" | jq -Rs 'scan("\\{[^{}]+\\}")' 2>/dev/null \
      | head -1 | tr -d '"' | sed 's/\\n/ /g')
  fi

  # Debug: zeige ollama-Rohausgabe wenn JSON-Parsing fehlschlägt
  if [ -z "$META_JSON" ]; then
    echo -e "  ${C_GRAY}ollama Rohausgabe:${C_RESET}" >&2
    printf '%s
' "$META_RAW" | head -10 | sed "s/^/  ${C_GRAY}│ /" >&2
    echo -e "${C_RESET}" >&2
  fi

  if [ -n "$META_JSON" ]; then
    RAW_COMPANY=$(echo "$META_JSON"  | jq -r '.company   // empty' 2>/dev/null)
    RAW_TITLE=$(echo "$META_JSON"    | jq -r '.job_title // empty' 2>/dev/null)
    RAW_CONTACT=$(echo "$META_JSON"  | jq -r '.contact   // empty' 2>/dev/null)

    [ -n "$RAW_COMPANY" ]  && COMPANY=$(printf '%s' "$RAW_COMPANY"       | sed 's/[^a-zA-Z0-9äöüÄÖÜß _&+.-]//g' | sed 's/[[:space:]]/_/g' | cut -c1-40)
    [ -n "$RAW_TITLE" ]    && DB_JOBTITEL=$(printf '%s' "$RAW_TITLE"  | cut -c1-80)
    [ -n "$RAW_CONTACT" ]  && DB_KONTAKT=$(printf '%s' "$RAW_CONTACT" | cut -c1-50)

    log_ok "Firma:          $COMPANY"
    log_ok "Jobtitel:       $DB_JOBTITEL"
    log_ok "Ansprechpartner: $DB_KONTAKT"
  else
    log_warn "JSON-Parsing fehlgeschlagen – manuelle Eingabe."
  fi
fi

# Fallbacks bei leeren Feldern
if [ -z "$COMPANY" ] || [ "$COMPANY" = "Unbekannt" ]; then
  read -rp "  Firmenname: " _IN
  COMPANY=$(printf '%s' "$_IN" | sed 's/[^a-zA-Z0-9äöüÄÖÜß _&+.-]//g'     | sed 's/[[:space:]]/_/g' | cut -c1-40)
  [ -z "$COMPANY" ] && COMPANY="Unbekannt"
fi
if [ -z "$DB_JOBTITEL" ]; then
  read -rp "  Jobtitel:   " DB_JOBTITEL
fi
if [ -z "$DB_KONTAKT" ] || [ "$DB_KONTAKT" = "Unbekannt" ]; then
  read -rp "  Ansprechpartner/in: " DB_KONTAKT
  [ -z "$DB_KONTAKT" ] && DB_KONTAKT="Unbekannt"
fi

# ══════════════════════════════════════════════════════════════════════
# Warte auf Lebenslauf-Kompilierung (falls noch nicht fertig)
# ══════════════════════════════════════════════════════════════════════
if [ -n "$CV_PID" ]; then
  echo -e "  ⏳ Warte auf Lebenslauf-Kompilierung …"
  wait "$CV_PID"
  CV_EXIT=$?
  # TAGS_CLEAN VOR dem Löschen des Logs extrahieren
  TAGS_CLEAN=$(grep '^TAGS_CLEAN=' "$CV_TMPLOG" 2>/dev/null | tail -1 | cut -d'=' -f2-)
  cat "$CV_TMPLOG" | sed 's/^/  /'
  rm -f "$CV_TMPLOG"
  if [ $CV_EXIT -ne 0 ]; then
    log_err "Lebenslauf-Kompilierung fehlgeschlagen (Exit $CV_EXIT)."
    exit 1
  fi
fi

# Fallback: neuesten exports/TOKEN__hash/ Ordner nehmen
if [ -z "$TAGS_CLEAN" ]; then
  TAGS_CLEAN=$(ls -1t exports/ 2>/dev/null | grep '__' | head -1)
fi
if [ -z "$TAGS_CLEAN" ]; then
  log_err "TAGS_CLEAN konnte nicht ermittelt werden."
  exit 1
fi
log_ok "Lebenslauf kompiliert → exports/$TAGS_CLEAN/"
# kurze Pause damit PDF sicher geschrieben ist

# Warten bis PDF wirklich auf Disk ist
CV_PDF_CHECK="exports/${TAGS_CLEAN}/${CV_FILENAME}"
BEFORE_SIZE=0
for i in {1..20}; do
  [ ! -f "$CV_PDF_CHECK" ] && { sleep 0.5; continue; }
  CURRENT_SIZE=$(stat -c%s "$CV_PDF_CHECK" 2>/dev/null || echo 0)
  [ "$CURRENT_SIZE" -gt 0 ] && [ "$CURRENT_SIZE" -eq "$BEFORE_SIZE" ] && break
  BEFORE_SIZE=$CURRENT_SIZE
  sleep 0.5
done
[ ! -f "$CV_PDF_CHECK" ] && { log_err "PDF nicht gefunden: $CV_PDF_CHECK"; exit 1; }
log_info "PDF bereit: $(stat -c%s "$CV_PDF_CHECK") Bytes"




# ══════════════════════════════════════════════════════════════════════
# SCHRITT 4: Mappe-Ordner anlegen
# ══════════════════════════════════════════════════════════════════════
YEAR_MONTH=$(date '+%Y-%m')
MAPPE_DIR="exports/${YEAR_MONTH}/${COMPANY}"
mkdir -p "$MAPPE_DIR"
log_step "Schritt 4: Bewerbungsmappe → $MAPPE_DIR"

# ══════════════════════════════════════════════════════════════════════
# SCHRITT 5: Anschreiben kompilieren TODO must use txt from MAPPE_DIR
# @ in E-Mail-Adressen für Typst escapen
#ESCAPED_LETTER=$(mktemp --tmpdir=. --suffix=.txt)

ESCAPED_LETTER=$(mktemp --tmpdir="$MAPPE_DIR" --suffix=.txt)

# kate $ESCAPED_LETTER # ist leer


LETTER_TXT="${MAPPE_DIR%/}/Anschreiben_Lauffer.txt"

sed 's/@/\\@/g' "$LETTER_TXT" > "$ESCAPED_LETTER"

# kate $ESCAPED_LETTER # ist leer
# exit



cp -f -- "$ESCAPED_LETTER" "./Anschreiben_Lauffer.txt"


trap "rm -f \"$ESCAPED_LETTER\"" EXIT

# ══════════════════════════════════════════════════════════════════════
log_step "Schritt 5: Anschreiben kompilieren"

LETTER_PDF_FINAL="${MAPPE_DIR}/${LETTER_FILENAME}"

typst compile cover_letter.typ \
  --input file="$ESCAPED_LETTER" \
  --input quote="Bewerbung als XXXXXXXX" \
  "$LETTER_PDF_FINAL"





if [ $? -eq 0 ]; then
  log_ok "Anschreiben PDF: $LETTER_PDF_FINAL"
else
  log_err "Typst-Fehler beim Anschreiben."
  exit 1
fi

# ══════════════════════════════════════════════════════════════════════
# SCHRITT 6: Lebenslauf in Mappe kopieren
# ══════════════════════════════════════════════════════════════════════
log_step "Schritt 6: Lebenslauf in Mappe kopieren"

CV_SOURCE="exports/${TAGS_CLEAN}/${CV_FILENAME}"
CV_DEST="${MAPPE_DIR}/${CV_FILENAME}"

if [ -f "$CV_SOURCE" ]; then
  cp "$CV_SOURCE" "$CV_DEST"
  log_ok "Lebenslauf kopiert: $CV_DEST"
  log_info "Quelle: $CV_SOURCE"
else
  log_warn "Lebenslauf-Quelle nicht gefunden: $CV_SOURCE"
  log_warn "Bitte manuell kopieren."
fi

# ══════════════════════════════════════════════════════════════════════
# SCHRITT 7: Anschreiben-Prompt für Google AI Studio vorbereiten
# ══════════════════════════════════════════════════════════════════════
log_step "Schritt 7: Anschreiben-Prompt → Google AI Studio"

JOB_AD_TEXT=""
[ -f "$JOB_AD_FILE" ] && JOB_AD_TEXT=$(cat "$JOB_AD_FILE")

CV_DATA=""
CV_PDF_SOURCE="exports/${TAGS_CLEAN}/${CV_FILENAME}"
if [ -f "$CV_PDF_SOURCE" ]; then
  if command -v pdftotext &>/dev/null; then
    CV_DATA=$(pdftotext "$CV_PDF_SOURCE" - 2>/dev/null)
    log_ok "CV-Text aus PDF extrahiert: $CV_PDF_SOURCE"
  else
    log_warn "pdftotext nicht gefunden – CV-Text fehlt im Prompt."
    log_info "Installation: sudo apt install poppler-utils"
  fi
else
  log_warn "Lebenslauf-PDF nicht gefunden: $CV_PDF_SOURCE"
fi

PROMPT_LETTER="Du bist ein erfahrener Bewerbungsberater. Schreibe ein Anschreiben auf Deutsch.

WICHTIG: AUSGABE-FORMAT (Typst-Markup)
Der Text wird direkt als Typst-Markup kompiliert. Exakte Regeln:

ZEILENUMBRÜCHE: Jede Zeile im Adressblock MUSS mit einem Backslash enden: \\
Ohne \\ am Zeilenende werden aufeinanderfolgende Zeilen zu einer einzigen Zeile!

KURSIV: *Text* (für Adressblock)
NICHT verwenden: #, **, __, HTML-Tags, Markdown-Überschriften

Der Adressblock muss EXAKT so aussehen (Backslash \\ am Ende jeder Zeile!):
*[Firmenname]* \\
*[Ansprechpartner falls bekannt]* \\
*[PLZ Ort]*

Betreff: Bewerbung als [Jobtitel aus Stellenanzeige]

Zwischen Absätzen: eine Leerzeile (kein \\)

TON & STIL
- Sachlich, direkt, professionell – kein übertriebenes Hochglanz-Bewerbungssprech
- Keine Floskeln wie \"hiermit bewerbe ich mich\" oder \"mit großer Begeisterung\"
- Konkret: Was kann ich, was passt zur Stelle – fertig
- Länge: ca. 3 kurze Absätze + Schluss, nicht länger
- Gib NUR den fertigen Anschreiben-Text zurück, keine Erklärungen, keine Kommentare

MEINE DATEN (aus meinem Lebenslauf)
${CV_DATA}

STELLENANZEIGE
${JOB_AD_TEXT}"

# Prompt-Datei im Mappe-Ordner speichern (als Referenz / Backup)
PROMPT_FILE="${MAPPE_DIR}/prompt_anschreiben_ki.txt"
printf '%s\n' "$PROMPT_LETTER" > "$PROMPT_FILE"
log_ok "Prompt gespeichert: $PROMPT_FILE"

# In Zwischenablage kopieren
CLIPBOARD_OK=false
if command -v xclip &>/dev/null; then
  printf '%s' "$PROMPT_LETTER" | xclip -selection clipboard
  CLIPBOARD_OK=true
  log_ok "Prompt in Zwischenablage kopiert (xclip)"
elif command -v xdotool &>/dev/null; then
  printf '%s' "$PROMPT_LETTER" | xclip -selection clipboard 2>/dev/null \
    || printf '%s' "$PROMPT_LETTER" | xdotool type --clearmodifiers --file -
  CLIPBOARD_OK=true
  log_ok "Prompt in Zwischenablage kopiert (xdotool)"
elif command -v wl-copy &>/dev/null; then
  printf '%s' "$PROMPT_LETTER" | wl-copy
  CLIPBOARD_OK=true
  log_ok "Prompt in Zwischenablage kopiert (wl-copy / Wayland)"
else
  log_warn "Kein Clipboard-Tool gefunden (xclip/wl-copy)."
  log_info "Prompt liegt in: $PROMPT_FILE"
fi

# Google AI Studio im Browser öffnen
echo ""
echo -e "  🌐 Öffne Google AI Studio …"
AI_STUDIO_URL="https://aistudio.google.com/prompts/new_chat"

if command -v xdg-open &>/dev/null; then
  xdg-open "$AI_STUDIO_URL" &
elif command -v firefox &>/dev/null; then
  firefox "$AI_STUDIO_URL" &
elif command -v chromium-browser &>/dev/null; then
  chromium-browser "$AI_STUDIO_URL" &
else
  log_warn "Kein Browser gefunden – bitte manuell öffnen:"
  echo -e "  ${C_CYAN}$AI_STUDIO_URL${C_RESET}"
fi

if $CLIPBOARD_OK; then
  echo ""
  echo -e "  ${C_BOLD}${C_GREEN}➡  Prompt ist in der Zwischenablage – einfach Strg+V in AI Studio einfügen!${C_RESET}"
else
  echo ""
  echo -e "  ${C_BOLD}${C_YELLOW}➡  Prompt manuell öffnen: $PROMPT_FILE${C_RESET}"
fi

# ── kate öffnen & auf Gemini-Text warten ─────────────────────────────
echo ""
echo -e "  📝 Öffne ${C_CYAN}${LETTER_TXT}${C_RESET} in kate …"
kate "$LETTER_TXT" &

echo ""
echo -e "${C_BOLD}${C_YELLOW}┌──────────────────────────────────────────────────────────────┐${C_RESET}"
echo -e "${C_BOLD}${C_YELLOW}│  1. Gemini-Text aus AI Studio kopieren                       │${C_RESET}"
echo -e "${C_BOLD}${C_YELLOW}│  2. In kate einfügen und speichern (Strg+S)                  │${C_RESET}"
echo -e "${C_BOLD}${C_YELLOW}│  3. Dann hier Enter drücken                                  │${C_RESET}"
echo -e "${C_BOLD}${C_YELLOW}└──────────────────────────────────────────────────────────────┘${C_RESET}"
read -rp "  ➡  Gemini-Text in ${LETTER_TXT} eingefügt? [Enter zum Fortfahren] "

# Schritt 8: Finales Anschreiben-PDF kompilieren
# Escaped-Kopie neu erstellen (User hat Text geändert)
sed 's/@/\\@/g' "$LETTER_TXT" > "$ESCAPED_LETTER"
log_step "Schritt 8: Finales Anschreiben-PDF kompilieren"

LETTER_PDF_FINAL="${MAPPE_DIR}/${LETTER_FILENAME}"
typst compile cover_letter.typ \
  --input file="$ESCAPED_LETTER" \
  --input quote="Bewerbung als XXXXXXXX" \
  "$LETTER_PDF_FINAL"

if [ $? -eq 0 ]; then
  log_ok "Finales Anschreiben PDF: $LETTER_PDF_FINAL"
else
  log_err "Fehler beim Kompilieren – bitte manuell prüfen."
fi


# ── Lebenslauf final sync (neueste Version) ───────────────────────────
# CV_LATEST=$(find exports/ -name "$CV_FILENAME" -not -path "*/20??-??/*" \
#  -printf "%T@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)

CV_LATEST=$(find exports/ -name "$CV_FILENAME" -not -path "*/20??-??/*" \
  -printf "%T@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)

if [ -f "$CV_LATEST" ]; then
  cp "$CV_LATEST" "${MAPPE_DIR}/${CV_FILENAME}"
  log_ok "Lebenslauf aktualisiert: $(basename $CV_LATEST) → $MAPPE_DIR"
  log_info "Quelle: $CV_LATEST"
else
  log_warn "Kein aktueller Lebenslauf gefunden."
fi




# ══════════════════════════════════════════════════════════════════════
# ZUSAMMENFASSUNG
# ══════════════════════════════════════════════════════════════════════
echo ""
echo -e "${C_BOLD}${C_GREEN}╔══════════════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_BOLD}${C_GREEN}║  ✅ Bewerbungsmappe vollständig                              ║${C_RESET}"
echo -e "${C_BOLD}${C_GREEN}╚══════════════════════════════════════════════════════════════╝${C_RESET}"
echo -e "  📁 ${C_CYAN}${MAPPE_DIR}/${C_RESET}"
ls -1 "$MAPPE_DIR" 2>/dev/null | while read -r f; do
  SIZE=$(du -h "${MAPPE_DIR}/${f}" 2>/dev/null | cut -f1)
  echo -e "  ${C_GRAY}  ├── ${f}  (${SIZE})${C_RESET}"
done
echo ""
echo -e "  ${C_GRAY}Lebenslauf-Quelle: exports/${TAGS_CLEAN}/${C_RESET}"
echo ""

# PDF einmal öffnen am Schluss
okular "$LETTER_PDF_FINAL" &

# ══════════════════════════════════════════════════════════════════════
# SCHRITT 9: Datenbank-Eintrag via add.sh
# ══════════════════════════════════════════════════════════════════════
ADD_SH="$HOME/projects/py/STT/config/maps/_privat/job/bewerbung/Lebenlauf-Sammlung/_Lebenslauf/add.sh"

log_step "Schritt 9: Datenbank-Eintrag"

if [ ! -f "$ADD_SH" ]; then
  log_warn "add.sh nicht gefunden: $ADD_SH"
else
  # Firma, Jobtitel, Ansprechpartner bereits in Schritt 3 gesetzt
  log_info "Verwende Metadaten aus Schritt 3."

  # Vorschau
  echo ""
  echo -e "${C_BOLD}${C_CYAN}┌─ Vorschau Datenbank-Eintrag ───────────────────────────────────┐${C_RESET}"
  echo -e "${C_CYAN}│${C_RESET}  ${C_BOLD}Firma:${C_RESET}           ${COMPANY_LABEL:-$COMPANY}"
  echo -e "${C_CYAN}│${C_RESET}  ${C_BOLD}Ansprechpartner:${C_RESET} $DB_KONTAKT"
  echo -e "${C_CYAN}│${C_RESET}  ${C_BOLD}Jobtitel:${C_RESET}        $DB_JOBTITEL"
  echo -e "${C_CYAN}│${C_RESET}"
  echo -e "${C_CYAN}│${C_RESET}  ${C_GRAY}"$ADD_SH" \\${C_RESET}"
  echo -e "${C_CYAN}│${C_RESET}  ${C_GRAY}  "${COMPANY_LABEL:-$COMPANY}" "$DB_KONTAKT" "$DB_JOBTITEL"${C_RESET}"
  echo -e "${C_BOLD}${C_CYAN}└────────────────────────────────────────────────────────────────┘${C_RESET}"
  echo ""

  read -rp "  Eintrag in Datenbank speichern? [j/N] " DB_CONFIRM
  if [[ "$DB_CONFIRM" =~ ^[jJyY]$ ]]; then
    echo -e "  ${C_GRAY}▶ Führe aus:${C_RESET}"
    echo -e "  ${C_GRAY}  bash "$ADD_SH" \\${C_RESET}"
    echo -e "  ${C_GRAY}    "${COMPANY_LABEL:-$COMPANY}" "$DB_KONTAKT" "$DB_JOBTITEL"${C_RESET}"
    echo ""
    bash "$ADD_SH" "${COMPANY_LABEL:-$COMPANY}" "$DB_KONTAKT" "$DB_JOBTITEL"
    EXIT_CODE=$?
    echo -e "  ${C_GRAY}Exit-Code: $EXIT_CODE${C_RESET}"
    if [ $EXIT_CODE -eq 0 ]; then
      log_ok "Datenbank-Eintrag gespeichert."
    else
      log_err "add.sh meldete einen Fehler (Exit $EXIT_CODE)."
      echo -e "  ${C_YELLOW}Manuell ausführen:${C_RESET}"
      echo -e "  ${C_CYAN}bash "$ADD_SH" "${COMPANY_LABEL:-$COMPANY}" "$DB_KONTAKT" "$DB_JOBTITEL"${C_RESET}"
    fi
  else
    log_info "Datenbank-Eintrag übersprungen."
    echo -e "  ${C_GRAY}Manuell nachholen:${C_RESET}"
    echo -e "  ${C_CYAN}bash "$ADD_SH" "${COMPANY_LABEL:-$COMPANY}" "$DB_KONTAKT" "$DB_JOBTITEL"${C_RESET}"
  fi
fi
