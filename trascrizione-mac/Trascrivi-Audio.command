#!/bin/bash
# Trascrivi-Audio.command — da aprire con doppio clic nel Finder (macOS).
#
# 1. Se manca, chiede il permesso e installa Whisper (faster-whisper) in locale.
# 2. Chiede il file audio e la cartella dove salvare i risultati.
# 3. Trascrive due volte (large-v3 e medium), confronta e segna le parole dubbie,
#    poi riascolta solo le frasi dubbie: se il riascolto di large coincide con medium
#    il dubbio è risolto, altrimenti un ascolto in più con medium deve confermarlo.
# 4. Ritaglia l'audio intorno a ogni parola ancora dubbia (3 s prima e dopo).
# 5. Avvisa con un popup e apre il file di controllo, da correggere a mano;
#    poi Applica-Correzioni.command crea la trascrizione corretta e impara le correzioni.
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
export MODELLO_C="${MODELLO_C:-medium}"     # terzo ascolto delle frasi ancora dubbie
export RIASCOLTO="${RIASCOLTO:-1}"          # 0 = non riascoltare le frasi dubbie
export CARTELLA_MODELLI="$SUPPORTO/modelli"
export DIZIONARIO="$SUPPORTO/dizionario.txt"   # creato e arricchito da Applica-Correzioni.command

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
if [ -e "$DESTINAZIONE/${NOME}_controllo.txt" ] || [ -e "$DESTINAZIONE/${NOME}_trascrizione.txt" ] \
   || [ -e "$DESTINAZIONE/${NOME}_clip" ]; then
  SUFFISSO="_$(date +%Y%m%d-%H%M%S)"   # non sovrascrivere risultati precedenti
fi
TRASCRIZIONE="$DESTINAZIONE/${NOME}_trascrizione${SUFFISSO}.txt"
CONTROLLO="$DESTINAZIONE/${NOME}_controllo${SUFFISSO}.txt"
DATI="$DESTINAZIONE/${NOME}_dati${SUFFISSO}.json"      # serve ad Applica-Correzioni
CLIP="$DESTINAZIONE/${NOME}_clip${SUFFISSO}"

# --- 3. Trascrizione e confronto (script Python scritto ogni volta, così è sempre aggiornato)

mkdir -p "$SUPPORTO" "$CARTELLA_MODELLI"
cat > "$SCRIPT_PY" <<'PYEOF'
import difflib
import json
import os
import re
import sys
import time
import wave

from faster_whisper import WhisperModel
from faster_whisper.audio import decode_audio

audio, file_trascrizione, file_controllo, file_dati, cartella_clip = sys.argv[1:6]
MODELLO_A = os.environ.get("MODELLO_A", "large-v3")
MODELLO_B = os.environ.get("MODELLO_B", "medium")
MODELLO_C = os.environ.get("MODELLO_C", "") or MODELLO_B  # terzo ascolto delle frasi ancora dubbie
SOGLIA = float(os.environ.get("SOGLIA", "0.6"))
LINGUA = os.environ.get("LINGUA", "it") or None
RIASCOLTO = os.environ.get("RIASCOLTO", "1") != "0"
CARTELLA_MODELLI = os.environ.get("CARTELLA_MODELLI")
DIZIONARIO = os.environ.get("DIZIONARIO", "")
FREQ = 16000        # campioni al secondo dell'audio decodificato
MARGINE = 0.5       # secondi aggiunti prima e dopo ogni frase riascoltata
MARGINE_CLIP = 3.0  # secondi aggiunti prima e dopo ogni parola nei ritagli per l'ascolto manuale
FASI = 4 if RIASCOLTO else 2


def tempo(secondi):
    s = int(secondi)
    return f"{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d}"


norm = lambda t: re.sub(r"[^\w']", "", t.lower())  # toglie spazi, maiuscole e punteggiatura

# Dizionario personale, creato da Applica-Correzioni: righe «sbagliata → giusta»
correzioni_note = {}
if DIZIONARIO and os.path.exists(DIZIONARIO):
    for riga in open(DIZIONARIO, encoding="utf-8"):
        if "→" in riga and not riga.lstrip().startswith("#"):
            sbagliata, giusta = (x.strip() for x in riga.split("→", 1))
            if norm(sbagliata) and giusta:
                correzioni_note[norm(sbagliata)] = giusta
# Le parole giuste vengono suggerite a Whisper (le più recenti per ultime, ne teniamo un numero limitato)
suggerimenti = " ".join(list(dict.fromkeys(correzioni_note.values()))[-40:]) or None


class Parola:
    def __init__(self, seg, w):
        self.seg = seg
        self.raw = w.word  # con lo spazio iniziale originale, per il testo pulito
        self.testo, self.start, self.end, self.prob = w.word.strip(), w.start, w.end, w.probability
        self.alternativa = None  # cosa ha sentito il modello di confronto, se diverso
        self.medio = ""          # cosa ha sentito il modello di confronto nello stesso punto
        self.riascolto_a = ""
        self.risolta = None      # come è stato risolto il dubbio
        self.note = []

    def sostituisci(self, nuovo):
        self.testo, self.raw = nuovo, " " + nuovo


def carica(nome_modello, fase):
    print(f"\n[{fase}/{FASI}] Carico il modello {nome_modello} "
          "(la prima volta viene scaricato, può volerci molto)...", flush=True)
    return WhisperModel(nome_modello, device="cpu", compute_type="int8", download_root=CARTELLA_MODELLI)


def trascrivi(modello, nome_modello, fase):
    segmenti, info = modello.transcribe(audio, language=LINGUA, word_timestamps=True, beam_size=5,
                                        vad_filter=True, hotwords=suggerimenti)
    durata = info.duration or 1
    inizio = time.time()
    parole, frasi = [], {}
    for n, seg in enumerate(segmenti):
        frasi[n] = (seg.start, seg.end)
        for w in seg.words or []:
            parole.append(Parola(n, w))
        print(f"\r[{fase}/{FASI}] {nome_modello}: {min(seg.end / durata, 1):6.1%} "
              f"({tempo(seg.end)} di {tempo(durata)})", end="", flush=True)
    print(f"\n[{fase}/{FASI}] {nome_modello} completato in {tempo(time.time() - inizio)}.", flush=True)
    return parole, frasi


def nello_stesso_punto(parole, p):
    """Testo delle parole (start, end, testo) che cadono nello stesso punto dell'audio della parola p:
    quelle che stanno per più di metà dentro p; se nessuna, quella che si sovrappone di più."""
    sovrapp = [(min(e, p.end) - max(s, p.start), s, e, t) for s, e, t in parole]
    dentro = [t for o, s, e, t in sovrapp if o > 0 and o >= 0.5 * max(e - s, 0.01)]
    if dentro:
        return " ".join(dentro)
    migliore = max(sovrapp, default=None)
    return migliore[3] if migliore and migliore[0] > 0 else ""


def dubbia(p):
    return p.risolta is None and (p.prob < SOGLIA or p.alternativa is not None)


def riascolta(modello, nome_modello, fase, campioni, frasi_da_rifare, contesto):
    """Riascolta solo le frasi indicate, ritagliate dall'audio. Restituisce {frase: [(start, end, testo)]}."""
    durata_audio = len(campioni) / FREQ
    risultato = {}
    for k, n in enumerate(frasi_da_rifare, 1):
        print(f"\r[{fase}/{FASI}] Riascolto con {nome_modello}: frase {k} di {len(frasi_da_rifare)}",
              end="", flush=True)
        s0, s1 = frasi[n]
        t0, t1 = max(0.0, s0 - MARGINE), min(durata_audio, s1 + MARGINE)
        segmenti, _ = modello.transcribe(
            campioni[int(t0 * FREQ):int(t1 * FREQ)], language=LINGUA, word_timestamps=True,
            beam_size=10, best_of=5, initial_prompt=contesto(n) or None, hotwords=suggerimenti,
            condition_on_previous_text=False, vad_filter=False)
        risultato[n] = [(w.start + t0, w.end + t0, w.word.strip())
                        for seg in segmenti for w in (seg.words or [])]
    print(flush=True)
    return risultato


def applica(p, sentito, come):
    if norm(sentito) != norm(p.testo):
        p.note.append(f"corretta: «{p.testo}» → «{sentito}» ({come})")
        p.sostituisci(sentito)
    else:
        p.note.append(f"confermata: «{p.testo}» ({come})")
    p.risolta = come


# --- 1° e 2° ascolto: due modelli diversi sull'intero audio
modello_a = carica(MODELLO_A, 1)
a, frasi = trascrivi(modello_a, MODELLO_A, 1)
modello_b = carica(MODELLO_B, 2)
b, _ = trascrivi(modello_b, MODELLO_B, 2)

sm = difflib.SequenceMatcher(a=[norm(p.testo) for p in a], b=[norm(p.testo) for p in b], autojunk=False)
for op, i1, i2, j1, j2 in sm.get_opcodes():
    if op in ("replace", "delete"):
        sentito = " ".join(p.testo for p in b[j1:j2]) or "(niente)"
        for i in range(i1, i2):
            a[i].alternativa = sentito
parole_b = [(p.start, p.end, p.testo) for p in b]
for p in a:
    p.medio = nello_stesso_punto(parole_b, p)

# Errori già corretti a mano in passato (dizionario personale)
for p in a:
    giusta = correzioni_note.get(norm(p.testo))
    if giusta and norm(giusta) != norm(p.testo):
        applica(p, giusta, "dal tuo dizionario")

dubbie_iniziali = sum(dubbia(p) for p in a)
contesto = lambda n: " ".join(p.testo for p in a if p.seg == n - 1)  # la frase precedente aiuta il modello
campioni = decode_audio(audio, sampling_rate=FREQ)

# --- Riascolto delle sole frasi con parole dubbie
if RIASCOLTO and dubbie_iniziali:
    # 3° ascolto: large riascolta; se coincide con quanto sentito da medium, il dubbio è risolto
    frasi_dubbie = sorted({p.seg for p in a if dubbia(p)})
    print(f"\n[3/{FASI}] {len(frasi_dubbie)} frasi con parole dubbie da riascoltare", flush=True)
    riascolto_a = riascolta(modello_a, MODELLO_A, 3, campioni, frasi_dubbie, contesto)
    for p in a:
        if dubbia(p):
            p.riascolto_a = nello_stesso_punto(riascolto_a[p.seg], p)
            p.note.append(f"riascolto {MODELLO_A}: «{p.riascolto_a or '(niente)'}»")
            if p.riascolto_a and norm(p.riascolto_a) == norm(p.medio):
                applica(p, p.riascolto_a, f"riascolto {MODELLO_A} = {MODELLO_B}")

    # 4° ascolto: dove ancora non coincidono, ascolta di nuovo con il modello C
    frasi_dubbie = sorted({p.seg for p in a if dubbia(p)})
    if frasi_dubbie:
        if MODELLO_C != MODELLO_B:
            del modello_b
            modello_b = carica(MODELLO_C, 4)
        riascolto_c = riascolta(modello_b, MODELLO_C, 4, campioni, frasi_dubbie, contesto)
        for p in a:
            if dubbia(p):
                sentito_c = nello_stesso_punto(riascolto_c[p.seg], p)
                p.note.append(f"riascolto {MODELLO_C}: «{sentito_c or '(niente)'}»")
                if p.riascolto_a and norm(sentito_c) == norm(p.riascolto_a):
                    applica(p, p.riascolto_a, f"riascolto {MODELLO_A} = riascolto {MODELLO_C}")

# --- Ritagli audio (3 secondi prima e dopo) per le parole ancora dubbie
dubbie = [i for i, p in enumerate(a) if dubbia(p)]
os.makedirs(cartella_clip, exist_ok=True)
durata_audio = len(campioni) / FREQ
voci = {}  # numero voce -> indice parola
for numero, i in enumerate(dubbie, 1):
    p = a[i]
    t0, t1 = max(0.0, p.start - MARGINE_CLIP), min(durata_audio, p.end + MARGINE_CLIP)
    pezzo = (campioni[int(t0 * FREQ):int(t1 * FREQ)].clip(-1, 1) * 32767).astype("<i2")
    nome_clip = f"{numero:03d}_{tempo(p.start).replace(':', '-')}.wav"
    with wave.open(os.path.join(cartella_clip, nome_clip), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(FREQ)
        w.writeframes(pezzo.tobytes())
    voci[f"{numero:03d}"] = {"indice": i, "clip": nome_clip}

# --- Risultati
def testo_pulito(parole):
    righe, riga, corrente = [], [], None
    for p in parole:
        if p.seg != corrente and riga:
            righe.append("".join(riga).strip())
            riga = []
        corrente = p.seg
        riga.append(p.raw)
    if riga:
        righe.append("".join(riga).strip())
    return "\n".join(righe) + "\n"


def segna(p):
    if not dubbia(p):
        return p.testo
    return f"**{p.testo}**" if p.prob < SOGLIA and p.alternativa is not None else f"*{p.testo}*"


righe_segnate, riga, corrente = [], [], None
for p in a:
    if p.seg != corrente:
        if riga:
            righe_segnate.append(" ".join(riga))
        riga, corrente = [f"[{tempo(frasi[p.seg][0])}]"], p.seg
    riga.append(segna(p))
if riga:
    righe_segnate.append(" ".join(riga))

risolte = [f"{tempo(p.start)}  {p.note[-1]}" for p in a if p.risolta]

with open(file_trascrizione, "w", encoding="utf-8") as f:
    f.write(testo_pulito(a))

with open(file_dati, "w", encoding="utf-8") as f:
    json.dump({"audio": audio, "trascrizione": os.path.basename(file_trascrizione),
               "cartella_clip": os.path.basename(cartella_clip), "voci": voci,
               "parole": [{"seg": p.seg, "raw": p.raw, "testo": p.testo, "start": p.start, "end": p.end}
                          for p in a]}, f, ensure_ascii=False, indent=1)

with open(file_controllo, "w", encoding="utf-8") as f:
    f.write(f"FILE DI CONTROLLO – {os.path.basename(audio)}\n")
    f.write(f"Creato il {time.strftime('%d/%m/%Y alle %H:%M')}\n")
    f.write(f"Modello principale: {MODELLO_A} – confronto: {MODELLO_B} – terzo ascolto: {MODELLO_C} – "
            f"soglia di sicurezza: {SOGLIA}\n\n")
    f.write("COME CORREGGERE\n")
    f.write(f"  1. Apri la cartella «{os.path.basename(cartella_clip)}»: ogni ritaglio ha lo stesso numero\n")
    f.write("     della voce qui sotto (nel Finder selezionalo e premi la barra spaziatrice).\n")
    f.write("  2. Nella riga «PAROLA» scrivi la parola giusta SENZA asterischi.\n")
    f.write("     Era già giusta? Togli solo gli asterischi. Va cancellata? Lascia vuoto dopo i due punti.\n")
    f.write("     Non sei sicuro? Lascia gli asterischi.\n")
    f.write("  3. Salva (Cmd+S) e fai doppio clic su «Applica-Correzioni.command».\n\n")
    f.write("LEGENDA\n")
    f.write("  *parola*    da controllare: sicurezza bassa OPPURE i modelli non concordano\n")
    f.write("  **parola**  da controllare per prima: sicurezza bassa E i modelli non concordano\n\n")
    f.write(f"Parole da riverificare: {len(dubbie)} su {len(a)}\n")
    f.write(f"(prima del riascolto erano {dubbie_iniziali}, {len(risolte)} risolte automaticamente)\n\n")
    f.write("=" * 70 + "\nPAROLE DA RIASCOLTARE E CORREGGERE\n" + "=" * 70 + "\n")
    if not dubbie:
        f.write("Nessuna parola dubbia.\n")
    for numero, v in voci.items():
        i = v["indice"]
        p = a[i]
        prima = " ".join(x.testo for x in a[max(0, i - 6):i])
        dopo = " ".join(x.testo for x in a[i + 1:i + 7])
        dettagli = f"sicurezza {p.prob:.2f}"
        if p.alternativa is not None:
            dettagli += f" – {MODELLO_B} ha sentito: «{p.alternativa}»"
        dettagli += "".join(f" – {x}" for x in p.note)
        f.write(f"\n[{numero}]  {tempo(p.start)}   ritaglio: {v['clip']}\n")
        f.write(f"       contesto: …{prima} [{p.testo}] {dopo}…\n")
        f.write(f"       {dettagli}\n")
        f.write(f"PAROLA {numero}: {segna(p)}\n")
    f.write("\n" + "=" * 70 + "\nTESTO CON LE PAROLE SEGNATE (solo da leggere)\n" + "=" * 70 + "\n")
    f.write("\n".join(righe_segnate) + "\n")
    f.write("\n" + "=" * 70 + "\nRISOLTE AUTOMATICAMENTE (per controllo)\n" + "=" * 70 + "\n")
    f.write("\n".join(risolte) if risolte else "Nessuna.")
    f.write("\n")

print(f"\nParole da riverificare: {len(dubbie)} su {len(a)} (prima del riascolto: {dubbie_iniziali})")
PYEOF

echo "Audio:        $AUDIO"
echo "Trascrizione: $TRASCRIZIONE"
echo "Controllo:    $CONTROLLO"

"$VENV/bin/python" "$SCRIPT_PY" "$AUDIO" "$TRASCRIZIONE" "$CONTROLLO" "$DATI" "$CLIP" \
  || errore "La trascrizione non è riuscita."

# --- 4. Avviso e apertura del file di controllo

QUANTE=$(grep -m1 '^Parole da riverificare:' "$CONTROLLO" | sed 's/^Parole da riverificare: //')
avviso "Trascrizione completata.

Parole da riverificare: $QUANTE
$(grep -m1 '^(prima del riascolto' "$CONTROLLO")

Ora si aprirà il file con le parole da riverificare.
I ritagli audio da ascoltare sono nella cartella:
$(basename "$CLIP")

Dopo aver corretto e salvato il file, fai doppio clic su Applica-Correzioni.command."
open "$CONTROLLO"
echo "Fatto. Puoi chiudere questa finestra."
