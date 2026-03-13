#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  typst_compile_cv.sh  –  3-stufiges semantisches Matching       ║
# ║                                                                  ║
# ║  Stufe 1: buzzword_map.json  (deterministisch, offline)         ║
# ║  Stufe 2: fzf                (Tippfehler / Teilwörter)          ║
# ║  Stufe 3: ollama llama3.2    (semantische Lücken)               ║
# ║                                                                  ║
# ║  Aufruf:                                                         ║
# ║  ./typst_compile_cv.sh "Frontend|OOP|Qualitätssicherung"        ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── Konfiguration ────────────────────────────────────────────────────
TOKENS_FILE="tokens.txt"          # Alle verfügbaren CV-Skills, einer pro Zeile
BUZZWORD_MAP="buzzword_map.json"  # Stufe-1-Mapping
OLLAMA_MODEL="llama3.2"           # Lokales Modell
OLLAMA_URL="http://localhost:11434/api/generate"

cv_data_file="filtered_cv_data.txt"
job_ad_file="job_ad.txt"
output_prompt_file="cover_letter_prompt.txt"

# ── Farben für lesbare Ausgabe ───────────────────────────────────────
C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_GRAY='\033[0;90m'

# ════════════════════════════════════════════════════════════════════
# STUFE 1: Mapping via buzzword_map.json
# Gibt gematchte Tokens zurück (newline-separiert), Rest als UNMATCHED
# ════════════════════════════════════════════════════════════════════

stage1_map_lookup() {
  local buzzword="$1"
  local result=""

  # ── NEU: Direktcheck gegen tokens.txt ─────────────────────────────
  # Ist der Buzzword selbst ein bekannter Token? Dann direkt zurückgeben.
  if [ -f "$TOKENS_FILE" ] && grep -qiF "$buzzword" "$TOKENS_FILE"; then
    grep -iF "$buzzword" "$TOKENS_FILE" | head -1
    return
  fi

  if [ ! -f "$BUZZWORD_MAP" ]; then
    echo "" ; return
  fi

  # Case-sensitiver Key-Lookup
  result=$(jq -r --arg key "$buzzword" \
    'if has($key) then .[$key] | .[] else empty end' \
    "$BUZZWORD_MAP" 2>/dev/null)

  # Fallback: case-insensitiver Key-Lookup
  if [ -z "$result" ]; then
    result=$(jq -r --arg key "${buzzword,,}" \
      'to_entries[] | select((.key | ascii_downcase) == $key) | .value[]' \
      "$BUZZWORD_MAP" 2>/dev/null)
  fi

  # ── NEU: Values gegen tokens.txt filtern ──────────────────────────
  if [ -n "$result" ] && [ -f "$TOKENS_FILE" ]; then
    result=$(echo "$result" | grep -iFf "$TOKENS_FILE")
  fi

  echo "$result"
}


# ════════════════════════════════════════════════════════════════════
# STUFE 2: fzf-Matching gegen tokens.txt
# Gut für Tippvarianten: "Bash-Scripting"→"Bash", "PostgresQL"→"PostgreSQL"
# ════════════════════════════════════════════════════════════════════
stage2_fzf_match() {
  local buzzword="$1"

  if [ ! -f "$TOKENS_FILE" ]; then
    echo "" ; return
  fi

  # fzf -f: filtert tokens.txt fuzzy, nimmt den besten Treffer
  # --threshold 50 gibt es nicht in fzf, stattdessen nehmen wir head -1
  # und prüfen ob der Match "gut genug" ist via Zeichenüberlappung
  local best
  best=$(fzf -f "$buzzword" --no-sort -i < "$TOKENS_FILE" | head -1)

  # Einfacher Qualitätscheck: mindestens 3 Zeichen des Buzzwords im Token
  if [ -n "$best" ]; then
    local bw_lower="${buzzword,,}"
    local token_lower="${best,,}"
    # Prüfe ob min. 40% der Buzzword-Zeichen im Token vorkommen
    local bw_len=${#bw_lower}
    local min_match=$(( bw_len * 40 / 100 ))
    local common=0
    for (( i=0; i<${#bw_lower}; i++ )); do
      char="${bw_lower:$i:1}"
      [[ "$token_lower" == *"$char"* ]] && (( common++ ))
    done
    if [ "$common" -ge "$min_match" ] && [ "$min_match" -gt 2 ]; then
      echo "$best"
      return
    fi
  fi
  echo ""
}

# ════════════════════════════════════════════════════════════════════
# STUFE 3: ollama llama3.2 für semantische Lücken
# Wird nur für Buzzwords aufgerufen die Stufe 1+2 nicht lösen konnten
# ════════════════════════════════════════════════════════════════════
stage3_ollama_match() {
  local unmatched_list="$1"   # Komma-separierte Buzzwords ohne Match

  # Prüfe ob ollama läuft
  if ! curl -sf "$OLLAMA_URL" -o /dev/null 2>/dev/null && \
     ! curl -sf "http://localhost:11434" -o /dev/null 2>/dev/null; then
    echo "" ; return
  fi

  # Alle verfügbaren Tokens für den Prompt laden
  local all_tokens
  all_tokens=$(paste -sd',' - < "$TOKENS_FILE" 2>/dev/null)
  [ -z "$all_tokens" ] && { echo "" ; return; }

  local prompt
  prompt="You are a CV skill matcher. Map job buzzwords to CV tokens.

Available CV tokens (comma-separated):
${all_tokens}

Job buzzwords to match: ${unmatched_list}

Rules:
- Return ONLY a JSON array of matching CV tokens
- Only include tokens that semantically relate to the buzzwords
- No explanation, no markdown, no extra text
- If nothing matches, return []

Example output: [\"Java\",\"ReactJS\",\"CI\"]"

  # curl-Aufruf an ollama
  local response
  response=$(curl -sf --max-time 30 "$OLLAMA_URL" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg model "$OLLAMA_MODEL" \
      --arg prompt "$prompt" \
      '{model: $model, prompt: $prompt, stream: false}')" \
    2>/dev/null)

  if [ -z "$response" ]; then
    echo "" ; return
  fi

  # Antwort extrahieren und JSON-Array parsen
  local raw_answer
  raw_answer=$(echo "$response" | jq -r '.response' 2>/dev/null)

  # Ersten JSON-Array aus der Antwort extrahieren (llama3.2 manchmal wordy)
  local json_array
  json_array=$(echo "$raw_answer" | grep -oP '\[.*?\]' | head -1)

  if [ -n "$json_array" ]; then
    # Tokens aus Array als Zeilen ausgeben
    # echo "$json_array" | jq -r '.[]' 2>/dev/null
    echo "$json_array" | jq -r '.[]' 2>/dev/null | grep -iFf "$TOKENS_FILE"
  else
    echo ""
  fi
}

# ════════════════════════════════════════════════════════════════════
# HAUPT-MATCHING-FUNKTION
# Orchestriert alle 3 Stufen, gibt finale Token-Liste zurück
# ════════════════════════════════════════════════════════════════════
resolve_tokens() {
  local input_filter="$1"
  local matched_tokens=()
  local unmatched_buzzwords=()

  echo -e "${C_BLUE}┌─ 3-Stufen Matching ────────────────────────────────────┐${C_RESET}" >&2

  IFS='|' read -ra buzzwords <<< "$input_filter"

  for bw in "${buzzwords[@]}"; do
    bw=$(printf '%s' "$bw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$bw" ] && continue

    # ── Stufe 1: Map-Lookup ────────────────────────────────────
    local s1_result
    s1_result=$(stage1_map_lookup "$bw")

    if [ -n "$s1_result" ]; then
      echo -e "${C_GREEN}│ ✓ MAP  ${C_RESET}'${bw}'" >&2
      while IFS= read -r token; do
        [ -n "$token" ] && {
          echo -e "${C_GRAY}│        → ${token}${C_RESET}" >&2
          matched_tokens+=("$token")
        }
      done <<< "$s1_result"
      continue
    fi

    # ── Stufe 2: fzf ──────────────────────────────────────────
    local s2_result
    s2_result=$(stage2_fzf_match "$bw")

    if [ -n "$s2_result" ]; then
      echo -e "${C_CYAN}│ ~ FZF  ${C_RESET}'${bw}' → '${s2_result}'" >&2
      matched_tokens+=("$s2_result")
      continue
    fi

    # ── Kein Match → für Stufe 3 vormerken ────────────────────
    echo -e "${C_YELLOW}│ ? OPEN ${C_RESET}'${bw}' → wird an ollama übergeben" >&2
    unmatched_buzzwords+=("$bw")
  done

  # ── Stufe 3: ollama für alle ungelösten Buzzwords ──────────
  if [ ${#unmatched_buzzwords[@]} -gt 0 ]; then
    local unmatched_csv
    unmatched_csv=$(printf '%s,' "${unmatched_buzzwords[@]}" | sed 's/,$//')
    echo -e "${C_BLUE}│${C_RESET}" >&2
    echo -e "${C_BLUE}├─ Stufe 3: ollama llama3.2 ─────────────────────────────${C_RESET}" >&2
    echo -e "${C_GRAY}│  Frage: ${unmatched_csv}${C_RESET}" >&2

    local s3_result
    s3_result=$(stage3_ollama_match "$unmatched_csv")

    if [ -n "$s3_result" ]; then
      while IFS= read -r token; do
        [ -n "$token" ] && {
          echo -e "${C_GREEN}│  ✓ LLM → '${token}'${C_RESET}" >&2
          matched_tokens+=("$token")
        }
      done <<< "$s3_result"
    else
      echo -e "${C_YELLOW}│  ⚠ ollama nicht erreichbar oder kein Match${C_RESET}" >&2
      # Fallback: ungematchte Buzzwords direkt übernehmen
      for bw in "${unmatched_buzzwords[@]}"; do
        echo -e "${C_GRAY}│  → '${bw}' direkt übernommen${C_RESET}" >&2
        matched_tokens+=("$bw")
      done
    fi
  fi

  echo -e "${C_BLUE}└────────────────────────────────────────────────────────┘${C_RESET}" >&2
  echo "" >&2

  # Dedupliziert, sortiert, mit '|' verbunden
  printf '%s\n' "${matched_tokens[@]}" | sort -u | paste -sd'|' -
}

# ════════════════════════════════════════════════════════════════════
# IT-Stack Erkennung
# ════════════════════════════════════════════════════════════════════
keywordsIT=( "IT" "informatics" "python" "java" "javascript" "js" "php" "c\+\+"
             "cpp" "devops" "ci" "linux" "security" "database" "postgresql"
             "db2" "matlab" "embedded" "automation" "ai" "llm" "rag"
             "architecture" "scripting" )
regex="\b($(IFS='|'; echo "${keywordsIT[*]}"))\b"

# ════════════════════════════════════════════════════════════════════
# FILTER normalisieren & Matching starten
# ════════════════════════════════════════════════════════════════════
FILTER=$1

if [ -z "$FILTER" ]; then
  SORTED_UNIQUE=""
  TAGS_CLEAN="Gesamt"
else
  # Trennzeichen vereinheitlichen → '|'
  NORMALIZED=${FILTER//,/|}
  NORMALIZED=${NORMALIZED//;/|}
  NORMALIZED=${NORMALIZED//[[:space:]]/|}
  NORMALIZED=$(printf '%s' "$NORMALIZED" | sed 's/||\+/|/g; s/^|//; s/|$//')

  # Rohe Deduplizierung
  RAW_UNIQUE=$(printf '%s\n' "${NORMALIZED//|/$'\n'}" | grep -v '^$' | sort -u | paste -sd'|' -)

  echo ""
  echo -e "${C_BLUE}🔍 Eingabe-Buzzwords:${C_RESET} $RAW_UNIQUE"
  echo ""

  # 3-stufiges Matching
  SORTED_UNIQUE=$(resolve_tokens "$RAW_UNIQUE")

  echo -e "${C_GREEN}✅ Finale Tokens:${C_RESET} $SORTED_UNIQUE"
  echo ""

  # Ordnername: lesbare Token-Liste, auf 80 Zeichen begrenzt + 6-Zeichen-Hash
  # → deterministisch (gleiche Tokens = gleicher Ordner), niemals zu lang
  TOKEN_LABEL=$(printf '%s' "$SORTED_UNIQUE" | tr '|' '_')
  TOKEN_HASH=$(printf '%s' "$SORTED_UNIQUE" | sha1sum | cut -c1-6)
  if [ ${#TOKEN_LABEL} -gt 80 ]; then
    TOKEN_LABEL="${TOKEN_LABEL:0:80}"
    # Nicht mitten in einem Token abschneiden → bis zum letzten '_' kürzen
    TOKEN_LABEL="${TOKEN_LABEL%_*}"
  fi
  TAGS_CLEAN="${TOKEN_LABEL}__${TOKEN_HASH}"
  [ -z "$TAGS_CLEAN" ] && TAGS_CLEAN="Gesamt"

  mkdir -p exports
fi

echo "SORTED_UNIQUE=$SORTED_UNIQUE"
echo "TAGS_CLEAN=$TAGS_CLEAN"

# ── Ordner & Dateipfade ───────────────────────────────────────────
mkdir -p "exports/$TAGS_CLEAN"
OUTPUT_CV="exports/$TAGS_CLEAN/Lebenslauf_Lauffer.pdf"
OUTPUT_LETTER_txt="exports/$TAGS_CLEAN/Anschreiben_Lauffer.txt"

# ── metadata.toml Restore ────────────────────────────────────────
METADATA="metadata.toml"
BACKUP="${METADATA}.bak"

if [ -f "$METADATA" ] && grep -qE \
  '^[[:space:]]*first_name[[:space:]]*=[[:space:]]*"[[:space:]]*first_name[[:space:]]*"[[:space:]]*$' \
  "$METADATA"; then
  if [ -f "$BACKUP" ]; then
    echo "Detected placeholder first_name — restoring from $BACKUP"
    cp -- "$BACKUP" "$METADATA"
  else
    echo "Placeholder detected but $BACKUP not found." >&2
  fi
fi

# ── show_stack erkennen ──────────────────────────────────────────
if printf '%s\n' "$SORTED_UNIQUE" | grep -Piq "$regex"; then
  show_stack="true"
else
  show_stack="false"
fi

echo "show_stack=$show_stack"

# ── Header & Typst ───────────────────────────────────────────────
./build_header.sh "$TAGS_CLEAN" "./metadata.toml" "./mappings.json"

echo "▶ typst compile cv.typ --input filter=\"$SORTED_UNIQUE\" \"$OUTPUT_CV\""
typst compile cv.typ \
  --input filter="$SORTED_UNIQUE" \
  "$OUTPUT_CV" \
  --input show_stack="$show_stack"

echo ""
echo "────────────────────────────────────────"
echo "✅ PDF erfolgreich erstellt:"
echo "   $OUTPUT_CV"
echo "   (Mapping: exports/mapping.txt)"
echo "────────────────────────────────────────"

okular "$OUTPUT_CV"
kate "$cv_data_file"
kate "$OUTPUT_LETTER_txt"
