#!/bin/bash
# Prova completa della gestione a progetti, simulando le finestre del Mac (test/finto-mac.sh).
# uso: test/prova-progetti.sh file_audio
# Usa modelli piccoli (base, tiny), una HOME e una cartella progetti temporanee.
# Alla fine stampa «TUTTE LE VERIFICHE SUPERATE» oppure l'elenco delle verifiche fallite.

set -u
QUI=$(cd "$(dirname "$0")/.." && pwd)
AUDIO=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
PROVA=$(mktemp -d)
. "$QUI/test/finto-mac.sh" "$PROVA"
export HOME="$PROVA/home" CARTELLA_PROGETTI="$PROVA/Progetti" SALTA_SCHERMATA=1
export MODELLO_A="${MODELLO_A:-base}" MODELLO_B="${MODELLO_B:-tiny}" MODELLO_C="${MODELLO_C:-tiny}"
mkdir -p "$HOME"
GENERALE="$CARTELLA_PROGETTI/elenco-progetti.json"
IN_CORSO="$CARTELLA_PROGETTI/progetto-in-corso.json"
FALLITE=0

esegui() {  # esegui "descrizione" comando [argomenti]; l'output va in $PROVA/ultimo.log
  echo; echo "################ $1 ################" | tee -a "$LOG"
  shift
  "$@" > "$PROVA/ultimo.log" 2>&1; ESITO=$?
  echo "esito: $ESITO"; grep -E "Progetto|SCHERMATA|ERRORE|Annullato|Parole da riverificare" "$PROVA/ultimo.log" | sed 's/^/   /'
}
verifica() {  # verifica "descrizione" condizione...
  local d="$1"; shift
  if "$@"; then echo "   OK  $d"; else echo "   NO  $d"; FALLITE=$((FALLITE + 1)); fi
}
json() { python3 -c "import json,sys; d=json.load(open('$GENERALE')); print(eval(sys.argv[1]))" "$1"; }
non_esiste() { [ ! -e "$1" ]; }
contiene() { grep -q -- "$2" "$1"; }

# 1. Prima esecuzione: installa Whisper; «Apri un progetto» senza progetti → nuovo progetto
risposte "Installa" "Apri un progetto" "Intervista Rossi" "$AUDIO"
esegui "1. Prima esecuzione, nessun progetto" "$QUI/Trascrivi-Audio.command"
P0="$CARTELLA_PROGETTI/000_IntervistaRossi"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "avviso «non ci sono ancora progetti»" contiene "$LOG" "Non ci sono ancora progetti"
verifica "file generale creato" [ -f "$GENERALE" ]
verifica "progetto 000 nel file generale" [ "$(json "d['progetti'][0]['numero'] + ' ' + d['progetti'][0]['nome']")" = "000 Intervista Rossi" ]
verifica "cartella 000_IntervistaRossi" [ -d "$P0" ]
for f in audio.mp3 trascrizione.txt controllo.txt dati.json clip; do
  verifica "file del progetto: 000_IntervistaRossi_$f" [ -e "$P0/000_IntervistaRossi_$f" ]
done
verifica "il file generale elenca i file" [ "$(json "d['progetti'][0]['file']['controllo']")" = "000_IntervistaRossi_controllo.txt" ]
verifica "audio originale registrato" [ "$(json "d['progetti'][0]['audio_originale']")" = "$AUDIO" ]
verifica "stato «trascritto»" [ "$(json "d['progetti'][0]['stato']")" = "trascritto" ]
verifica "schermata aperta sul progetto 000" contiene "$PROVA/ultimo.log" "SCHERMATA (test): $P0/000_IntervistaRossi_controllo.txt"
verifica "file temporaneo cancellato alla fine" non_esiste "$IN_CORSO"

# 2. Nuovo progetto con nome già usato, poi un nome con spazi e caratteri speciali
risposte "Nuovo progetto" "intervista rossi" "Seconda prova: n.2!" "$AUDIO"
esegui "2. Nuovo progetto (nome duplicato, poi valido)" "$QUI/Trascrivi-Audio.command"
P1="$CARTELLA_PROGETTI/001_Secondaprovan2"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "nome duplicato rifiutato" contiene "$LOG" "Esiste già un progetto chiamato"
verifica "cartella 001_Secondaprovan2 (senza spazi)" [ -d "$P1" ]
verifica "due progetti nel file generale" [ "$(json "len(d['progetti'])")" = 2 ]
verifica "Whisper non richiesto una seconda volta" [ "$(grep -c "installare Whisper" "$LOG")" = 1 ]

# 3. Apri un progetto → Analisi delle parole
risposte "Apri un progetto" "Intervista Rossi" "Analisi delle parole"
esegui "3. Apri progetto → analisi parole" "$QUI/Trascrivi-Audio.command"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "la lista mostra solo i nomi" contiene "$LOG" "Scegli il progetto da aprire: | Intervista Rossi | Seconda prova: n.2!"
verifica "schermata sul progetto 000" contiene "$PROVA/ultimo.log" "SCHERMATA (test): $P0/000_IntervistaRossi_controllo.txt"
verifica "file temporaneo cancellato" non_esiste "$IN_CORSO"

# 4. Correzione a mano + Applica-Correzioni solo sul progetto 001
sed -i.bak -E 's/^PAROLA 001: .*/PAROLA 001: CORRETTA/' "$P1/001_Secondaprovan2_controllo.txt"; rm -f "$P1"/*.bak
P0_PRIMA=$(ls -la "$P0" | md5sum)
risposte "Seconda prova: n.2!"
esegui "4. Applica-Correzioni sul progetto 001" "$QUI/Applica-Correzioni.command"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "trascrizione corretta nel progetto 001" contiene "$P1/001_Secondaprovan2_trascrizione_corretta.txt" "CORRETTA"
verifica "progetto 000 non toccato" [ "$(ls -la "$P0" | md5sum)" = "$P0_PRIMA" ]
verifica "file temporaneo cancellato" non_esiste "$IN_CORSO"

# 5. Apri un progetto → Rielabora la trascrizione (conferma)
risposte "Apri un progetto" "Seconda prova: n.2!" "Rielabora la trascrizione" "Rielabora"
esegui "5. Rielabora la trascrizione del progetto 001" "$QUI/Trascrivi-Audio.command"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "audio non richiesto di nuovo" [ "$(grep -c "sorgente del progetto" "$LOG")" = 2 ]
verifica "trascrizione rifatta (correzioni del progetto azzerate)" non_esiste "$P1/001_Secondaprovan2_trascrizione_corretta.txt"
verifica "file di controllo rigenerato" [ -f "$P1/001_Secondaprovan2_controllo.txt" ]
verifica "correzione imparata nel dizionario" contiene "$HOME/Library/Application Support/TrascriviAudio/dizionario.txt" "→ CORRETTA"

# 6. Rielabora → Annulla alla conferma: nulla cambia
P1_PRIMA=$(ls -la "$P1" | md5sum)
risposte "Apri un progetto" "Seconda prova: n.2!" "Rielabora la trascrizione" "ANNULLA"
esegui "6. Rielabora annullato" "$QUI/Trascrivi-Audio.command"
verifica "esito 0 e «Annullato»" contiene "$PROVA/ultimo.log" "Annullato"
verifica "progetto 001 non toccato" [ "$(ls -la "$P1" | md5sum)" = "$P1_PRIMA" ]

# 7. Annulla alla prima domanda, e Annulla nella lista dei progetti
risposte "ANNULLA"
esegui "7a. Annulla alla prima domanda" "$QUI/Trascrivi-Audio.command"
verifica "esito 0" [ "$ESITO" = 0 ]
risposte "Apri un progetto" "ANNULLA"
esegui "7b. Annulla nella lista dei progetti" "$QUI/Trascrivi-Audio.command"
verifica "esito 0" [ "$ESITO" = 0 ]
verifica "file temporaneo cancellato" non_esiste "$IN_CORSO"
verifica "ancora due progetti" [ "$(json "len(d['progetti'])")" = 2 ]

# 8. Controlla-Parole lanciato da solo: lista dei progetti trascritti
risposte "Intervista Rossi"
esegui "8. Controlla-Parole da solo" "$QUI/Controlla-Parole.command"
verifica "schermata sul progetto 000" contiene "$PROVA/ultimo.log" "SCHERMATA (test): $P0/000_IntervistaRossi_controllo.txt"
verifica "file temporaneo cancellato" non_esiste "$IN_CORSO"

# 9. Nuovo progetto annullato alla scelta dell'audio, poi riaperto: chiede l'audio e trascrive
risposte "Nuovo progetto" "Terzo" "ANNULLA"
esegui "9a. Nuovo progetto senza audio" "$QUI/Trascrivi-Audio.command"
verifica "progetto 002 creato con stato «nuovo»" [ "$(json "[p['stato'] for p in d['progetti'] if p['numero']=='002'][0]")" = "nuovo" ]
risposte "Apri un progetto" "Terzo" "$AUDIO"
esegui "9b. Riapertura: chiede l'audio e trascrive" "$QUI/Trascrivi-Audio.command"
verifica "avviso «trascrizione non completa»" contiene "$LOG" "non ha ancora una trascrizione completa"
verifica "progetto 002 trascritto" [ "$(json "[p['stato'] for p in d['progetti'] if p['numero']=='002'][0]")" = "trascritto" ]

echo; echo "======== File generale dei progetti ========"; cat "$GENERALE"
echo; echo "======== Cartella dei progetti ========"; (cd "$CARTELLA_PROGETTI" && find . -maxdepth 2 | sort | grep -v '_clip/')
echo; echo "======== Finestre mostrate ========"; cat "$LOG"
echo
if [ "$FALLITE" = 0 ]; then echo "TUTTE LE VERIFICHE SUPERATE"; else echo "VERIFICHE FALLITE: $FALLITE"; fi
echo "(file di prova in $PROVA)"
[ "$FALLITE" = 0 ]
