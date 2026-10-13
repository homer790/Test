#!/bin/bash
# Prova Trascrivi-Audio.command su Linux (o su Mac senza clic), simulando le finestre di dialogo.
# uso: test/prova-senza-mac.sh file_audio [annulla]
#   annulla → simula il clic su "Annulla" alla richiesta di installazione
# Usa modelli piccoli (tiny/base) e una HOME temporanea, per non toccare nulla di reale.

set -eu
QUI=$(cd "$(dirname "$0")" && pwd)
AUDIO=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
RISPOSTA_INSTALLA="${2:-installa}"

PROVA=$(mktemp -d)
mkdir -p "$PROVA/bin" "$PROVA/home" "$PROVA/uscita"
LOG="$PROVA/finestre.log"

# osascript finto: registra ogni finestra e risponde come farebbe l'utente
cat > "$PROVA/bin/osascript" <<EOF
#!/bin/bash
if [ "\${1:-}" = "-e" ]; then
  case "\$2" in
    *"choose file"*)   echo "== scelta file"     >> "$LOG"; echo "$AUDIO" ;;
    *"choose folder"*) echo "== scelta cartella" >> "$LOG"; echo "$PROVA/uscita/" ;;
  esac
  exit 0
fi
shift
echo "== finestra: \$1" >> "$LOG"
cat > /dev/null
if [ "\$2" = "Installa" ] && [ "$RISPOSTA_INSTALLA" = "annulla" ]; then exit 1; fi
exit 0
EOF
# open finto: registra quale file verrebbe aperto
cat > "$PROVA/bin/open" <<EOF
#!/bin/bash
echo "== aperto: \$1" >> "$LOG"
EOF
chmod +x "$PROVA/bin/"*

PATH="$PROVA/bin:$PATH" HOME="$PROVA/home" MODELLO_A="${MODELLO_A:-base}" MODELLO_B="${MODELLO_B:-tiny}" \
  "$QUI/../Trascrivi-Audio.command" && ESITO=0 || ESITO=$?

echo
echo "################ Esito: $ESITO ################"
echo "---- Finestre mostrate ----"
cat "$LOG"
for f in "$PROVA/uscita/"*; do
  [ -e "$f" ] || continue
  echo "---- $(basename "$f") ----"
  cat "$f"
done
echo "(file di prova in $PROVA)"
