# BTW gemini cant remember name correctly for 2 mnute (2026-0211-1613 , 11.2.'26 16:13 Wed)
echo "Log: gemini cant remember name correctly for 2 mnute (2026-0211-1613 , 11.2.'26 16:13 Wed)"

# Liste aller Namen, die ich fälschlicherweise verwenden könnte
aliases=(
  "build_cv.sh"
  "create_cv.sh"
  "compile_cv.sh"
  "make_cv.sh"
  "gen_cv.sh"
  "generate_cv.sh"
  "build.sh"
  "make.sh"
  "compile.sh"
  "generate.sh"
  "run.sh"
  "cv.sh"
)

# Erstellt für jeden Namen eine Weiterleitung auf dein echtes Skript
for script in "${aliases[@]}"; do
    echo '#!/bin/bash' > "$script"
    echo './typst_compile_cv.sh "$@"' >> "$script"
    chmod +x "$script"
    echo "Alias erstellt: $script -> ./typst_compile_cv.sh"
done
