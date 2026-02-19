#!/bin/bash

# Default: Wenn kein Dateiname angegeben ist, suche nach "anschreiben.txt"
INPUT_FILE="${1:-Anschreiben_Lauffer.txt}"
OUTPUT_FILE="${2:-Anschreiben_Lauffer.pdf}"

# Prüfen, ob die Textdatei existiert
if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Fehler: Datei '$INPUT_FILE' nicht gefunden!"
    echo "Benutzung: ./build_letter.sh mein_text.txt [ausgabe.pdf]"
    exit 1
fi

echo "📄 Lese Text aus: $INPUT_FILE"
echo "🔨 Generiere PDF..."

# Typst aufrufen und den Dateinamen als Variable übergeben
# Wir übergeben auch 'quote', damit der Header zum CV passt (optional)
typst compile cover_letter.typ \
    --input file="$INPUT_FILE" \
    --input quote="Bewerbung als Sachbearbeiter im Kundenservice" \
    "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "✅ PDF erfolgreich erstellt: $OUTPUT_FILE"
    echo "okular $OUTPUT_FILE"
    okular $OUTPUT_FILE
else
    echo "❌ Fehler beim Erstellen des PDFs."
fi


