#!/bin/bash
# Crea il pacchetto da distribuire: dist/TrascriviAudio.zip
#
# Con un doppio clic sullo ZIP, il Mac estrae la cartella «Trascrivi Audio» con dentro:
#   - Trascrivi Audio.app   l'app: al primo avvio si copia in Applicazioni e prepara tutto da sola
#   - Guida rapida.pdf      la guida
#
# Passi: guida PDF (da guida/GUIDA-RAPIDA.md) → icona .icns (da app/icona.png) → app → ZIP.
# uso: ./crea-installatore.sh

set -eu
QUI=$(cd "$(dirname "$0")" && pwd)
DIST="$QUI/dist"
VERSIONE=$(date +%Y.%m.%d)
LAVORO=$(mktemp -d)
trap 'rm -rf "$LAVORO"' EXIT

# --- 1. Guida rapida in PDF: Markdown → HTML (pandoc, immagini incluse) → PDF (Chrome senza finestra).
# Se mancano gli strumenti si usa il PDF già presente nel repository.
GUIDA_PDF="$QUI/Guida rapida.pdf"
trova_chrome() {
  for c in "${CHROME:-}" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           "$(command -v chromium || true)" "$(command -v chromium-browser || true)" \
           "$(command -v google-chrome || true)" /opt/pw-browsers/chromium-*/chrome-linux/chrome; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}
if command -v pandoc >/dev/null && CHROME_BIN=$(trova_chrome); then
  (cd "$QUI/guida" && pandoc GUIDA-RAPIDA.md -s --embed-resources --css stile.css \
    --metadata pagetitle="Trascrivi Audio – Guida rapida" --metadata lang=it -o "$LAVORO/guida.html")
  "$CHROME_BIN" --headless --no-sandbox --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="$LAVORO/guida.pdf" "file://$LAVORO/guida.html" 2>/dev/null
  [ -s "$LAVORO/guida.pdf" ] || { echo "Creazione del PDF non riuscita." >&2; exit 1; }
  mv "$LAVORO/guida.pdf" "$GUIDA_PDF"
  echo "Guida rapida.pdf rigenerata."
elif [ -e "$GUIDA_PDF" ]; then
  echo "ATTENZIONE: pandoc o Chrome non trovati, uso «Guida rapida.pdf» esistente (potrebbe non essere aggiornata)." >&2
else
  echo "Servono pandoc e Chrome (o Chromium) per creare «Guida rapida.pdf»." >&2
  exit 1
fi

# --- 2. Icona dell'app (.icns) dal disegno (app/icona.png, creata da app/crea-icona.js)
if python3 -c 'import PIL' 2>/dev/null; then
  python3 -c "from PIL import Image; Image.open('$QUI/app/icona.png').save('$QUI/app/AppIcon.icns')"
fi
[ -s "$QUI/app/AppIcon.icns" ] || { echo "Manca app/AppIcon.icns (serve Python con Pillow)." >&2; exit 1; }

# --- 3. L'app: Trascrivi Audio.app
CARTELLA="$LAVORO/Trascrivi Audio"
APP="$CARTELLA/Trascrivi Audio.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/programma"
sed "s/@VERSIONE@/$VERSIONE/g" "$QUI/app/Info.plist" > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$QUI/app/TrascriviAudio" "$APP/Contents/MacOS/TrascriviAudio"
cp "$QUI/app/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$QUI/programma/Trascrivi-Audio.command" "$QUI/programma/comune.sh" "$QUI/programma/progetti.py" \
   "$QUI/programma/trascrivi_dubbi.py" "$QUI/programma/schermata_controllo.py" \
   "$QUI/programma/applica_correzioni.py" "$APP/Contents/Resources/programma/"
cp "$GUIDA_PDF" "$APP/Contents/Resources/Guida rapida.pdf"
echo "$VERSIONE" > "$APP/Contents/Resources/versione.txt"
chmod 755 "$APP/Contents/MacOS/TrascriviAudio" "$APP/Contents/Resources/programma/Trascrivi-Audio.command"
python3 -c "import plistlib,sys; plistlib.load(open(sys.argv[1],'rb'))" "$APP/Contents/Info.plist" \
  || { echo "Info.plist non valido." >&2; exit 1; }
cp "$GUIDA_PDF" "$CARTELLA/Guida rapida.pdf"

# --- 4. ZIP con i permessi Unix (il Mac li rispetta quando lo si apre con doppio clic)
mkdir -p "$DIST"
rm -f "$DIST/TrascriviAudio.zip" "$DIST/Installa-TrascriviAudio.zip"
(cd "$LAVORO" && COPYFILE_DISABLE=1 zip -q -r -X -y "$DIST/TrascriviAudio.zip" "Trascrivi Audio")
echo "Creato dist/TrascriviAudio.zip (versione $VERSIONE):"
unzip -l "$DIST/TrascriviAudio.zip" | sed 's/^/  /'
