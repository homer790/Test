#!/bin/bash
# Applica-Correzioni.command — alternativa alla schermata di controllo, per chi corregge A MANO
# il file delle parole dubbie di un progetto (righe «PAROLA 001: ...», togliendo gli asterischi).
#
# 1. Mostra la lista dei progetti già trascritti e lavora solo sui file di quello scelto.
# 2. Crea la trascrizione corretta del progetto.
# 3. Impara correzioni e conferme (dizionario personale) e salva i ritagli corretti come esempi.
# 4. Avvisa con un popup e apre la trascrizione corretta.
# Si può rilanciare quante volte si vuole: riparte sempre dalla trascrizione originale.

set -u

# Cartella del programma (anche se lanciato da un collegamento)
QUI="$0"
while [ -L "$QUI" ]; do
  L=$(readlink "$QUI"); case "$L" in /*) QUI="$L" ;; *) QUI="$(dirname "$QUI")/$L" ;; esac
done
QUI=$(cd "$(dirname "$QUI")" && pwd)
TITOLO="Applica correzioni"
. "$QUI/comune.sh"

trap 'progetto chiudi >/dev/null 2>&1' EXIT   # il file del progetto in corso è temporaneo
seleziona_progetto "Scegli il progetto di cui applicare le correzioni:" --trascritti
case $? in
  1) echo "Annullato."; exit 0 ;;
  2) errore "Non ci sono ancora progetti trascritti." ;;
esac

CONTROLLO=$(progetto campo controllo)
CORRETTA=$(progetto campo trascrizione_corretta)
[ -f "$CONTROLLO" ] || errore "Il progetto non ha ancora parole da controllare."
PYTHON=$(python_programma) || errore "Python non trovato. Esegui prima Trascrivi Audio."

RIEPILOGO=$("$PYTHON" "$QUI/applica_correzioni.py" "$CONTROLLO") \
  || errore "Non sono riuscito ad applicare le correzioni."

IFS='|' read -r CORRETTE CONFERMATE RIMASTE NUOVE MANCANTI <<< "$RIEPILOGO"
MESSAGGIO="Correzioni applicate al progetto «$(progetto campo nome)».

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
