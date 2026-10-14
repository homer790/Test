# comune.sh — funzioni condivise dal programma (da includere con «. comune.sh»).
# Prima di includerlo si impostano QUI (cartella del programma) e TITOLO (titolo delle finestre).

SUPPORTO="$HOME/Library/Application Support/TrascriviAudio"
VENV="$SUPPORTO/venv"
export DIZIONARIO="$SUPPORTO/dizionario.txt"   # dizionario personale, comune a tutti i progetti
export ESEMPI="$SUPPORTO/esempi"
# Progetti in Documenti/Trascrivi Audio/Progetti (visibili nel Finder, al sicuro negli aggiornamenti)
export PYTHONDONTWRITEBYTECODE=1   # niente file di cache di Python dentro l'app in Applicazioni
export HF_HUB_DISABLE_TELEMETRY=1  # nessuna statistica inviata durante i download dei modelli
export CARTELLA_DOCUMENTI="${CARTELLA_DOCUMENTI:-$HOME/Documents/Trascrivi Audio}"
export CARTELLA_PROGETTI="${CARTELLA_PROGETTI:-$CARTELLA_DOCUMENTI/Progetti}"

# --- Finestre di dialogo (testi passati come argomenti, così le virgolette non creano problemi)

avviso() {  # avviso "messaggio" [note|caution|stop]
  osascript - "$1" "${2:-note}" "$TITOLO" >/dev/null 2>&1 <<'EOF'
on run argv
  set icona to note
  if item 2 of argv is "caution" then set icona to caution
  if item 2 of argv is "stop" then set icona to stop
  display dialog (item 1 of argv) buttons {"OK"} default button "OK" with title (item 3 of argv) with icon icona
end run
EOF
}

domanda() {  # domanda "messaggio" "pulsante sì" → 0 se confermato, 1 se annullato
  osascript - "$1" "$2" "$TITOLO" >/dev/null 2>&1 <<'EOF'
on run argv
  display dialog (item 1 of argv) buttons {"Annulla", item 2 of argv} default button (item 2 of argv) cancel button "Annulla" with title (item 3 of argv)
end run
EOF
}

scelta() {  # scelta "messaggio" "Annulla" "pulsante 2" ["pulsante 3"] → stampa il pulsante scelto; 1 se Annulla
  osascript - "$TITOLO" "$@" 2>/dev/null <<'EOF'
on run argv
  set pulsanti to items 3 thru -1 of argv
  set r to display dialog (item 2 of argv) buttons pulsanti default button (last item of pulsanti) cancel button "Annulla" with title (item 1 of argv)
  return button returned of r
end run
EOF
}

chiedi_testo() {  # chiedi_testo "messaggio" → stampa il testo scritto; 1 se Annulla
  osascript - "$TITOLO" "$1" 2>/dev/null <<'EOF'
on run argv
  set r to display dialog (item 2 of argv) default answer "" buttons {"Annulla", "Avanti"} default button "Avanti" cancel button "Annulla" with title (item 1 of argv)
  return text returned of r
end run
EOF
}

scegli_dalla_lista() {  # scegli_dalla_lista "messaggio" voce1 voce2 ... → stampa la voce scelta; 1 se si esce
  local r                # (pulsante per uscire: $ESCI_LISTA, predefinito «Annulla»)
  r=$(osascript - "$TITOLO" "${ESCI_LISTA:-Annulla}" "$@" 2>/dev/null <<'EOF'
on run argv
  set voci to items 4 thru -1 of argv
  set r to choose from list voci with title (item 1 of argv) with prompt (item 3 of argv) default items {item 1 of voci} OK button name "Avanti" cancel button name (item 2 of argv)
  if r is false then return "§ANNULLA§"
  return item 1 of r
end run
EOF
) || return 1
  [ "$r" != "§ANNULLA§" ] || return 1
  printf '%s\n' "$r"
}

errore() {
  avviso "$1

Dettagli nella finestra del Terminale." stop
  echo
  echo "ERRORE: $1"
  exit 1
}

menu_principale() {  # stampa la voce scelta nel menu principale; 1 se «Esci»
  ESCI_LISTA="Esci" scegli_dalla_lista "Cosa vuoi fare?" \
    "Nuovo progetto" "Apri un progetto" "Guida rapida" "Disinstalla Trascrivi Audio"
}

# --- Python del programma: quello di Whisper o il portatile, MAI il python3 di sistema
#     (su un Mac senza strumenti per sviluppatori farebbe comparire una richiesta di Apple)

python_programma() {
  if [ -x "$VENV/bin/python" ]; then echo "$VENV/bin/python"; return 0; fi
  if [ -x "$SUPPORTO/python/bin/python3" ]; then echo "$SUPPORTO/python/bin/python3"; return 0; fi
  return 1
}

# --- Progetti (vedi progetti.py)

progetto() {
  local py
  py=$(python_programma) || return 1
  "$py" "$QUI/progetti.py" "$@"
}

seleziona_progetto() {  # seleziona_progetto "messaggio" [--trascritti] → rende in corso il progetto scelto; 1 se Annulla
  local nomi=() r nome msg
  while IFS= read -r r; do [ -n "$r" ] && nomi+=("$r"); done < <(progetto elenco ${2:-})
  if [ ${#nomi[@]} -eq 0 ]; then
    return 2
  fi
  nome=$(scegli_dalla_lista "$1" "${nomi[@]}") || return 1
  msg=$(progetto seleziona "$nome" 2>&1 >/dev/null) || errore "$msg"
  return 0
}
