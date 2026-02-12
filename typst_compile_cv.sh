#!/bin/bash

# Beispielaufruf:
# ./typst_compile_cv.sh "Social|it|edu-it|SQL|AI|Java|PHP|API|PostgreSQL|Docker|Laravel|Vue|AI"

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
OUTPUT="exports/$TAGS_CLEAN/Lebenslauf_Lauffer.pdf"





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







# ./build_header.sh "$TAGS_CLEAN" "./metadata.toml"
./build_header.sh "$TAGS_CLEAN" "./metadata.toml" "./mappings.json"


# 5. Typst ausführen
echo 'command with regex-filter: typst compile cv.typ --input filter="..." "$OUTPUT" --input show_stack="true"'


echo $SORTED_UNIQUE
typst compile cv.typ --input filter="$SORTED_UNIQUE" "$OUTPUT" --input show_stack="true"

echo "----------------------------------------"
echo "✅ PDF erfolgreich erstellt:"
echo "📂 $OUTPUT"
echo "----------------------------------------"

okular $OUTPUT
