#!/bin/bash
# Controlla-Parole.command — apre la schermata di controllo delle parole dubbie.
#
# Si usa per riprendere il lavoro in un secondo momento: chiede il file di controllo
# (NOME_controllo.txt) e apre nel browser la schermata, che funziona solo su questo computer.
# Trascrivi-Audio.command la apre da solo a fine trascrizione, passando il file come argomento.

set -u

# Cartella del programma (anche se lanciato dal collegamento sulla Scrivania)
QUI="$0"
while [ -L "$QUI" ]; do
  L=$(readlink "$QUI"); case "$L" in /*) QUI="$L" ;; *) QUI="$(dirname "$QUI")/$L" ;; esac
done
QUI=$(cd "$(dirname "$QUI")" && pwd)

SUPPORTO="$HOME/Library/Application Support/TrascriviAudio"
VENV="$SUPPORTO/venv"
TITOLO="Controlla parole"
export DIZIONARIO="$SUPPORTO/dizionario.txt"
export ESEMPI="$SUPPORTO/esempi"

errore() {
  osascript - "$1" "$TITOLO" >/dev/null 2>&1 <<'OSA'
on run argv
  display dialog (item 1 of argv) buttons {"OK"} default button "OK" with title (item 2 of argv) with icon stop
end run
OSA
  echo "ERRORE: $1"
  exit 1
}

CONTROLLO="${1:-}"
if [ -z "$CONTROLLO" ]; then
  CONTROLLO=$(osascript -e 'POSIX path of (choose file with prompt "Scegli il file di controllo da riprendere (finisce con _controllo.txt):")' 2>/dev/null) \
    || { echo "Nessun file scelto."; exit 0; }
fi
case "$(basename "$CONTROLLO")" in
  *_controllo*.txt) ;;
  *) errore "Il file scelto non è un file di controllo (il nome deve contenere «_controllo» e finire con .txt)." ;;
esac
[ -f "$CONTROLLO" ] || errore "Non trovo il file $CONTROLLO."

PYTHON="$VENV/bin/python"
[ -x "$PYTHON" ] || PYTHON=$(command -v python3) || errore "Python non trovato. Esegui prima Trascrivi-Audio.command."

echo "Apro la schermata di controllo nel browser..."
echo "Lascia aperta questa finestra finché lavori; si chiude da sola quando premi «Chiudi» nella pagina."
"$PYTHON" "$QUI/schermata_controllo.py" "$CONTROLLO" || errore "La schermata di controllo si è chiusa con un errore. Guarda la finestra del Terminale."
