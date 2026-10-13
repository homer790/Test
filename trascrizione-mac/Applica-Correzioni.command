#!/bin/bash
# Applica-Correzioni.command — da aprire con doppio clic dopo aver corretto A MANO il file di controllo
# (in alternativa alla schermata di controllo, che applica le correzioni da sola quando salvi).
#
# 1. Chiede il file di controllo corretto a mano (NOME_controllo.txt).
# 2. Crea NOME_trascrizione_corretta.txt con le tue correzioni.
# 3. Impara correzioni e conferme: le aggiunge al dizionario personale usato dalle
#    trascrizioni future (le parole verificate non verranno più segnate) e salva i
#    ritagli audio corretti come esempi.
# 4. Avvisa con un popup e apre la trascrizione corretta.
#
# Si può rilanciare quante volte si vuole: riparte sempre dalla trascrizione originale.

set -u

# Cartella del programma (anche se lanciato dal collegamento sulla Scrivania)
QUI="$0"
while [ -L "$QUI" ]; do
  L=$(readlink "$QUI"); case "$L" in /*) QUI="$L" ;; *) QUI="$(dirname "$QUI")/$L" ;; esac
done
QUI=$(cd "$(dirname "$QUI")" && pwd)

SUPPORTO="$HOME/Library/Application Support/TrascriviAudio"
VENV="$SUPPORTO/venv"
TITOLO="Applica correzioni"
export DIZIONARIO="$SUPPORTO/dizionario.txt"
export ESEMPI="$SUPPORTO/esempi"

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

errore() {
  avviso "$1" stop
  echo "ERRORE: $1"
  exit 1
}

CONTROLLO=$(osascript -e 'POSIX path of (choose file with prompt "Scegli il file di controllo che hai corretto (finisce con _controllo.txt):")' 2>/dev/null) \
  || { echo "Nessun file scelto."; exit 0; }

case "$(basename "$CONTROLLO")" in
  *_controllo*.txt) ;;
  *) errore "Il file scelto non è un file di controllo (il nome deve contenere «_controllo» e finire con .txt)." ;;
esac
CORRETTA="$(dirname "$CONTROLLO")/$(basename "$CONTROLLO" .txt | sed 's/_controllo/_trascrizione_corretta/').txt"

PYTHON="$VENV/bin/python"
[ -x "$PYTHON" ] || PYTHON=$(command -v python3) || errore "Python non trovato. Esegui prima Trascrivi-Audio.command."

RIEPILOGO=$("$PYTHON" "$QUI/applica_correzioni.py" "$CONTROLLO") \
  || errore "Non sono riuscito ad applicare le correzioni. Guarda la finestra del Terminale."

IFS='|' read -r CORRETTE CONFERMATE RIMASTE NUOVE MANCANTI <<< "$RIEPILOGO"
MESSAGGIO="Correzioni applicate.

Parole corrette: $CORRETTE
Parole confermate: $CONFERMATE
Ancora da verificare (con asterisco): $RIMASTE
Nuove voci nel dizionario (correzioni e conferme): $NUOVE"
[ -n "$MANCANTI" ] && MESSAGGIO="$MESSAGGIO

Attenzione: non trovo le righe PAROLA $MANCANTI (cancellate per sbaglio?). Restano da verificare."
avviso "$MESSAGGIO

Ora si aprirà la trascrizione corretta:
$(basename "$CORRETTA")"
open "$CORRETTA"
echo "Fatto. Puoi chiudere questa finestra."
