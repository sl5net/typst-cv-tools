#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  build_letter.sh  –  Anschreiben → PDF + Bewerbungsmappe        ║
# ║                                                                  ║
# ║  Aufruf:                                                         ║
# ║  ./build_letter.sh Anschreiben.txt ausgabe.pdf AI_Java__a4fd71  ║
# ║                                                                  ║
# ║  Ergebnis-Ordner:                                                ║
# ║  exports/2025-06/MusterGmbH/                                     ║
# ║    ├── Anschreiben_Lauffer.pdf                                   ║
# ║    └── Lebenslauf_Lauffer.pdf   (Kopie aus TOKEN__hash/)         ║
# ╚══════════════════════════════════════════════════════════════════╝

INPUT_FILE="${1:-Anschreiben_Lauffer.txt}"
OUTPUT_FILE="${2:-Anschreiben_Lauffer.pdf}"
TAGS_CLEAN="${3:-}"          # z.B. "AI_Java_ReactJS__a4fd71"

OLLAMA_MODEL="llama3.2"
OLLAMA_URL="http://localhost:11434/api/generate"
JOB_AD_FILE="job_ad.txt"
CV_FILENAME="Lebenslauf_Lauffer.pdf"

# ── Farben ────────────────────────────────────────────────────────
C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'
C_GRAY='\033[0;90m'

# ════════════════════════════════════════════════════════════════════
# PRÜFUNG 1: Anschreiben-Textdatei vorhanden?
# ════════════════════════════════════════════════════════════════════
if [ ! -f "$INPUT_FILE" ]; then
  echo -e "${C_RED}❌ Fehler: Datei '$INPUT_FILE' nicht gefunden!${C_RESET}"
  echo "Benutzung: ./build_letter.sh mein_text.txt [ausgabe.pdf] [TAGS_CLEAN]"
  exit 1
fi

# ════════════════════════════════════════════════════════════════════
# PRÜFUNG 2: job_ad.txt – Alter prüfen
# ════════════════════════════════════════════════════════════════════
JOB_AD_MAX_DAYS=3   # Warnung ab dieser Anzahl Tage

if [ ! -f "$JOB_AD_FILE" ]; then
  echo -e "${C_YELLOW}⚠️  Warnung: '$JOB_AD_FILE' nicht gefunden.${C_RESET}"
  echo -e "${C_YELLOW}   Hast du die Stellenanzeige gespeichert?${C_RESET}"
  echo ""
else
  # Datei-Alter in Sekunden
  FILE_AGE_SEC=$(( $(date +%s) - $(stat -c %Y "$JOB_AD_FILE") ))
  FILE_AGE_DAYS=$(( FILE_AGE_SEC / 86400 ))
  FILE_DATE=$(stat -c %y "$JOB_AD_FILE" | cut -d' ' -f1)

  if [ "$FILE_AGE_DAYS" -ge "$JOB_AD_MAX_DAYS" ]; then
    echo -e "${C_YELLOW}╔══════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_YELLOW}║  ⚠️  job_ad.txt ist ${FILE_AGE_DAYS} Tage alt (Stand: ${FILE_DATE})    ${C_RESET}"
    echo -e "${C_YELLOW}║  Hast du vergessen, die Stellenanzeige zu aktualisieren? ║${C_RESET}"
    echo -e "${C_YELLOW}╚══════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    read -rp "  Trotzdem fortfahren? [j/N] " CONFIRM
    [[ "$CONFIRM" =~ ^[jJyY]$ ]] || { echo "Abgebrochen."; exit 0; }
    echo ""
  else
    echo -e "${C_GREEN}✓ job_ad.txt aktuell${C_RESET} (${FILE_AGE_DAYS} Tage alt, Stand: ${FILE_DATE})"
  fi
fi

# ════════════════════════════════════════════════════════════════════
# FIRMENNAME via ollama aus Anschreiben extrahieren
# ════════════════════════════════════════════════════════════════════
extract_company_name() {
  local text_file="$1"
  local text
  text=$(head -40 "$text_file")   # Erste 40 Zeilen reichen

  # Prüfe ob ollama läuft
  if ! curl -sf "http://localhost:11434" -o /dev/null 2>/dev/null; then
    echo ""
    return
  fi

  local prompt
  prompt="Extract the company name from this cover letter text.
Return ONLY the company name, nothing else.
No explanation, no punctuation, no greeting.
If you cannot find a company name, return: Unbekannt

Cover letter text:
${text}"

  local response
  response=$(curl -sf --max-time 20 "$OLLAMA_URL" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg model "$OLLAMA_MODEL" \
      --arg prompt "$prompt" \
      '{model: $model, prompt: $prompt, stream: false}')" \
    2>/dev/null)

  if [ -z "$response" ]; then
    echo ""; return
  fi

  # Antwort extrahieren, Whitespace/Sonderzeichen bereinigen
  echo "$response" \
    | jq -r '.response' 2>/dev/null \
    | tr -d '\n\r' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | sed 's/[^a-zA-Z0-9äöüÄÖÜß _&+.-]//g' \
    | sed 's/[[:space:]]/_/g' \
    | head -c 40   # Firmenname maximal 40 Zeichen
}

echo ""
echo -e "${C_BLUE}🏢 Extrahiere Firmenname via ollama…${C_RESET}"
COMPANY_RAW=$(extract_company_name "$INPUT_FILE")

if [ -z "$COMPANY_RAW" ] || [ "$COMPANY_RAW" = "Unbekannt" ]; then
  echo -e "${C_YELLOW}   ollama nicht erreichbar oder kein Name gefunden.${C_RESET}"
  read -rp "  Firmenname manuell eingeben: " COMPANY_RAW
  COMPANY_RAW=$(printf '%s' "$COMPANY_RAW" \
    | sed 's/[^a-zA-Z0-9äöüÄÖÜß _&+.-]//g' \
    | sed 's/[[:space:]]/_/g' \
    | head -c 40)
  [ -z "$COMPANY_RAW" ] && COMPANY_RAW="Unbekannt"
fi

echo -e "${C_GREEN}   → Firma: ${COMPANY_RAW}${C_RESET}"

# ════════════════════════════════════════════════════════════════════
# AUSGABE-ORDNER: exports/YYYY-MM/Firmenname/
# ════════════════════════════════════════════════════════════════════
YEAR_MONTH=$(date '+%Y-%m')
MAPPE_DIR="exports/${YEAR_MONTH}/${COMPANY_RAW}"

mkdir -p "$MAPPE_DIR"
echo ""
echo -e "${C_BLUE}📁 Bewerbungsmappe:${C_RESET} $MAPPE_DIR"

# Output-PDF in den Mappe-Ordner legen
LETTER_BASENAME=$(basename "$OUTPUT_FILE")
OUTPUT_PDF_FINAL="${MAPPE_DIR}/${LETTER_BASENAME}"

# ════════════════════════════════════════════════════════════════════
# TYPST: Anschreiben kompilieren
# ════════════════════════════════════════════════════════════════════
echo ""
echo -e "${C_BLUE}📄 Lese Text aus:${C_RESET} $INPUT_FILE"
echo -e "${C_BLUE}🔨 Generiere Anschreiben-PDF…${C_RESET}"

typst compile cover_letter.typ \
  --input file="$INPUT_FILE" \
  --input quote="Bewerbung als XXXXXXXX" \
  "$OUTPUT_PDF_FINAL"

if [ $? -ne 0 ]; then
  echo -e "${C_RED}❌ Fehler beim Erstellen des Anschreiben-PDFs.${C_RESET}"
  exit 1
fi
echo -e "${C_GREEN}✅ Anschreiben erstellt:${C_RESET} $OUTPUT_PDF_FINAL"

# ════════════════════════════════════════════════════════════════════
# LEBENSLAUF kopieren aus exports/TAGS_CLEAN/
# ════════════════════════════════════════════════════════════════════
echo ""
if [ -n "$TAGS_CLEAN" ]; then
  CV_SOURCE="exports/${TAGS_CLEAN}/${CV_FILENAME}"

  if [ -f "$CV_SOURCE" ]; then
    cp "$CV_SOURCE" "${MAPPE_DIR}/${CV_FILENAME}"
    echo -e "${C_GREEN}✅ Lebenslauf kopiert:${C_RESET} ${MAPPE_DIR}/${CV_FILENAME}"
    echo -e "${C_GRAY}   Quelle: ${CV_SOURCE}${C_RESET}"
  else
    echo -e "${C_YELLOW}⚠️  Lebenslauf nicht gefunden:${C_RESET} $CV_SOURCE"
    echo -e "${C_YELLOW}   Bitte manuell kopieren oder typst_compile_cv.sh erneut ausführen.${C_RESET}"
  fi
else
  echo -e "${C_YELLOW}⚠️  Kein TAGS_CLEAN übergeben – Lebenslauf nicht kopiert.${C_RESET}"
  echo -e "${C_YELLOW}   Aufruf: ./build_letter.sh $INPUT_FILE $OUTPUT_FILE <TAGS_CLEAN>${C_RESET}"
fi

# ════════════════════════════════════════════════════════════════════
# ZUSAMMENFASSUNG
# ════════════════════════════════════════════════════════════════════
echo ""
echo -e "${C_BLUE}────────────────────────────────────────────────────────${C_RESET}"
echo -e "${C_GREEN}✅ Bewerbungsmappe vollständig:${C_RESET}"
echo -e "   📁 ${MAPPE_DIR}/"
ls -1 "$MAPPE_DIR" | while read -r f; do
  echo -e "   ${C_GRAY}└── ${f}${C_RESET}"
done
echo -e "${C_BLUE}────────────────────────────────────────────────────────${C_RESET}"
echo ""

okular "$OUTPUT_PDF_FINAL"
