#!/bin/bash
# Prova completa dell'app, dallo ZIP alla disinstallazione, simulando il Mac (test/finto-mac.sh).
# uso: test/prova-app.sh file_audio      (prima crea lo ZIP con ./crea-installatore.sh)
#
# Simula un Mac SENZA Python (il Python «portatile» è un file locale al posto di quello di GitHub)
# e con una versione precedente del programma installata altrove, con un progetto.
# Usa modelli piccoli (base, tiny). Alla fine stampa «TUTTE LE VERIFICHE SUPERATE» o le fallite.

set -u
QUI=$(cd "$(dirname "$0")/.." && pwd)
AUDIO=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
ZIP="$QUI/dist/TrascriviAudio.zip"
[ -f "$ZIP" ] || { echo "Manca $ZIP: esegui prima ./crea-installatore.sh"; exit 1; }
PROVA=$(mktemp -d)
. "$QUI/test/finto-mac.sh" "$PROVA"
export HOME="$PROVA/home" APPLICAZIONI="$PROVA/Applications" SALTA_SCHERMATA=1
export MODELLO_A="${MODELLO_A:-base}" MODELLO_B="${MODELLO_B:-tiny}" MODELLO_C="${MODELLO_C:-tiny}"
export PIP_CACHE_DIR="${PIP_CACHE_DIR:-/tmp/cache-pip-prove}"
export PYTHON_CANDIDATI=""   # nessun Python sul «Mac»
mkdir -p "$HOME/Desktop" "$HOME/Downloads" "$HOME/Documents" "$APPLICAZIONI"
APP="$APPLICAZIONI/Trascrivi Audio.app"
SUPPORTO="$HOME/Library/Application Support/TrascriviAudio"
DOCUMENTI="$HOME/Documents/Trascrivi Audio"
PROGETTI="$DOCUMENTI/Progetti"
GENERALE="$PROGETTI/elenco-progetti.json"
ICONA="$HOME/Desktop/Trascrivi Audio"
FALLITE=0

# Python «portatile» finto: un archivio come quello di python-build-standalone (cartella python/)
mkdir -p "$PROVA/py/python/bin"
printf '#!/bin/bash\nexec %s "$@"\n' "$(command -v python3)" > "$PROVA/py/python/bin/python3"
chmod +x "$PROVA/py/python/bin/python3"
tar -czf "$PROVA/python.tar.gz" -C "$PROVA/py" python
export PYTHON_PORTATILE_URL="file://$PROVA/python.tar.gz"
export PYTHON_PORTATILE_SHA256=$(shasum -a 256 "$PROVA/python.tar.gz" | cut -d' ' -f1)

# Versione precedente: programma in un'altra cartella, icona sulla Scrivania al suo .command,
# collegamento «Controlla Parole», un progetto «Vecchio progetto».
VECCHIA="$HOME/Programmi/Trascrivi Audio"
mkdir -p "$VECCHIA/Progetti/000_Vecchioprogetto"
for f in Trascrivi-Audio.command Controlla-Parole.command comune.sh progetti.py versione.txt; do echo vecchio > "$VECCHIA/$f"; done
echo "audio" > "$VECCHIA/Progetti/000_Vecchioprogetto/000_Vecchioprogetto_audio.mp3"
cat > "$VECCHIA/Progetti/elenco-progetti.json" <<EOF
{"progetti": [{"numero": "000", "nome": "Vecchio progetto", "cartella": "$VECCHIA/Progetti/000_Vecchioprogetto",
  "stato": "trascritto", "audio_originale": "", "file": {"audio": "000_Vecchioprogetto_audio.mp3"}}]}
EOF
ln -s "$VECCHIA/Trascrivi-Audio.command" "$ICONA"
ln -s "$VECCHIA/Controlla-Parole.command" "$HOME/Desktop/Controlla Parole"

esegui() {  # esegui "descrizione" comando...; output in $PROVA/ultimo.log
  echo; echo "################ $1 ################" | tee -a "$LOG"
  shift
  "$@" > "$PROVA/ultimo.log" 2>&1; ESITO=$?
  echo "esito: $ESITO"
  grep -E "^Progetto:|SCHERMATA|ERRORE|Parole da riverificare|Scarico|Installo|installato\.|spostati|Arrivederci|Disinstall" \
    "$PROVA/ultimo.log" | sed 's/^/   /'
}
verifica() { local d="$1"; shift; if "$@"; then echo "   OK  $d"; else echo "   NO  $d"; FALLITE=$((FALLITE + 1)); fi; }
json() { python3 -c "import json,sys; d=json.load(open(sys.argv[2])); print(eval(sys.argv[1]))" "$1" "$GENERALE"; }
contiene() { grep -q -- "$2" "$1"; }
non_contiene() { ! grep -q -- "$2" "$1"; }
non_esiste() { [ ! -e "$1" ] && [ ! -L "$1" ]; }
log_giro() { sed -n "/################ $1/,\$p" "$LOG"; }
prima_domanda() { log_giro "$1" | grep -m1 -E "^== (finestra|prompt)"; }

# ---------------------------------------------------------------------------------------------
# 1. Doppio clic sullo ZIP (estrae la cartella «Trascrivi Audio»), poi doppio clic sull'app
(cd "$HOME/Downloads" && unzip -q "$ZIP")
SCARICATA="$HOME/Downloads/Trascrivi Audio/Trascrivi Audio.app"
verifica "lo ZIP estrae la cartella «Trascrivi Audio» con app e guida" \
  [ -x "$SCARICATA/Contents/MacOS/TrascriviAudio" -a -f "$HOME/Downloads/Trascrivi Audio/Guida rapida.pdf" ]
risposte "Nuovo progetto" "Intervista Rossi" "$AUDIO" "ANNULLA"
esegui "1. Primo avvio dalla cartella scaricata" "$SCARICATA/Contents/MacOS/TrascriviAudio"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "app copiata in Applicazioni" [ -x "$APP/Contents/MacOS/TrascriviAudio" ]
verifica "blocco «scaricato da internet» tolto" contiene "$LOG" "xattr -dr com.apple.quarantine $APP"
verifica "programma aperto nel Terminale dalla copia in Applicazioni" contiene "$LOG" "Terminale apre: Trascrivi-Audio.command"
verifica "Python portatile installato senza chiedere" [ -x "$SUPPORTO/python/bin/python3" ]
verifica "Whisper installato" "$SUPPORTO/venv/bin/python" -c "import faster_whisper"
verifica "modelli scaricati durante l'installazione" contiene "$PROVA/ultimo.log" "Scarico il modello base"
verifica "nessuna domanda prima del menu" eval 'prima_domanda "1. Primo" | grep -q "Cosa vuoi fare?"'
verifica "avviso «Installazione completata»" contiene "$LOG" "Installazione completata"
verifica "icona sulla Scrivania → app in Applicazioni" [ "$(readlink "$ICONA")" = "$APP" ]
verifica "vecchio collegamento «Controlla Parole» tolto" non_esiste "$HOME/Desktop/Controlla Parole"
verifica "file della vecchia versione tolti" [ ! -e "$VECCHIA/comune.sh" -a ! -e "$VECCHIA/Trascrivi-Audio.command" ]
verifica "vecchio progetto spostato in Documenti" [ -f "$PROGETTI/000_Vecchioprogetto/000_Vecchioprogetto_audio.mp3" ]
verifica "vecchio progetto registrato con la nuova cartella" [ "$(json "d['progetti'][0]['cartella']")" = "$PROGETTI/000_Vecchioprogetto" ]
verifica "guida copiata in Documenti/Trascrivi Audio" [ -f "$DOCUMENTI/Guida rapida.pdf" ]
P1="$PROGETTI/001_IntervistaRossi"
verifica "nuovo progetto 001 in Documenti" [ -f "$P1/001_IntervistaRossi_controllo.txt" -a -f "$P1/001_IntervistaRossi_audio.mp3" ]
verifica "schermata aperta sul nuovo progetto" contiene "$PROVA/ultimo.log" "SCHERMATA (test): $P1/001_IntervistaRossi_controllo.txt"
verifica "ritorno al menu e uscita con «Esci»" contiene "$PROVA/ultimo.log" "Arrivederci"
verifica "file temporaneo cancellato" non_esiste "$PROGETTI/progetto-in-corso.json"
verifica "marcatore di installazione tolto" non_esiste "$SUPPORTO/installazione-da-completare"

# ---------------------------------------------------------------------------------------------
# 2. Avvio dall'icona della Scrivania: analisi, poi rielaborazione; nessuna reinstallazione
risposte "Apri un progetto" "Intervista Rossi" "Analisi delle parole" \
         "Apri un progetto" "Intervista Rossi" "Rielabora la trascrizione" "Rielabora" "ANNULLA"
esegui "2. Icona della Scrivania: analisi e rielaborazione" "$ICONA/Contents/MacOS/TrascriviAudio"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "nessuna nuova copia in Applicazioni" eval '! log_giro "2. Icona" | grep -q "xattr"'
verifica "nessuna reinstallazione né avvisi di installazione" eval '! grep -qE "Installo Whisper|Scarico" "$PROVA/ultimo.log" && ! log_giro "2. Icona" | grep -q "Installazione completata"'
verifica "la lista mostra i nomi dei progetti" eval 'log_giro "2. Icona" | grep -q "Scegli il progetto da aprire: | Vecchio progetto | Intervista Rossi"'
verifica "analisi sul progetto 001" contiene "$PROVA/ultimo.log" "SCHERMATA (test): $P1/001_IntervistaRossi_controllo.txt"
verifica "rielaborazione eseguita" [ "$(grep -c "Parole da riverificare" "$PROVA/ultimo.log")" -ge 1 ]

# ---------------------------------------------------------------------------------------------
# 3. Guida, nome duplicato, Annulla nei vari punti
risposte "Guida rapida" "Nuovo progetto" "intervista rossi" "ANNULLA" "Apri un progetto" "ANNULLA" "ANNULLA"
esegui "3. Guida, nome duplicato, Annulla" "$ICONA/Contents/MacOS/TrascriviAudio"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "guida aperta" contiene "$LOG" "aperto: $APP/Contents/Resources/programma/../Guida rapida.pdf"
verifica "nome duplicato rifiutato" contiene "$LOG" "Esiste già un progetto chiamato «intervista rossi»"
verifica "ancora due progetti" [ "$(json "len(d['progetti'])")" = 2 ]
verifica "file temporaneo cancellato" non_esiste "$PROGETTI/progetto-in-corso.json"

# ---------------------------------------------------------------------------------------------
# 4. Aggiornamento: nuova copia scaricata, avviata
mkdir -p "$HOME/Downloads/nuova" && (cd "$HOME/Downloads/nuova" && unzip -q "$ZIP")
risposte "ANNULLA"
esegui "4. Aggiornamento" "$HOME/Downloads/nuova/Trascrivi Audio/Trascrivi Audio.app/Contents/MacOS/TrascriviAudio"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "avviso «Aggiornamento completato»" eval 'log_giro "4. Agg" | grep -q "Aggiornamento completato"'
verifica "nessuna reinstallazione di Whisper" non_contiene "$PROVA/ultimo.log" "Installo Whisper"
verifica "progetti conservati" [ "$(json "len(d['progetti'])")" = 2 -a -d "$P1" ]

# ---------------------------------------------------------------------------------------------
# 5. Disinstalla conservando i progetti
risposte "Disinstalla Trascrivi Audio" "Conserva i progetti"
esegui "5. Disinstalla (conserva i progetti)" "$ICONA/Contents/MacOS/TrascriviAudio"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "app tolta da Applicazioni" non_esiste "$APP"
verifica "icona tolta dalla Scrivania" non_esiste "$ICONA"
verifica "Whisper, modelli e dati del programma tolti" non_esiste "$SUPPORTO"
verifica "progetti conservati in Documenti" [ -f "$P1/001_IntervistaRossi_audio.mp3" -a -f "$GENERALE" ]
verifica "avviso di disinstallazione" eval 'log_giro "5. Dis" | grep -q "è stato disinstallato"'

# ---------------------------------------------------------------------------------------------
# 6. Reinstallazione (ritrova i progetti), poi disinstalla tutto
risposte "Apri un progetto" "ANNULLA" "Disinstalla Trascrivi Audio" "Cancella anche i progetti" "Cancella tutto"
esegui "6. Reinstallazione e disinstalla tutto" "$SCARICATA/Contents/MacOS/TrascriviAudio"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "progetti ritrovati dopo la reinstallazione" eval 'log_giro "6. Rein" | grep -q "Scegli il progetto da aprire: | Vecchio progetto | Intervista Rossi"'
verifica "app tolta" non_esiste "$APP"
verifica "progetti cancellati" non_esiste "$DOCUMENTI"
verifica "dati del programma tolti" non_esiste "$SUPPORTO"

# ---------------------------------------------------------------------------------------------
# 7. Download di Python corrotto: installazione interrotta con un messaggio
PYTHON_PORTATILE_SHA256=0000 esegui "7. Python scaricato corrotto" "$SCARICATA/Contents/MacOS/TrascriviAudio"
verifica "messaggio «non è integro»" contiene "$LOG" "non è integro"
verifica "nessun Python installato" non_esiste "$SUPPORTO/python/bin/python3"

echo; echo "======== Finestre mostrate ========"; cat "$LOG"
echo
if [ "$FALLITE" = 0 ]; then echo "TUTTE LE VERIFICHE SUPERATE"; else echo "VERIFICHE FALLITE: $FALLITE"; fi
echo "(file di prova in $PROVA)"
[ "$FALLITE" = 0 ]
