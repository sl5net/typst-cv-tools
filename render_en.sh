#!/bin/bash
# clear;time ./render_en.sh


# Fehler:
# "#image(\"assets/signature.png\", 3.5cm)": "#image(\"assets/signature.png\", XTYPCMD29X3.5cm)",
#  "#image(\"assets/signature.png\", 3.5cm)": "#image(\"assets/signature.png\", XTYPCMD29X3.5cm)",
# 29 │ #line(XTYPCMD25X4cm, XTYPCMD26X0.5pt)



# cp translation-cache-en.json translation-cache-en.json.bak2026-0513-0936

# veralteten Cache-Einträge translation-cache-en.json raus:

#jq 'with_entries(select(.value | test("X\\s*TYP(?:E)?\\s*CMD\\s*\\d+\\s*X"; "i") | not)) | with_entries(select(.key | contains("tags:") | not))' translation-cache-en.json > /tmp/cache-clean.json && mv /tmp/cache-clean.json translation-cache-en.json


# 1. Alte Übersetzungen löschen
# find . -name "*.i18n" -type d -exec rm -rf {} +

# rm tools/translation-cache-en.json



clear
echo "_____________________________"
echo "clear;time ./render_en.sh"
echo " time ./render_en.sh shows how long the script need."

echo "Starte Übersetzung und Build..."

# 1. Alte Übersetzungen löschen
# find . -name "*.i18n" -type d -exec rm -rf {} +
# rm modules_de/teaching.i18n/teaching-enlang.typ
# rm modules_de/professional.i18n/professional-enlang.typ

# 2. Python Script ausführen
echo ""
echo "/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\\"
python3 tools/translate_typst.py
echo "\_____________________________/"
echo ""



# 3. Kompilieren (mit --root . damit Pfade wie ../ funktionieren)
if [ -f "cv.i18n/cv-enlang.typ" ]; then
    echo "Gut Typst-Datei cv-enlang.typ existiert."
    espeak "Gut Typst-Datei cv-englisch existiert."
    echo "Kompiliere Englisch..."
    echo "/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\\"
    echo ""
    typst compile cv.i18n/cv-enlang.typ cv_en.pdf --root .
    echo ""
    echo "\_____________________________/"

    if [ -f "cv_en.pdf" ]; then
        echo "Fertig! Datei cv_en.pdf wurde erstellt."
        espeak "Super! Fertig! PDF-Datei für englischer Lebenslauf wurde erstellt."
        espeak "Diesmal hat es super geklappt. Glückwunsch."
    else
        echo "Fehler beim Erstellen des PDFs."
        espeak "Mist. Mist. Mist. Das PDF konnte nicht erstellt werden."
    fi
else
    echo "Fehler: cv.i18n/cv-enlang.typ wurde nicht gefunden!"
    espeak "Fehler: Die Übersetzung hat nicht geklappt."
fi
