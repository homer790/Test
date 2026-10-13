#!/bin/bash
# Applica-Correzioni.command — da aprire con doppio clic dopo aver corretto il file di controllo.
#
# 1. Chiede il file di controllo corretto a mano (NOME_controllo.txt).
# 2. Crea NOME_trascrizione_corretta.txt con le tue correzioni.
# 3. Impara le correzioni: le aggiunge al dizionario personale usato dalle trascrizioni
#    future e salva i ritagli audio con la parola giusta come esempi.
# 4. Avvisa con un popup e apre la trascrizione corretta.
#
# Si può rilanciare quante volte si vuole: riparte sempre dalla trascrizione originale.

set -u

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
CARTELLA=$(dirname "$CONTROLLO")
BASE=$(basename "$CONTROLLO" .txt)
DATI="$CARTELLA/$(echo "$BASE" | sed 's/_controllo/_dati/').json"
CORRETTA="$CARTELLA/$(echo "$BASE" | sed 's/_controllo/_trascrizione_corretta/').txt"
[ -e "$DATI" ] || errore "Non trovo il file $(basename "$DATI") accanto al file di controllo.
Serve per applicare le correzioni: non spostarlo e non rinominarlo."

PYTHON="$VENV/bin/python"
[ -x "$PYTHON" ] || PYTHON=$(command -v python3) || errore "Python non trovato. Esegui prima Trascrivi-Audio.command."

RIEPILOGO=$("$PYTHON" - "$CONTROLLO" "$DATI" "$CORRETTA" <<'PYEOF'
import json
import os
import re
import shutil
import sys

file_controllo, file_dati, file_corretta = sys.argv[1:4]
DIZIONARIO, ESEMPI = os.environ["DIZIONARIO"], os.environ["ESEMPI"]
norm = lambda t: re.sub(r"[^\w']", "", t.lower())

dati = json.load(open(file_dati, encoding="utf-8"))
parole = dati["parole"]
cartella = os.path.dirname(file_controllo)
nome_audio = os.path.splitext(os.path.basename(dati["audio"]))[0]

# Le righe «PAROLA 001: ...» del file corretto a mano
scritte = {}
for riga in open(file_controllo, encoding="utf-8"):
    m = re.match(r"\s*PAROLA\s+(\d+)\s*:(.*)$", riga)
    if m:
        scritte[m.group(1).zfill(3)] = m.group(2).strip()

corrette, confermate, rimaste, mancanti, imparate = 0, 0, 0, [], {}
segnate = set()
for numero, voce in dati["voci"].items():
    i = voce["indice"]
    if numero not in scritte:
        mancanti.append(numero)
        segnate.add(i)
        continue
    valore = scritte[numero]
    if "*" in valore:  # non corretta: resta da verificare
        rimaste += 1
        segnate.add(i)
        continue
    originale = parole[i]["testo"]
    if valore == originale:
        confermate += 1
        continue
    corrette += 1
    parole[i]["testo"], parole[i]["raw"] = valore, (" " + valore if valore else "")
    if valore and norm(valore) != norm(originale):
        imparate[originale] = valore
    # Esempio per il futuro: ritaglio audio + testo giusto di quel tratto
    clip = os.path.join(cartella, dati["cartella_clip"], voce["clip"])
    if os.path.exists(clip):
        os.makedirs(ESEMPI, exist_ok=True)
        nome = f"{nome_audio}_{voce['clip'][:-4]}"
        shutil.copyfile(clip, os.path.join(ESEMPI, nome + ".wav"))
        t0, t1 = parole[i]["start"] - 3, parole[i]["end"] + 3
        tratto = "".join(p["raw"] for p in parole if t0 <= p["start"] and p["end"] <= t1).strip()
        with open(os.path.join(ESEMPI, nome + ".txt"), "w", encoding="utf-8") as f:
            f.write(f"parola: {originale} → {valore}\ntesto: {tratto}\n")

# Trascrizione corretta (le parole non ancora verificate restano tra asterischi)
righe, riga, corrente = [], [], None
for i, p in enumerate(parole):
    if p["seg"] != corrente and riga:
        righe.append("".join(riga).strip())
        riga = []
    corrente = p["seg"]
    riga.append(f" *{p['testo']}*" if i in segnate else p["raw"])
if riga:
    righe.append("".join(riga).strip())
with open(file_corretta, "w", encoding="utf-8") as f:
    f.write("\n".join(r for r in righe if r) + "\n")

# Dizionario personale: «sbagliata → giusta», usato dalle prossime trascrizioni
voci_diz = {}
if os.path.exists(DIZIONARIO):
    for r in open(DIZIONARIO, encoding="utf-8"):
        if "→" in r and not r.lstrip().startswith("#"):
            s, g = (x.strip() for x in r.split("→", 1))
            voci_diz[s] = g
nuove = sum(1 for s, g in imparate.items() if voci_diz.get(s) != g)
voci_diz.update(imparate)
os.makedirs(os.path.dirname(DIZIONARIO), exist_ok=True)
with open(DIZIONARIO, "w", encoding="utf-8") as f:
    f.write("# Dizionario personale di Trascrivi-Audio: «parola sentita male → parola giusta».\n")
    f.write("# Si può modificare a mano. Le righe che iniziano con # sono ignorate.\n")
    for s, g in voci_diz.items():
        f.write(f"{s} → {g}\n")

print(f"{corrette}|{confermate}|{rimaste + len(mancanti)}|{nuove}|{','.join(mancanti)}")
PYEOF
) || errore "Non sono riuscito ad applicare le correzioni. Guarda la finestra del Terminale."

IFS='|' read -r CORRETTE CONFERMATE RIMASTE NUOVE MANCANTI <<< "$RIEPILOGO"
MESSAGGIO="Correzioni applicate.

Parole corrette: $CORRETTE
Parole confermate: $CONFERMATE
Ancora da verificare (con asterisco): $RIMASTE
Nuove parole imparate nel dizionario: $NUOVE"
[ -n "$MANCANTI" ] && MESSAGGIO="$MESSAGGIO

Attenzione: non trovo le righe PAROLA $MANCANTI (cancellate per sbaglio?). Restano da verificare."
avviso "$MESSAGGIO

Ora si aprirà la trascrizione corretta:
$(basename "$CORRETTA")"
open "$CORRETTA"
echo "Fatto. Puoi chiudere questa finestra."
