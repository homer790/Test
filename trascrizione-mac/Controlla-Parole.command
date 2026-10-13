#!/bin/bash
# Controlla-Parole.command — apre la schermata di controllo delle parole dubbie di un progetto.
#
# - Con «--progetto-in-corso» (come lo lancia Trascrivi-Audio) usa il progetto in corso.
# - Lanciato da solo, mostra la lista dei progetti già trascritti e apre quello scelto.
# La schermata si apre nel browser ma funziona solo su questo computer, e lavora solo
# sui file del progetto.

set -u

# Cartella del programma (anche se lanciato da un collegamento)
QUI="$0"
while [ -L "$QUI" ]; do
  L=$(readlink "$QUI"); case "$L" in /*) QUI="$L" ;; *) QUI="$(dirname "$QUI")/$L" ;; esac
done
QUI=$(cd "$(dirname "$QUI")" && pwd)
TITOLO="Controlla parole"
. "$QUI/comune.sh"

if [ "${1:-}" != "--progetto-in-corso" ]; then
  trap 'progetto chiudi >/dev/null 2>&1' EXIT   # il file del progetto in corso è temporaneo
  seleziona_progetto "Scegli il progetto di cui controllare le parole:" --trascritti
  case $? in
    1) echo "Annullato."; exit 0 ;;
    2) errore "Non ci sono ancora progetti trascritti." ;;
  esac
fi

CONTROLLO=$(progetto campo controllo 2>/dev/null) || errore "Nessun progetto in corso."
[ -f "$CONTROLLO" ] || errore "Il progetto «$(progetto campo nome)» non ha ancora parole da controllare: rielabora prima la trascrizione."

echo "Progetto: $(progetto campo numero) – $(progetto campo nome)"
if [ -n "${SALTA_SCHERMATA:-}" ]; then  # usato solo dai test automatici
  echo "SCHERMATA (test): $CONTROLLO"
  exit 0
fi
echo "Apro la schermata di controllo nel browser..."
echo "Lascia aperta questa finestra finché lavori; si chiude da sola quando premi «Chiudi» nella pagina."
"$(python_programma)" "$QUI/schermata_controllo.py" "$CONTROLLO" \
  || errore "La schermata di controllo si è chiusa con un errore."
