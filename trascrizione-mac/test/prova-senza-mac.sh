#!/bin/bash
# Prova i due comandi su Linux (o su Mac senza clic), simulando le finestre di dialogo.
# uso: test/prova-senza-mac.sh file_audio [annulla]
#   annulla → simula il clic su "Annulla" alla richiesta di installazione e si ferma
#
# Cosa fa:
#   1. Trascrivi-Audio.command (installazione + trascrizione + ritagli)
#   2. simula la correzione a mano: nella voce PAROLA 001 scrive «PAROLA_CORRETTA»
#      (o il valore di $CORREZIONE) e toglie gli asterischi dalla voce 002
#   3. Applica-Correzioni.command (trascrizione corretta + dizionario)
#   4. Trascrivi-Audio.command di nuovo, per vedere il dizionario in azione
# Usa modelli piccoli (base, tiny) e una HOME temporanea, per non toccare nulla di reale.

set -eu
QUI=$(cd "$(dirname "$0")" && pwd)
AUDIO=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
RISPOSTA_INSTALLA="${2:-installa}"
CORREZIONE="${CORREZIONE:-PAROLA_CORRETTA}"

PROVA=$(mktemp -d)
mkdir -p "$PROVA/bin" "$PROVA/home" "$PROVA/uscita"
LOG="$PROVA/finestre.log"

# osascript finto: registra ogni finestra e risponde come farebbe l'utente
cat > "$PROVA/bin/osascript" <<EOF
#!/bin/bash
if [ "\${1:-}" = "-e" ]; then
  case "\$2" in
    *"file di controllo"*) echo "== scelta file di controllo" >> "$LOG"; ls "$PROVA/uscita/"*_controllo*.txt | head -1 ;;
    *"choose file"*)       echo "== scelta file audio"        >> "$LOG"; echo "$AUDIO" ;;
    *"choose folder"*)     echo "== scelta cartella"          >> "$LOG"; echo "$PROVA/uscita/" ;;
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

esegui() {
  echo; echo "################ $1 ################" | tee -a "$LOG"
  PATH="$PROVA/bin:$PATH" HOME="$PROVA/home" \
    MODELLO_A="${MODELLO_A:-base}" MODELLO_B="${MODELLO_B:-tiny}" MODELLO_C="${MODELLO_C:-tiny}" \
    "$QUI/../$1" && echo "Esito: 0" || echo "Esito: $?"
}
mostra() {
  for f in "$@"; do
    [ -f "$f" ] || continue
    echo "---- $(basename "$f") ----"; cat "$f"
  done
}

esegui Trascrivi-Audio.command
if [ "$RISPOSTA_INSTALLA" != "annulla" ]; then
  CONTROLLO=$(ls "$PROVA/uscita/"*_controllo*.txt | head -1)
  # correzione a mano simulata
  sed -i.bak -E "s/^PAROLA 001: .*/PAROLA 001: $CORREZIONE/; s/^PAROLA 002: \*+([^*]*)\*+$/PAROLA 002: \1/" "$CONTROLLO"
  rm -f "$CONTROLLO.bak"
  esegui Applica-Correzioni.command
  mkdir -p "$PROVA/primo-giro" && mv "$PROVA/uscita/"* "$PROVA/primo-giro/"
  esegui Trascrivi-Audio.command
fi

echo; echo "======== Finestre mostrate ========"
cat "$LOG"
echo; echo "======== Primo giro ========"
mostra "$PROVA/primo-giro/"*.txt
ls "$PROVA/primo-giro/"*_clip* 2>/dev/null || true
echo; echo "======== Dizionario e esempi imparati ========"
mostra "$PROVA/home/Library/Application Support/TrascriviAudio/dizionario.txt"
ls "$PROVA/home/Library/Application Support/TrascriviAudio/esempi" 2>/dev/null || true
echo; echo "======== Secondo giro (con il dizionario) ========"
mostra "$PROVA/uscita/"*_controllo*.txt
echo "(file di prova in $PROVA)"
