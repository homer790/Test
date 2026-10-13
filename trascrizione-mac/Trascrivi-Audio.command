#!/bin/bash
# Trascrivi-Audio.command — da aprire con doppio clic nel Finder (macOS).
#
# 1. Se manca, chiede il permesso e installa Whisper (faster-whisper) in locale.
# 2. Chiede il file audio e la cartella dove salvare i risultati.
# 3. Trascrive due volte (large-v3 e medium), confronta e segna le parole dubbie.
# 4. Avvisa con un popup e apre il file di controllo.
#
# L'audio non viene mai inviato online: da internet si scaricano solo
# il programma (al primo avvio) e i modelli (al primo utilizzo).

set -u

SUPPORTO="$HOME/Library/Application Support/TrascriviAudio"
VENV="$SUPPORTO/venv"
SCRIPT_PY="$SUPPORTO/trascrivi_dubbi.py"
TITOLO="Trascrizione audio"

# Impostazioni modificabili (anche da Terminale, es. SOGLIA=0.7 ./Trascrivi-Audio.command)
export MODELLO_A="${MODELLO_A:-large-v3}"   # trascrizione principale
export MODELLO_B="${MODELLO_B:-medium}"     # trascrizione di confronto
export SOGLIA="${SOGLIA:-0.6}"              # sotto questa sicurezza la parola è dubbia
export LINGUA="${LINGUA:-it}"
export CARTELLA_MODELLI="$SUPPORTO/modelli"

# --- Finestre di dialogo (testo passato come argomento, così le virgolette non creano problemi)

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

errore() {
  avviso "$1

Dettagli nella finestra del Terminale." stop
  echo
  echo "ERRORE: $1"
  exit 1
}

# --- 1. Python e Whisper

trova_python() {
  for p in /opt/homebrew/bin/python3 /usr/local/bin/python3 \
           /Library/Frameworks/Python.framework/Versions/Current/bin/python3 /usr/bin/python3; do
    # /usr/bin/python3 esiste anche senza Command Line Tools ma non funziona: controlliamo prima.
    if [ "$p" = /usr/bin/python3 ] && [ "$(uname)" = Darwin ] && ! xcode-select -p >/dev/null 2>&1; then
      continue
    fi
    if [ -x "$p" ] && "$p" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

whisper_installato() {
  [ -x "$VENV/bin/python" ] && "$VENV/bin/python" -c 'import faster_whisper' 2>/dev/null
}

if ! whisper_installato; then
  domanda "Per trascrivere serve installare Whisper sul tuo Mac.

• Programma: circa 300 MB, in Libreria/Application Support/TrascriviAudio
• Modelli $MODELLO_A e $MODELLO_B: circa 4,5 GB, scaricati alla prima trascrizione

I tuoi file audio NON verranno mai inviati online.

Vuoi installarlo ora?" "Installa" || { echo "Installazione annullata."; exit 0; }

  PYTHON=$(trova_python)
  if [ -z "$PYTHON" ]; then
    if [ "$(uname)" = Darwin ]; then
      xcode-select --install >/dev/null 2>&1
    fi
    errore "Manca Python 3, necessario per Whisper.

Si è aperta (o si aprirà) la finestra di Apple per installare gli «Strumenti da riga di comando». Completa l'installazione e poi riapri questo file.

In alternativa installa Python da python.org."
  fi

  echo "Installazione di Whisper con $PYTHON ..."
  mkdir -p "$SUPPORTO" || errore "Impossibile creare la cartella $SUPPORTO"
  "$PYTHON" -m venv "$VENV" || errore "Impossibile creare l'ambiente Python."
  "$VENV/bin/python" -m pip install --upgrade pip || errore "Aggiornamento di pip non riuscito (controlla la connessione)."
  # av<19: PyAV 19 ha tolto un'opzione usata da faster-whisper 1.2 (errore «metadata_errors»)
  "$VENV/bin/python" -m pip install faster-whisper "av<19" || errore "Installazione di Whisper non riuscita (controlla la connessione)."
  whisper_installato || errore "Whisper risulta installato ma non si avvia."
  echo "Whisper installato."
fi

# --- 2. File audio e cartella di destinazione

AUDIO=$(osascript -e 'POSIX path of (choose file with prompt "Scegli il file audio (o video) da trascrivere:")' 2>/dev/null) \
  || { echo "Nessun file scelto."; exit 0; }
DESTINAZIONE=$(osascript -e 'POSIX path of (choose folder with prompt "Dove salvo i file di trascrizione?" default location (path to documents folder))' 2>/dev/null) \
  || { echo "Nessuna cartella scelta."; exit 0; }
DESTINAZIONE="${DESTINAZIONE%/}"

NOME=$(basename "$AUDIO")
NOME="${NOME%.*}"
SUFFISSO=""
if [ -e "$DESTINAZIONE/${NOME}_controllo.txt" ] || [ -e "$DESTINAZIONE/${NOME}_trascrizione.txt" ]; then
  SUFFISSO="_$(date +%Y%m%d-%H%M%S)"   # non sovrascrivere risultati precedenti
fi
TRASCRIZIONE="$DESTINAZIONE/${NOME}_trascrizione${SUFFISSO}.txt"
CONTROLLO="$DESTINAZIONE/${NOME}_controllo${SUFFISSO}.txt"

# --- 3. Trascrizione e confronto (script Python scritto ogni volta, così è sempre aggiornato)

mkdir -p "$SUPPORTO" "$CARTELLA_MODELLI"
cat > "$SCRIPT_PY" <<'PYEOF'
import difflib
import os
import re
import sys
import time

from faster_whisper import WhisperModel

audio, file_trascrizione, file_controllo = sys.argv[1:4]
MODELLO_A = os.environ.get("MODELLO_A", "large-v3")
MODELLO_B = os.environ.get("MODELLO_B", "medium")
SOGLIA = float(os.environ.get("SOGLIA", "0.6"))
LINGUA = os.environ.get("LINGUA", "it") or None
CARTELLA_MODELLI = os.environ.get("CARTELLA_MODELLI")


def tempo(secondi):
    s = int(secondi)
    return f"{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d}"


def trascrivi(nome_modello, passaggio):
    print(f"\n[{passaggio}/2] Carico il modello {nome_modello} "
          "(la prima volta viene scaricato, può volerci molto)...", flush=True)
    modello = WhisperModel(nome_modello, device="cpu", compute_type="int8",
                           download_root=CARTELLA_MODELLI)
    segmenti, info = modello.transcribe(audio, language=LINGUA, word_timestamps=True,
                                        beam_size=5, vad_filter=True)
    durata = info.duration or 1
    inizio = time.time()
    risultato = []  # (indice segmento, inizio segmento, parola)
    for n, seg in enumerate(segmenti):
        for w in seg.words or []:
            risultato.append((n, seg.start, w))
        print(f"\r[{passaggio}/2] {nome_modello}: {min(seg.end / durata, 1):6.1%} "
              f"({tempo(seg.end)} di {tempo(durata)})", end="", flush=True)
    print(f"\n[{passaggio}/2] {nome_modello} completato in {tempo(time.time() - inizio)}.", flush=True)
    return risultato


a = trascrivi(MODELLO_A, 1)
b = trascrivi(MODELLO_B, 2)

# Confronto parola per parola tra le due trascrizioni
norm = lambda t: re.sub(r"[^\w']", "", t.lower())
sm = difflib.SequenceMatcher(a=[norm(w.word) for _, _, w in a],
                             b=[norm(w.word) for _, _, w in b], autojunk=False)
alternativa = {}  # indice parola in a -> cosa ha sentito il modello B
for op, i1, i2, j1, j2 in sm.get_opcodes():
    if op in ("replace", "delete"):
        sentito = " ".join(w.word.strip() for _, _, w in b[j1:j2]) or "(niente)"
        for i in range(i1, i2):
            alternativa[i] = sentito

righe, dubbi = [], []
riga, segmento_corrente = [], None
for i, (n, inizio_seg, w) in enumerate(a):
    if n != segmento_corrente:
        if riga:
            righe.append(" ".join(riga))
        riga, segmento_corrente = [f"[{tempo(inizio_seg)}]"], n
    parola = w.word.strip()
    incerta = w.probability < SOGLIA
    diversa = i in alternativa
    if incerta and diversa:
        segnata = f"**{parola}**"
    elif incerta or diversa:
        segnata = f"*{parola}*"
    else:
        segnata = parola
    riga.append(segnata)
    if incerta or diversa:
        nota = f"sicurezza {w.probability:.2f}"
        if diversa:
            nota += f" – {MODELLO_B} ha sentito: «{alternativa[i]}»"
        dubbi.append(f"{tempo(w.start)}  {segnata:<24} {nota}")
if riga:
    righe.append(" ".join(riga))

# Trascrizione pulita (modello principale)
with open(file_trascrizione, "w", encoding="utf-8") as f:
    testo_righe, riga, segmento_corrente = [], [], None
    for n, inizio_seg, w in a:
        if n != segmento_corrente:
            if riga:
                testo_righe.append("".join(riga).strip())
            riga, segmento_corrente = [], n
        riga.append(w.word)
    if riga:
        testo_righe.append("".join(riga).strip())
    f.write("\n".join(testo_righe) + "\n")

# File di controllo
with open(file_controllo, "w", encoding="utf-8") as f:
    f.write(f"FILE DI CONTROLLO – {os.path.basename(audio)}\n")
    f.write(f"Creato il {time.strftime('%d/%m/%Y alle %H:%M')}\n")
    f.write(f"Modello principale: {MODELLO_A} – confronto: {MODELLO_B} – soglia di sicurezza: {SOGLIA}\n\n")
    f.write("LEGENDA\n")
    f.write("  *parola*    da controllare: sicurezza bassa OPPURE i due modelli non concordano\n")
    f.write("  **parola**  da controllare per prima: sicurezza bassa E i due modelli non concordano\n")
    f.write("  [hh:mm:ss]  punto dell'audio in cui inizia la frase\n\n")
    f.write(f"Parole da riverificare: {len(dubbi)} su {len(a)}\n\n")
    f.write("=" * 70 + "\nELENCO PAROLE DA RIASCOLTARE\n" + "=" * 70 + "\n")
    f.write("\n".join(dubbi) if dubbi else "Nessuna parola dubbia.")
    f.write("\n\n" + "=" * 70 + "\nTESTO CON LE PAROLE SEGNATE\n" + "=" * 70 + "\n")
    f.write("\n".join(righe) + "\n")

print(f"\nParole da riverificare: {len(dubbi)} su {len(a)}")
PYEOF

echo "Audio:        $AUDIO"
echo "Trascrizione: $TRASCRIZIONE"
echo "Controllo:    $CONTROLLO"

"$VENV/bin/python" "$SCRIPT_PY" "$AUDIO" "$TRASCRIZIONE" "$CONTROLLO" \
  || errore "La trascrizione non è riuscita."

# --- 4. Avviso e apertura del file di controllo

QUANTE=$(grep -m1 '^Parole da riverificare:' "$CONTROLLO" | sed 's/^Parole da riverificare: //')
avviso "Trascrizione completata.

Parole da riverificare: $QUANTE

Ora si aprirà il file con le parole da riverificare.
La trascrizione completa è in:
$(basename "$TRASCRIZIONE")"
open "$CONTROLLO"
echo "Fatto. Puoi chiudere questa finestra."
