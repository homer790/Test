#!/bin/bash
# Prova l'installatore autoestraente su Linux (o su Mac senza clic), simulando le finestre.
# uso: test/prova-installatore.sh   (prima esegue ./crea-installatore.sh)
# Simula: prima installazione, poi aggiornamento nella stessa cartella. Usa una HOME temporanea.

set -eu
QUI=$(cd "$(dirname "$0")" && pwd)
"$QUI/../crea-installatore.sh" >/dev/null

PROVA=$(mktemp -d)
mkdir -p "$PROVA/bin" "$PROVA/home" "$PROVA/scaricati" "$PROVA/Documenti"
LOG="$PROVA/finestre.log"

cat > "$PROVA/bin/osascript" <<EOF
#!/bin/bash
if [ "\${1:-}" = "-e" ]; then
  case "\$2" in
    *"choose folder"*) echo "== scelta cartella" >> "$LOG"; echo "$PROVA/Documenti/" ;;
  esac
  exit 0
fi
shift
echo "== finestra: \$1" >> "$LOG"
cat > /dev/null
exit 0
EOF
cat > "$PROVA/bin/open" <<EOF
#!/bin/bash
echo "== aperto: \$1" >> "$LOG"
EOF
chmod +x "$PROVA/bin/"*

# Come sul Mac: si scarica lo ZIP, lo si apre e si lancia il .command
(cd "$PROVA/scaricati" && unzip -q "$QUI/../dist/Installa-TrascriviAudio.zip")
for giro in "Prima installazione" "Aggiornamento"; do
  echo "################ $giro ################" | tee -a "$LOG"
  PATH="$PROVA/bin:$PATH" HOME="$PROVA/home" "$PROVA/scaricati/Installa-TrascriviAudio.command" \
    > "$PROVA/terminale.log" 2>&1 && echo "Esito: 0" || echo "Esito: $?"
  tail -3 "$PROVA/terminale.log"
done

echo; echo "======== Finestre mostrate ========"; cat "$LOG"
echo; echo "======== Cartella installata ========"; ls -la "$PROVA/Documenti/Trascrivi Audio"
echo; echo "======== Scrivania ========"; ls -la "$PROVA/home/Desktop"
echo; echo "======== Whisper ========"
"$PROVA/home/Library/Application Support/TrascriviAudio/venv/bin/python" -c 'import faster_whisper; print("faster-whisper", faster_whisper.__version__)'
echo "(file di prova in $PROVA)"
