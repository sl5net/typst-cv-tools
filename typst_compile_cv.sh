#!/bin/bash
# Beispielaufruf:
# ./typst_compile_cv.sh "Social|it|edu-it|SQL|AI|Java|PHP|API|PostgreSQL|Docker|Laravel|Vue|AI"

cv_data_file="filtered_cv_data.txt"  # Hier sollten die gefilterten CV-Daten liegen
job_ad_file="job_ad.txt"              # Hier liegt die Stellenanzeige
output_prompt_file="cover_letter_prompt.txt" # Ausgabe-Datei für den generierten Prompt


# Try find out if show_stack should set True.
# Example keywords (tweak as needed)
keywordsIT=( "IT" "informatics" "python" "java" "javascript" "js" "php" "c\+\+" "cpp" "devops" "ci" "linux" "security" "database" "postgresql" "db2" "matlab" "embedded" "automation" "ai" "llm" "rag" "architecture" "scripting" )

# Join into a single alternation regex, anchor with word boundaries.
# We escape any slashes/newlines, and make it case-insensitive later.
regex="\b($(IFS='|'; echo "${keywordsIT[*]}"))\b"


FILTER=$1

# Falls kein Filter angegeben wurde, nennen wir es "Gesamt"
if [ -z "$FILTER" ]; then
  TAGS_CLEAN="Gesamt"
else


    # Normalize separators: replace commas and semicolons and multiple spaces with a single '|'
    # - First replace commas and semicolons with '|'
    # - Then replace runs of whitespace with '|'
    # - Then collapse multiple '|' into a single '|'
  # Replace ',' and ';' with '|'
  NORMALIZED=${FILTER//,/|}
  NORMALIZED=${NORMALIZED//;/|}

  # Replace any whitespace runs with '|'
  # (uses parameter expansion with a bash pattern)
  NORMALIZED=${NORMALIZED//[[:space:]]/|}

  # Collapse repeated '|' into a single '|'
  # This uses 'sed' to simplify consecutive pipes
  NORMALIZED=$(printf '%s' "$NORMALIZED" | sed 's/|\\{2,\\}/|/g')

  # Trim leading/trailing '|' if present (optional, keeps empty items away)
  NORMALIZED=$(printf '%s' "$NORMALIZED" | sed 's/^|//; s/|$//')

  # Split, sort unique, and rejoin with '|'
  SORTED_UNIQUE=$(printf '%s\n' "${NORMALIZED//|/$'\n'}" | grep -v '^$' | sort -u | paste -sd'|' -)

  # Underscore-safe version
  TAGS_CLEAN=${SORTED_UNIQUE//|/_}

  [ -z "$TAGS_CLEAN" ] && TAGS_CLEAN="Gesamt"

fi

echo "SORTED_UNIQUE=$SORTED_UNIQUE"
echo "TAGS_CLEAN=$TAGS_CLEAN"

# 3. Ordner erstellen
mkdir -p exports
mkdir -p exports/$TAGS_CLEAN

# 4. Dateiname generieren
OUTPUT_CV="exports/$TAGS_CLEAN/Lebenslauf_Lauffer.pdf"
OUTPUT_LETTER_txt="exports/$TAGS_CLEAN/Anschreiben_Lauffer.txt"





METADATA="metadata.toml"
BACKUP="${METADATA}.bak"

# Wenn metadata.toml existiert und exakt die Zeile first_name = "first_name" enthält,
# dann restore aus metadata.toml.bak (falls vorhanden).
if [ -f "$METADATA" ] && grep -qE '^[[:space:]]*first_name[[:space:]]*=[[:space:]]*"[[:space:]]*first_name[[:space:]]*"[[:space:]]*$' "$METADATA"; then
  if [ -f "$BACKUP" ]; then
    echo "Detected placeholder first_name in $METADATA — restoring from $BACKUP"
    cp -- "$BACKUP" "$METADATA"
    echo "Restored $METADATA from backup."
  else
    echo "Placeholder detected but backup $BACKUP not found; proceeding without restore." >&2
  fi
fi




# Use grep -E -i; it understands \b (word boundary) only in GNU grep with -P or with GNU's -E? Safer to use grep -P if available.
if printf '%s\n' "$SORTED_UNIQUE" | grep -Piq "$regex"; then
  show_stack="true"
else
  show_stack="false"
fi






# ./build_header.sh "$TAGS_CLEAN" "./metadata.toml"
./build_header.sh "$TAGS_CLEAN" "./metadata.toml" "./mappings.json"


# 5. Typst ausführen
echo 'command with regex-filter: typst compile cv.typ --input filter="..." "$OUTPUT_CV" --input show_stack="$show_stack"'


echo $SORTED_UNIQUE
typst compile cv.typ --input filter="$SORTED_UNIQUE" "$OUTPUT_CV" --input show_stack="$show_stack"

echo "----------------------------------------"
echo "✅ PDF erfolgreich erstellt:"
echo "📂 $OUTPUT_CV"
echo "----------------------------------------"
echo "okular $OUTPUT_CV"
okular $OUTPUT_CV

kate $cv_data_file

# experimental:

# Anschreiben generieren (mit Prompt-Parameter)
#OUTPUT_LETTER="exports/$TAGS_CLEAN/Lebenslauf_Anschreiben.pdf"
#typst compile cv.typ --input its_cover_letter_prompt="1" "$OUTPUT_LETTER" --input show_stack="$show_stack"

# PDFs öffnen
#okular "$OUTPUT_LETTER"

#okular $OUTPUT_CV

kate $OUTPUT_LETTER_txt

# Nach der PDF-Generierung:
echo "Generiere Prompt für das Anschreiben..."
./gen_cover_letter_prompt.sh "$SORTED_UNIQUE"

