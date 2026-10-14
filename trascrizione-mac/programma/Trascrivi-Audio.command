#!/bin/bash
# Trascrivi-Audio.command — il programma di Trascrivi Audio.
#
# Lo apre nel Terminale l'app «Trascrivi Audio» (icona sulla Scrivania o in Applicazioni):
# la finestra del Terminale mostra l'avanzamento delle operazioni.
#
# 1. Prepara tutto SENZA CHIEDERE, solo se manca qualcosa:
#    - Python: usa quello del Mac (3.10 o successivo) o scarica un Python portatile,
#      senza password, nella cartella dei dati del programma;
#    - Whisper (faster-whisper) e i modelli large-v3 e medium (circa 4,5 GB).
#    Alla prima installazione e dopo un aggiornamento crea anche l'icona sulla Scrivania
#    e ripulisce le versioni precedenti del programma.
# 2. Menu principale: Nuovo progetto, Apri un progetto, Guida rapida,
#    Disinstalla Trascrivi Audio (si torna al menu dopo ogni operazione; «Esci» chiude).
#    - Nuovo progetto: nome → numero 000-999 e cartella «NNN_NomeSenzaSpazi» in
#      Documenti/Trascrivi Audio/Progetti → audio sorgente, copiato nel progetto → trascrizione.
#    - Apri un progetto: lista dei progetti → «Analisi delle parole» (schermata di controllo)
#      oppure «Rielabora la trascrizione».
# 3. Trascrizione: large-v3 e medium sull'intero audio, poi riascolto delle sole frasi dubbie
#    (se il riascolto di large coincide con medium il dubbio è risolto, altrimenti un ascolto
#    in più con medium deve confermarlo); ritagli audio di ±3 s per le parole ancora dubbie.
# 4. Schermata di controllo nel browser (solo su questo computer).
#
# L'audio non viene mai inviato online: da internet si scaricano solo Python (se manca),
# Whisper e i modelli, una volta sola.

set -u

QUI=$(cd "$(dirname "$0")" && pwd -P)
TITOLO="Trascrivi Audio"
. "$QUI/comune.sh"

# Il pacchetto dell'app che contiene questo programma (vuoto se eseguito fuori dall'app)
APP=""
case "$QUI" in
  *.app/Contents/Resources/programma) APP=$(cd "$QUI/../../.." && pwd -P) ;;
esac
GUIDA="$QUI/../Guida rapida.pdf"
SCRIVANIA="$HOME/Desktop"
COLLEGAMENTO="$SCRIVANIA/Trascrivi Audio"
MARCATORE="$SUPPORTO/installazione-da-completare"   # scritto dall'app quando si installa o si aggiorna

# Impostazioni modificabili (anche da Terminale, es. SOGLIA=0.7)
export MODELLO_A="${MODELLO_A:-large-v3}"   # trascrizione principale
export MODELLO_B="${MODELLO_B:-medium}"     # trascrizione di confronto
export MODELLO_C="${MODELLO_C:-medium}"     # terzo ascolto delle frasi ancora dubbie
export SOGLIA="${SOGLIA:-0.6}"              # sotto questa sicurezza la parola è dubbia
export LINGUA="${LINGUA:-it}"
export RIASCOLTO="${RIASCOLTO:-1}"          # 0 = non riascoltare le frasi dubbie
export CARTELLA_MODELLI="$SUPPORTO/modelli"

# Python portatile (python-build-standalone), scaricato solo se sul Mac non c'è un Python adatto
PYTHON_PORTATILE="$SUPPORTO/python"
PYTHON_RILASCIO="20261013"
PYTHON_VERSIONE="3.12.15"

# ============================================================================================
# 1. Preparazione (senza domande)
# ============================================================================================

trova_python() {
  # PYTHON_CANDIDATI permette ai test di simulare un Mac senza Python
  for p in "$PYTHON_PORTATILE/bin/python3" ${PYTHON_CANDIDATI-/opt/homebrew/bin/python3 /usr/local/bin/python3 \
           /Library/Frameworks/Python.framework/Versions/Current/bin/python3 /usr/bin/python3}; do
    # /usr/bin/python3 esiste anche senza Command Line Tools ma non funziona: controlliamo prima.
    if [ "$p" = /usr/bin/python3 ] && [ "$(uname)" = Darwin ] && ! xcode-select -p >/dev/null 2>&1; then
      continue
    fi
    if [ -x "$p" ] && "$p" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

installa_python_portatile() {
  local arch sha url tmp
  case "$(uname -m)" in
    arm64|aarch64) arch=aarch64; sha=ba32036ad8f4c434d97a1ee7feef8b7edc0fac16777639b97e39c74a108e4440 ;;
    x86_64)        arch=x86_64;  sha=9686ddd8639b855905447ea4a16eb54a804a9ef12afbe7c9ecb1412d9c1fbc98 ;;
    *) errore "Processore non riconosciuto ($(uname -m)): non posso installare Python." ;;
  esac
  url="https://github.com/astral-sh/python-build-standalone/releases/download/$PYTHON_RILASCIO/cpython-$PYTHON_VERSIONE%2B$PYTHON_RILASCIO-$arch-apple-darwin-install_only.tar.gz"
  url="${PYTHON_PORTATILE_URL:-$url}"; sha="${PYTHON_PORTATILE_SHA256:-$sha}"   # i test usano un file locale
  tmp=$(mktemp -d)
  echo "Scarico Python $PYTHON_VERSIONE portatile (circa 24 MB)..."
  curl -fL --progress-bar -o "$tmp/python.tar.gz" "$url" \
    || errore "Download di Python non riuscito. Controlla la connessione a internet e riapri Trascrivi Audio."
  # Il file deve essere identico a quello pubblicato (impronta SHA-256 fissata qui)
  [ "$(shasum -a 256 "$tmp/python.tar.gz" | cut -d' ' -f1)" = "$sha" ] \
    || errore "Il file di Python scaricato non è integro: installazione interrotta per sicurezza."
  rm -rf "$PYTHON_PORTATILE"
  tar -xzf "$tmp/python.tar.gz" -C "$SUPPORTO" || errore "Estrazione di Python non riuscita."
  rm -rf "$tmp"
  "$PYTHON_PORTATILE/bin/python3" -c 'import ssl, venv' || errore "Python portatile installato ma non si avvia."
  echo "Python portatile installato."
}

whisper_installato() {
  [ -x "$VENV/bin/python" ] && "$VENV/bin/python" -c 'import faster_whisper' 2>/dev/null
}

modelli_mancanti() {  # stampa i modelli non ancora scaricati, uno per riga
  "$VENV/bin/python" - "$CARTELLA_MODELLI" "$@" 2>/dev/null <<'EOF'
import sys
from faster_whisper import download_model
for nome in dict.fromkeys(sys.argv[2:]):
    try:
        download_model(nome, cache_dir=sys.argv[1], local_files_only=True)
    except Exception:
        print(nome)
EOF
}

scarica_modello() {
  "$VENV/bin/python" - "$1" "$CARTELLA_MODELLI" <<'EOF'
import sys
from faster_whisper import download_model
download_model(sys.argv[1], cache_dir=sys.argv[2])
EOF
}

prepara() {
  local python m
  mkdir -p "$SUPPORTO" "$CARTELLA_PROGETTI" || errore "Non riesco a creare le cartelle del programma."

  if ! whisper_installato; then
    python=$(trova_python)
    if [ -z "$python" ]; then
      installa_python_portatile
      python="$PYTHON_PORTATILE/bin/python3"
    fi
    echo "Python: $python"
    echo "Installo Whisper (circa 300 MB, alcuni minuti)..."
    rm -rf "$VENV"  # un'installazione precedente non riuscita va rifatta da capo
    "$python" -m venv "$VENV" || errore "Impossibile creare l'ambiente di Whisper."
    "$VENV/bin/python" -m pip install --upgrade pip || errore "Installazione di Whisper non riuscita (controlla la connessione a internet)."
    # av<19: PyAV 19 ha tolto un'opzione usata da faster-whisper 1.2 (errore «metadata_errors»)
    "$VENV/bin/python" -m pip install faster-whisper "av<19" \
      || errore "Installazione di Whisper non riuscita (controlla la connessione a internet)."
    whisper_installato || errore "Whisper risulta installato ma non si avvia."
    echo "Whisper installato."
  fi

  for m in $(modelli_mancanti "$MODELLO_A" "$MODELLO_B" "$MODELLO_C"); do
    echo "Scarico il modello $m (una volta sola, può volerci un po')..."
    scarica_modello "$m" || errore "Download del modello $m non riuscito (controlla la connessione a internet)."
  done
}

pulisci_versioni_precedenti() {
  local vecchio cartella c f
  # Le versioni precedenti si installavano in una cartella scelta, con un collegamento sulla
  # Scrivania al file Trascrivi-Audio.command: togliamo i loro file del programma e portiamo
  # i loro progetti nella nuova posizione (Documenti/Trascrivi Audio/Progetti).
  vecchio=$(readlink "$COLLEGAMENTO" 2>/dev/null)
  case "$vecchio" in
    */Trascrivi-Audio.command) cartella=$(dirname "$vecchio") ;;
    *) cartella="" ;;
  esac
  for c in "$cartella" "$CARTELLA_DOCUMENTI"; do
    if [ -n "$c" ] && [ -f "$c/comune.sh" ] && [ -f "$c/versione.txt" ]; then
      for f in Trascrivi-Audio.command Controlla-Parole.command Applica-Correzioni.command comune.sh \
               progetti.py schermata_controllo.py applica_correzioni.py versione.txt \
               "Guida rapida.md" "Istruzioni complete.txt"; do
        rm -f "$c/$f"
      done
      rm -rf "$c/__pycache__"
      if [ -d "$c/Progetti" ] && [ "$c/Progetti" != "$CARTELLA_PROGETTI" ]; then
        progetto migra "$c/Progetti" || echo "Attenzione: i progetti precedenti sono rimasti in $c/Progetti"
      fi
    fi
  done
  rm -f "$SCRIVANIA/Controlla Parole" "$SCRIVANIA/Applica Correzioni"
}

completa_installazione() {
  local tipo
  if [ -f "$MARCATORE" ]; then tipo=$(cat "$MARCATORE"); else tipo=""; fi
  [ -n "$tipo" ] || return 0
  pulisci_versioni_precedenti
  if [ -n "$APP" ]; then
    if [ -L "$COLLEGAMENTO" ] || [ ! -e "$COLLEGAMENTO" ]; then
      mkdir -p "$SCRIVANIA"
      ln -sfn "$APP" "$COLLEGAMENTO" || echo "Attenzione: non sono riuscito a creare l'icona sulla Scrivania."
    fi
  fi
  [ -f "$GUIDA" ] && cp -f "$GUIDA" "$CARTELLA_DOCUMENTI/Guida rapida.pdf"
  rm -f "$MARCATORE"
  if [ "$tipo" = "aggiornamento" ]; then
    avviso "Aggiornamento completato.

I tuoi progetti sono rimasti dove erano:
Documenti › Trascrivi Audio › Progetti"
  else
    avviso "Installazione completata.

• Sulla Scrivania trovi l'icona «Trascrivi Audio»: aprila ogni volta che vuoi usare il programma.
• I progetti verranno salvati in Documenti › Trascrivi Audio › Progetti.
• La guida è in Documenti › Trascrivi Audio › Guida rapida.pdf.

Ora si apre il menu principale."
  fi
}

# ============================================================================================
# 2. Progetti
# ============================================================================================

scegli_audio() {  # chiede l'audio sorgente e lo copia nel progetto in corso; 1 se Annulla
  local sorgente msg
  sorgente=$(osascript -e 'POSIX path of (choose file with prompt "Scegli il file audio (o video) da trascrivere:")' 2>/dev/null) \
    || return 1
  echo "Copio l'audio nel progetto..."
  msg=$(progetto imposta-audio "$sorgente" 2>&1 >/dev/null) || errore "$msg"
}

nuovo_progetto() {
  local messaggio nome errore_crea
  messaggio="Scrivi il nome del nuovo progetto:"
  while :; do
    nome=$(chiedi_testo "$messaggio") || return 0
    errore_crea=$(progetto crea "$nome" 2>&1 >/dev/null) && break
    messaggio="$errore_crea

Scrivi il nome del nuovo progetto:"
  done
  scegli_audio || return 0
  trascrivi_progetto
}

apri_progetto() {
  local nome cosa audio
  seleziona_progetto "Scegli il progetto da aprire:"
  case $? in
    1) return 0 ;;
    2) avviso "Non ci sono ancora progetti: ne creiamo uno nuovo."
       nuovo_progetto
       return 0 ;;
  esac
  nome=$(progetto campo nome)
  if [ "$(progetto campo stato)" = "trascritto" ]; then
    cosa=$(scelta "Progetto «$nome»: cosa vuoi fare?" "Annulla" "Rielabora la trascrizione" "Analisi delle parole") \
      || return 0
    if [ "$cosa" = "Analisi delle parole" ]; then
      analisi_parole
      return 0
    fi
    domanda "Rielaborare la trascrizione del progetto «$nome»?

La trascrizione e le parole da controllare verranno rifatte da capo: le correzioni fatte in questo progetto andranno perse (il tuo dizionario personale resta e verrà usato)." "Rielabora" \
      || return 0
  else
    avviso "Il progetto «$nome» non ha ancora una trascrizione completa: la avvio ora."
  fi
  audio=$(progetto campo audio)
  if [ -z "$audio" ] || [ ! -f "$audio" ]; then
    scegli_audio || return 0
  fi
  trascrivi_progetto
}

trascrivi_progetto() {
  local nome audio trascrizione corretta controllo dati clip quante
  nome=$(progetto campo nome)
  audio=$(progetto campo audio)
  trascrizione=$(progetto campo trascrizione)
  corretta=$(progetto campo trascrizione_corretta)
  controllo=$(progetto campo controllo)
  dati=$(progetto campo dati)
  clip=$(progetto campo clip)
  # Una nuova trascrizione sostituisce i risultati precedenti del progetto
  rm -rf "$clip" "$controllo" "$dati" "$corretta" "$trascrizione"
  progetto stato "in trascrizione"
  echo
  echo "Progetto:     $(progetto campo numero) – $nome"
  echo "Cartella:     $(progetto campo cartella)"
  echo "Audio:        $(basename "$audio")"
  echo "Non chiudere questa finestra: qui vedi l'avanzamento della trascrizione."

  "$VENV/bin/python" "$QUI/trascrivi_dubbi.py" "$audio" "$trascrizione" "$controllo" "$dati" "$clip" \
    || errore "La trascrizione non è riuscita."
  progetto stato trascritto

  quante=$(grep -m1 '^Parole da riverificare:' "$controllo" | sed 's/^Parole da riverificare: //')
  if [ "${quante%% *}" = "0" ]; then
    avviso "Trascrizione del progetto «$nome» completata.

Non ci sono parole da riverificare: ora si apre la trascrizione."
    open "$trascrizione"
    return 0
  fi
  avviso "Trascrizione del progetto «$nome» completata.

Parole da riverificare: $quante
$(grep -m1 '^(prima del riascolto' "$controllo")

Ora si apre nel browser la schermata di controllo delle parole: ascolta ogni ritaglio, correggi la parola e spunta «Confermata», poi premi «Salva»."
  analisi_parole
}

analisi_parole() {
  local controllo
  controllo=$(progetto campo controllo)
  [ -f "$controllo" ] || errore "Il progetto «$(progetto campo nome)» non ha ancora parole da controllare: rielabora prima la trascrizione."
  echo
  echo "Progetto: $(progetto campo numero) – $(progetto campo nome)"
  if [ -n "${SALTA_SCHERMATA:-}" ]; then  # usato solo dai test automatici
    echo "SCHERMATA (test): $controllo"
    return 0
  fi
  echo "Apro la schermata di controllo nel browser."
  echo "Quando hai finito premi «Chiudi» nella pagina: tornerai al menu principale."
  "$VENV/bin/python" "$QUI/schermata_controllo.py" "$controllo" \
    || errore "La schermata di controllo si è chiusa con un errore."
}

# ============================================================================================
# 3. Disinstallazione
# ============================================================================================

rimuovi_app() {
  [ -n "$APP" ] && [ -d "$APP" ] || return 0
  case "$APP" in *.app) ;; *) return 0 ;; esac
  rm -rf "$APP" 2>/dev/null && return 0
  # Cartella Applicazioni non scrivibile: chiede la password a macOS
  osascript - "$APP" >/dev/null 2>&1 <<'EOF'
on run argv
  do shell script "/bin/rm -rf " & quoted form of (item 1 of argv) with administrator privileges
end run
EOF
}

disinstalla() {
  local risposta
  risposta=$(scelta "Vuoi disinstallare Trascrivi Audio?

Verranno cancellati il programma, l'icona sulla Scrivania, Whisper con i modelli (circa 5 GB) e il dizionario delle tue correzioni.

I progetti (audio e trascrizioni) sono in Documenti › Trascrivi Audio: puoi conservarli o cancellarli." \
    "Annulla" "Cancella anche i progetti" "Conserva i progetti") || return 0
  if [ "$risposta" = "Cancella anche i progetti" ]; then
    domanda "Sei sicuro? Tutti i progetti, con audio e trascrizioni, verranno cancellati definitivamente." \
      "Cancella tutto" || return 0
  fi
  echo "Disinstallo Trascrivi Audio..."
  progetto chiudi >/dev/null 2>&1
  trap - EXIT
  [ -L "$COLLEGAMENTO" ] && rm -f "$COLLEGAMENTO"
  case "$SUPPORTO" in */TrascriviAudio) rm -rf "$SUPPORTO" ;; esac
  if [ "$risposta" = "Cancella anche i progetti" ]; then
    case "$CARTELLA_DOCUMENTI" in */"Trascrivi Audio") rm -rf "$CARTELLA_DOCUMENTI" ;; esac
  else
    rm -f "$CARTELLA_DOCUMENTI/Guida rapida.pdf"
  fi
  rimuovi_app
  if [ "$risposta" = "Cancella anche i progetti" ]; then
    avviso "Trascrivi Audio è stato disinstallato, insieme ai progetti."
  else
    avviso "Trascrivi Audio è stato disinstallato.

I progetti sono stati conservati in Documenti › Trascrivi Audio › Progetti."
  fi
  echo "Disinstallazione completata. Puoi chiudere questa finestra."
  exit 0
}

# ============================================================================================
# Avvio
# ============================================================================================

echo "Trascrivi Audio $(cat "$QUI/../versione.txt" 2>/dev/null)"
echo "Questa finestra mostra l'avanzamento: lasciala aperta mentre usi il programma."
trap 'progetto chiudi >/dev/null 2>&1' EXIT   # il file del progetto in corso è temporaneo
mkdir -p "$SUPPORTO" || errore "Non riesco a creare la cartella dei dati del programma."
[ -d "$VENV" ] || [ -f "$MARCATORE" ] || echo "installazione" > "$MARCATORE"   # app copiata a mano
prepara
completa_installazione

while :; do
  SCELTA=$(menu_principale) || break
  case "$SCELTA" in
    "Nuovo progetto") nuovo_progetto ;;
    "Apri un progetto") apri_progetto ;;
    "Guida rapida") open "$GUIDA" ;;
    "Disinstalla Trascrivi Audio") disinstalla ;;
  esac
  progetto chiudi >/dev/null 2>&1
done
echo "Arrivederci. Puoi chiudere questa finestra."
