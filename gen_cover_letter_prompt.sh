#!/bin/bash

# Keywords aus dem Lebenslauf-Skript übernehmen
keywords="$1"

# Dateien definieren
cv_data_file="filtered_cv_data.txt"  # Hier sollten die gefilterten CV-Daten liegen
job_ad_file="job_ad.txt"              # Hier liegt die Stellenanzeige
output_prompt_file="letter_prompt.txt" # Ausgabe-Datei für den generierten Prompt

# Überprüfe, ob die Dateien existieren
if [ ! -f "$cv_data_file" ]; then
    echo "Fehler: $cv_data_file nicht gefunden. Bitte stelle sicher, dass die gefilterten CV-Daten vorhanden sind."
    echo "kate $cv_data_file"
    exit 1
fi

if [ ! -f "$job_ad_file" ]; then
    echo "Fehler: $job_ad_file nicht gefunden. Bitte speichere die Stellenanzeige in dieser Datei."
    echo "kate $cv_data_file"
    echo "kate $job_ad_file"
    exit 1
fi

# Prompt generieren (strengere Version)
cat > "$output_prompt_file" <<EOL
**Role:** You are an expert copywriter for job applications. Your task is to write a **factually accurate** cover letter in German.
**Tone:** Professional, empathetic, structured.

**Strict Rules:**
- Use **only** the information provided in "My Background" and "The Job".
- Do **not** invent or exaggerate skills or experiences.
- If a skill is not explicitly mentioned in "My Background", do **not** include it.
- Focus on the keywords: $keywords.

**My Background (Resume Data):**
$(grep -v "@" "$cv_data_file")

**The Job (Requirement):**
$(cat "$job_ad_file")

**Instructions:**
- Start with the Company-Address if available
 Do NOT include any of my contact information (name, email, phone, address, homepage, GitHub, GitLab). The header is added automatically by the template!
- Connect my specific experience to the job requirements.
- Keep it under 1 page.
- Be concise and professional.
- You can use Typst formation like *bold* or -list or _cursiv_
EOL

# Ausgabe
echo "Prompt wurde erfolgreich generiert und in $output_prompt_file gespeichert."
echo "Du kannst den Prompt nun an Ollama/ChatGPT übergeben oder direkt verwenden."
echo "kate $output_prompt_file"
kate $output_prompt_file
echo "ollama run llama3.2"
ollama run llama3.2

###