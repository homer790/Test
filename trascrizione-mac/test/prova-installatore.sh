#!/bin/bash
# Prova l'installatore autoestraente, simulando le finestre del Mac (test/finto-mac.sh).
# uso: test/prova-installatore.sh   (rigenera prima lo ZIP con ./crea-installatore.sh)
# Simula: installazione con collegamenti di una versione precedente sulla Scrivania, avvio
# automatico di Trascrivi Audio (annullato), poi aggiornamento nella stessa cartella.

set -u
QUI=$(cd "$(dirname "$0")/.." && pwd)
"$QUI/crea-installatore.sh" >/dev/null || exit 1
PROVA=$(mktemp -d)
. "$QUI/test/finto-mac.sh" "$PROVA"
export HOME="$PROVA/home"
mkdir -p "$HOME/Desktop" "$PROVA/scaricati" "$PROVA/Documenti"
touch "$HOME/Desktop/Controlla Parole" "$HOME/Desktop/Applica Correzioni"  # versione precedente
FALLITE=0
verifica() { local d="$1"; shift; if "$@"; then echo "   OK  $d"; else echo "   NO  $d"; FALLITE=$((FALLITE + 1)); fi; }

(cd "$PROVA/scaricati" && unzip -q "$QUI/dist/Installa-TrascriviAudio.zip")
DEST="$PROVA/Documenti/Trascrivi Audio"

echo "################ Prima installazione ################" | tee -a "$LOG"
risposte "Continua" "$PROVA/Documenti/" "Installa" "ANNULLA"
"$PROVA/scaricati/Installa-TrascriviAudio.command" > "$PROVA/terminale1.log" 2>&1; echo "esito: $?"
verifica "file del programma estratti" [ -x "$DEST/Trascrivi-Audio.command" -a -f "$DEST/progetti.py" -a -f "$DEST/comune.sh" ]
verifica "guida .md e .pdf" [ -f "$DEST/Guida rapida.md" -a -f "$DEST/Guida rapida.pdf" ]
verifica "cartella Progetti" [ -d "$DEST/Progetti" ]
verifica "collegamento «Trascrivi Audio»" [ -L "$HOME/Desktop/Trascrivi Audio" ]
verifica "vecchi collegamenti tolti" [ ! -e "$HOME/Desktop/Controlla Parole" -a ! -e "$HOME/Desktop/Applica Correzioni" ]
verifica "Whisper installato" "$HOME/Library/Application Support/TrascriviAudio/venv/bin/python" -c 'import faster_whisper'
verifica "Trascrivi Audio avviato da solo dopo l'installazione" grep -q "Vuoi aprire un progetto esistente" "$LOG"

echo "################ Aggiornamento ################" | tee -a "$LOG"
risposte "Continua" "$PROVA/Documenti/" "Aggiorna" "ANNULLA"
"$PROVA/scaricati/Installa-TrascriviAudio.command" > "$PROVA/terminale2.log" 2>&1; echo "esito: $?"
verifica "proposto l'aggiornamento" grep -q "c'è già Trascrivi Audio" "$LOG"
verifica "Whisper non richiesto di nuovo" [ "$(grep -c "installare Whisper" "$LOG")" = 1 ]
verifica "cartella Progetti conservata" [ -d "$DEST/Progetti" ]

echo; echo "======== Finestre mostrate ========"; cat "$LOG"
echo; echo "======== Scrivania ========"; ls -la "$HOME/Desktop"
echo
if [ "$FALLITE" = 0 ]; then echo "TUTTE LE VERIFICHE SUPERATE"; else echo "VERIFICHE FALLITE: $FALLITE"; fi
echo "(file di prova in $PROVA)"
[ "$FALLITE" = 0 ]
