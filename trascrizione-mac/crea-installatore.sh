#!/bin/bash
# Crea l'installatore autoestraente per Mac:
#   dist/Installa-TrascriviAudio.zip, che contiene Installa-TrascriviAudio.command
#   (script + archivio dei file in coda). Lo ZIP conserva il permesso di esecuzione.
# uso: ./crea-installatore.sh

set -eu
QUI=$(cd "$(dirname "$0")" && pwd)
DIST="$QUI/dist"
VERSIONE=$(date +%Y.%m.%d)
LAVORO=$(mktemp -d)
trap 'rm -rf "$LAVORO"' EXIT

# --- Guida rapida in PDF: GUIDA-RAPIDA.md → HTML (pandoc) → PDF (Chrome/Chromium senza finestra).
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
  pandoc "$QUI/GUIDA-RAPIDA.md" -s --embed-resources --css "$QUI/guida-stile.css" \
    --metadata pagetitle="Trascrivi Audio – Guida rapida" --metadata lang=it -o "$LAVORO/guida.html"
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

# --- File dell'applicazione da mettere nell'archivio
mkdir -p "$LAVORO/app"
cp "$QUI/Trascrivi-Audio.command" "$QUI/Controlla-Parole.command" "$QUI/Applica-Correzioni.command" \
   "$QUI/schermata_controllo.py" "$QUI/applica_correzioni.py" "$LAVORO/app/"
cp "$GUIDA_PDF" "$LAVORO/app/Guida rapida.pdf"
cp "$QUI/GUIDA-RAPIDA.md" "$LAVORO/app/Guida rapida.md"
cp "$QUI/LEGGIMI.md" "$LAVORO/app/Istruzioni complete.txt"
echo "$VERSIONE" > "$LAVORO/app/versione.txt"
chmod +x "$LAVORO/app/"*.command
# COPYFILE_DISABLE: niente file ._ di macOS nell'archivio, se lo si crea su Mac
COPYFILE_DISABLE=1 tar -czf "$LAVORO/app.tar.gz" -C "$LAVORO/app" .

# --- Intestazione: lo script che estrae l'archivio
mkdir -p "$DIST"
INSTALLATORE="$DIST/Installa-TrascriviAudio.command"
sed "s/@VERSIONE@/$VERSIONE/" > "$INSTALLATORE" <<'EOF'
#!/bin/bash
# Installatore autoestraente di Trascrivi Audio (versione @VERSIONE@).
# Doppio clic: chiede la cartella, estrae i file, installa Python e Whisper se mancano
# (chiedendo conferma) e crea i collegamenti
# sulla Scrivania. Rilanciarlo scegliendo la stessa cartella aggiorna il programma
# senza toccare dizionario, esempi e trascrizioni.

set -u
TITOLO="Installa Trascrivi Audio"
NOME_CARTELLA="Trascrivi Audio"

avviso() {
  osascript - "$1" "${2:-note}" "$TITOLO" >/dev/null 2>&1 <<'OSA'
on run argv
  set icona to note
  if item 2 of argv is "stop" then set icona to stop
  display dialog (item 1 of argv) buttons {"OK"} default button "OK" with title (item 3 of argv) with icon icona
end run
OSA
}
domanda() {
  osascript - "$1" "$2" "$TITOLO" >/dev/null 2>&1 <<'OSA'
on run argv
  display dialog (item 1 of argv) buttons {"Annulla", item 2 of argv} default button (item 2 of argv) cancel button "Annulla" with title (item 3 of argv)
end run
OSA
}
errore() { avviso "$1" stop; echo "ERRORE: $1"; exit 1; }

domanda "Benvenuto nell'installazione di Trascrivi Audio (versione @VERSIONE@).

Ora ti chiederò in quale cartella installarlo: verrà creata la cartella «$NOME_CARTELLA».
Poi controllerò se sul Mac ci sono Python e Whisper: se mancano, ti chiederò
se installarli (puoi sempre annullare).
Sulla Scrivania troverai i collegamenti «Trascrivi Audio» e «Controlla Parole».

Se il programma è già installato, scegli la stessa cartella per aggiornarlo:
dizionario, esempi e trascrizioni non vengono toccati." "Continua" || exit 0

SCELTA=$(osascript -e 'POSIX path of (choose folder with prompt "In quale cartella installo Trascrivi Audio? (verrà creata la cartella «Trascrivi Audio»)" default location (path to documents folder))' 2>/dev/null) \
  || { echo "Nessuna cartella scelta."; exit 0; }
SCELTA="${SCELTA%/}"
# Se l'utente ha scelto direttamente la cartella «Trascrivi Audio», usiamo quella
if [ "$(basename "$SCELTA")" = "$NOME_CARTELLA" ]; then DEST="$SCELTA"; else DEST="$SCELTA/$NOME_CARTELLA"; fi

if [ -e "$DEST/Trascrivi-Audio.command" ]; then
  domanda "In «$DEST» c'è già Trascrivi Audio (versione $(cat "$DEST/versione.txt" 2>/dev/null || echo "?")).

Vuoi aggiornarlo alla versione @VERSIONE@?" "Aggiorna" || exit 0
fi

# --- Estrazione dell'archivio che sta in coda a questo file
mkdir -p "$DEST" || errore "Non riesco a creare la cartella $DEST."
INIZIO=$(awk '/^__ARCHIVIO__$/ { print NR + 1; exit }' "$0")
tail -n +"$INIZIO" "$0" | tar -xzf - -C "$DEST" || errore "Estrazione dei file non riuscita."
chmod +x "$DEST/"*.command
# I file estratti non devono essere bloccati da macOS come "scaricati da internet"
command -v xattr >/dev/null && xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
echo "File estratti in: $DEST"

# --- Controllo e installazione di Python e Whisper (solo se mancano, chiedendo conferma)
"$DEST/Trascrivi-Audio.command" --installa || errore "Installazione di Python o Whisper non riuscita. Guarda la finestra del Terminale."
VENV="$HOME/Library/Application Support/TrascriviAudio/venv"
if "$VENV/bin/python" -c 'import faster_whisper' 2>/dev/null; then
  STATO_WHISPER="Python e Whisper sono installati."
else
  STATO_WHISPER="Python e/o Whisper non sono stati installati: verranno proposti al primo avvio di «Trascrivi Audio»."
fi

# --- Collegamenti sulla Scrivania
SCRIVANIA="$HOME/Desktop"
mkdir -p "$SCRIVANIA"
ln -sfn "$DEST/Trascrivi-Audio.command" "$SCRIVANIA/Trascrivi Audio"
ln -sfn "$DEST/Controlla-Parole.command" "$SCRIVANIA/Controlla Parole"
rm -f "$SCRIVANIA/Applica Correzioni"  # collegamento delle versioni precedenti: ora si usa «Controlla Parole»

avviso "Installazione completata.

$STATO_WHISPER

Sulla Scrivania trovi:
• Trascrivi Audio – per trascrivere un file audio
• Controlla Parole – per riprendere il controllo delle parole dubbie

I file del programma e la guida rapida sono in:
$DEST"
command -v open >/dev/null && open "$DEST"
echo "Fatto. Puoi chiudere questa finestra."
exit 0
__ARCHIVIO__
EOF
cat "$LAVORO/app.tar.gz" >> "$INSTALLATORE"
chmod +x "$INSTALLATORE"

# ZIP con i permessi Unix (il Mac li rispetta quando lo si apre con doppio clic)
rm -f "$DIST/Installa-TrascriviAudio.zip"
(cd "$DIST" && zip -q -X Installa-TrascriviAudio.zip Installa-TrascriviAudio.command)
rm "$INSTALLATORE"  # si distribuisce solo lo ZIP
echo "Creati:"
ls -la "$DIST"
