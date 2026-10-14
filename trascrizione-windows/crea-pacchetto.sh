#!/bin/bash
# Crea il pacchetto per Windows 11: dist/TrascriviAudio-Windows.zip
#
# Estraendo lo ZIP (tasto destro → «Estrai tutto…») si ottiene la cartella «Trascrivi Audio» con:
#   - Installa Trascrivi Audio.cmd   doppio clic: installa (o aggiorna) il programma e lo avvia
#   - Guida rapida.pdf               la guida per Windows
#   - programma\                     TrascriviAudio.ps1, Finestre.cs, icona e i file Python
#
# I file Python sono in comune con la versione Mac (cartella ../trascrizione-comune).
# uso: ./crea-pacchetto.sh

set -eu
QUI=$(cd "$(dirname "$0")" && pwd)
COMUNE="$QUI/../trascrizione-comune"
DIST="$QUI/dist"
VERSIONE=$(date +%Y.%m.%d)
LAVORO=$(mktemp -d)
trap 'rm -rf "$LAVORO"' EXIT

# --- 1. Guida in PDF: Markdown → HTML (pandoc, immagini incluse) → PDF (Chrome senza finestra)
GUIDA_PDF="$QUI/Guida rapida (Windows).pdf"
trova_chrome() {
  for c in "${CHROME:-}" "$(command -v chromium || true)" "$(command -v chromium-browser || true)" \
           "$(command -v google-chrome || true)" /opt/pw-browsers/chromium-*/chrome-linux/chrome; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}
if command -v pandoc >/dev/null && CHROME_BIN=$(trova_chrome); then
  (cd "$QUI/guida" && pandoc GUIDA-RAPIDA.md -s --embed-resources --css stile.css \
    --metadata pagetitle="Trascrivi Audio per Windows – Guida" --metadata lang=it -o "$LAVORO/guida.html")
  "$CHROME_BIN" --headless --no-sandbox --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="$LAVORO/guida.pdf" "file://$LAVORO/guida.html" 2>/dev/null
  [ -s "$LAVORO/guida.pdf" ] || { echo "Creazione del PDF non riuscita." >&2; exit 1; }
  mv "$LAVORO/guida.pdf" "$GUIDA_PDF"
  echo "Guida rapida (Windows).pdf rigenerata."
elif [ -e "$GUIDA_PDF" ]; then
  echo "ATTENZIONE: pandoc o Chrome non trovati, uso la guida PDF esistente (potrebbe non essere aggiornata)." >&2
else
  echo "Servono pandoc e Chrome (o Chromium) per creare la guida PDF." >&2
  exit 1
fi

# --- 2. La cartella «Trascrivi Audio»
CARTELLA="$LAVORO/Trascrivi Audio"
PROGRAMMA="$CARTELLA/programma"
mkdir -p "$PROGRAMMA"
cp "$QUI/avvio/Installa Trascrivi Audio.cmd" "$CARTELLA/"
cp "$GUIDA_PDF" "$CARTELLA/Guida rapida.pdf"
# TrascriviAudio.ps1 con il marcatore UTF-8 (BOM): senza, Windows PowerShell 5.1 mostra male gli accenti
python3 - "$QUI/programma/TrascriviAudio.ps1" "$PROGRAMMA/TrascriviAudio.ps1" <<'PY'
import sys
testo = open(sys.argv[1], encoding="utf-8-sig").read()
open(sys.argv[2], "w", encoding="utf-8-sig", newline="\r\n").write(testo)
PY
cp "$QUI/programma/Finestre.cs" "$QUI/programma/TrascriviAudio.ico" "$PROGRAMMA/"
cp "$COMUNE/progetti.py" "$COMUNE/trascrivi_dubbi.py" "$COMUNE/schermata_controllo.py" \
   "$COMUNE/applica_correzioni.py" "$COMUNE/modelli.py" "$PROGRAMMA/"
echo "$VERSIONE" > "$PROGRAMMA/versione.txt"

# --- 3. ZIP
mkdir -p "$DIST"
rm -f "$DIST/TrascriviAudio-Windows.zip"
(cd "$LAVORO" && zip -q -r -X "$DIST/TrascriviAudio-Windows.zip" "Trascrivi Audio")
echo "Creato dist/TrascriviAudio-Windows.zip (versione $VERSIONE):"
unzip -l "$DIST/TrascriviAudio-Windows.zip" | sed 's/^/  /'
