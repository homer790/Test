# finto-mac.sh — da includere nei test («. test/finto-mac.sh CARTELLA»): crea in CARTELLA/bin
# versioni finte dei comandi del Mac, per provare il programma su Linux senza clic.
#
# - osascript: simula le finestre. Le risposte dell'utente si scrivono, una per riga, nel file
#   $RISPOSTE (funzione «risposte»): il testo di un pulsante, un nome da scrivere, un percorso da
#   scegliere o una voce della lista; ANNULLA = clic su «Annulla»/«Esci». Le finestre con il solo
#   pulsante OK non consumano risposte. Ogni finestra viene registrata in $LOG.
# - open: «open -a Terminal FILE» esegue FILE (come il Terminale); «open APP.app» avvia l'app;
#   gli altri file vengono solo registrati («== aperto: ...»).
# - ditto (copia, registrata), xattr (nessun effetto, registrato).
# Con BASH_MAC=percorso di una bash 3.2 (quella del Mac) gli script del programma girano con quella.

FINTO="$1"
mkdir -p "$FINTO/bin"
export RISPOSTE="$FINTO/risposte.txt" LOG="$FINTO/finestre.log"
: > "$RISPOSTE"; : > "$LOG"
cat > "$FINTO/bin/osascript" <<'OSA'
#!/bin/bash
prossima() {  # toglie e stampa la prima risposta della coda
  local r; r=$(head -n 1 "$RISPOSTE"); sed -i.bak '1d' "$RISPOSTE"; rm -f "$RISPOSTE.bak"
  [ -n "$r" ] || { echo "   !! RISPOSTA MANCANTE" >> "$LOG"; exit 1; }
  echo "   -> $r" >> "$LOG"; [ "$r" = "ANNULLA" ] && exit 1; echo "$r"
}
if [ "${1:-}" = "-e" ]; then
  echo "== $(echo "$2" | grep -o 'prompt "[^"]*"' | head -1)" >> "$LOG"; prossima; exit 0
fi
shift; script=$(cat)
testo=$(printf '%s | ' "$@" | tr '\n' ' ' | cut -c1-200)
if echo "$script" | grep -q 'administrator privileges'; then echo "== password richiesta: $testo" >> "$LOG"; exit 1; fi
if echo "$script" | grep -q 'buttons {"OK"}'; then echo "== avviso: $testo" >> "$LOG"; exit 0; fi
echo "== finestra: $testo" >> "$LOG"; prossima
OSA
cat > "$FINTO/bin/open" <<'OPEN'
#!/bin/bash
if [ "$1" = "-a" ] && [ "$2" = "Terminal" ]; then
  echo "== Terminale apre: $(basename "$3")" >> "$LOG"; "${BASH_MAC:-bash}" "$3"; exit $?
fi
[ "$1" = "-n" ] && shift
case "$1" in
  *.app) echo "== avvio app: $1" >> "$LOG"; exec "${BASH_MAC:-bash}" "$1/Contents/MacOS/TrascriviAudio" ;;
  *) echo "== aperto: $1" >> "$LOG" ;;
esac
OPEN
cat > "$FINTO/bin/ditto" <<'DITTO'
#!/bin/bash
[ "$1" = "--noqtn" ] && shift
echo "== ditto $1 → $2" >> "$LOG"
cp -R "$1" "$2"
DITTO
printf '#!/bin/bash\necho "== xattr $*" >> "$LOG"\n' > "$FINTO/bin/xattr"
chmod +x "$FINTO/bin/"*
export PATH="$FINTO/bin:$PATH"
risposte() { printf '%s\n' "$@" > "$RISPOSTE"; }
