#!/bin/bash
# Crea le immagini della guida in guida/immagini/:
#  1. prepara un progetto dimostrativo (intervista inventata, solo per le immagini);
#  2. avvia la schermata di controllo vera su quel progetto (senza aprire il browser);
#  3. fotografa le illustrazioni e la schermata con Chromium (guida/crea-immagini.js);
#  4. alleggerisce le immagini (Python con Pillow).
# uso: guida/crea-immagini.sh   (variabili: PLAYWRIGHT = modulo playwright, CHROME = Chromium)

set -eu
QUI=$(cd "$(dirname "$0")" && pwd)
DEMO=$(mktemp -d)
mkdir -p "$QUI/immagini"

python3 - "$DEMO" <<'PY'
import json, os, sys, wave
demo = sys.argv[1]
base = "000_IntervistaRossi"
cartella = os.path.join(demo, base)
clip = os.path.join(cartella, base + "_clip")
os.makedirs(clip)
voci = [  # (orario, contesto prima, parola, contesto dopo, segni, dettagli, confermata)
  ("00:00:14", "nel 1992 abbiamo aperto il", "laboratorio", "in via Garibaldi, all'inizio", "**",
   "sicurezza 0.52 – medium ha sentito: «laboratori» – riascolto large-v3: «laboratorio» – riascolto medium: «laboratori»", True),
  ("00:01:03", "mio padre faceva il", "ceramista", "e ci teneva molto alla tradizione", "*",
   "sicurezza 0.58 – riascolto large-v3: «ceramista» – riascolto medium: «ceramisti»", True),
  ("00:02:27", "la tecnica del", "racu", "l'abbiamo imparata da un maestro giapponese", "**",
   "sicurezza 0.21 – medium ha sentito: «raccu» – riascolto large-v3: «racù» – riascolto medium: «raccu»", False),
  ("00:03:10", "i forni a", "legno", "richiedono tre giorni di cottura", "*",
   "sicurezza 0.71 – medium ha sentito: «legna» – riascolto large-v3: «legno» – riascolto medium: «legna»", False),
  ("00:04:45", "a", "Faenza", "c'era la scuola più importante", "*",
   "sicurezza 0.49 – riascolto large-v3: «Faenza» – riascolto medium: «faenza.»", False),
  ("00:05:58", "lo smalto", "cristallino", "si ottiene con molta pazienza", "*",
   "sicurezza 0.55 – medium ha sentito: «cristallina» – riascolto large-v3: «cristallino» – riascolto medium: «cristallina»", False),
  ("00:07:12", "con il", "caolino", "che arriva dalla Cornovaglia", "**",
   "sicurezza 0.33 – medium ha sentito: «cavolino» – riascolto large-v3: «caolino» – riascolto medium: «Carolina»", False),
  ("00:08:40", "le", "maioliche", "dipinte a mano si vendono ancora", "*",
   "sicurezza 0.57 – riascolto large-v3: «maioliche» – riascolto medium: «maiolica»", False),
  ("00:09:55", "durante la", "pandemia", "abbiamo lavorato solo su ordinazione", "*",
   "sicurezza 0.59 – riascolto large-v3: «pandemia» – riascolto medium: «la pandemia»", False),
  ("00:11:20", "il", "tornio", "elettrico ha cambiato tutto", "**",
   "sicurezza 0.38 – medium ha sentito: «torno» – riascolto large-v3: «tornio» – riascolto medium: «torno»", False),
  ("00:12:48", "la cottura a", "terzo", "fuoco serve per l'oro", "*",
   "sicurezza 0.52 – riascolto large-v3: «terzo» – riascolto medium: «terso»", False),
  ("00:14:05", "vengono molti turisti", "giapponesi", "anche in inverno", "*",
   "sicurezza 0.56 – riascolto large-v3: «giapponesi» – riascolto medium: «giapponese»", False),
  ("00:15:30", "abbiamo esposto anche a", "Montelupo", "Fiorentino", "**",
   "sicurezza 0.27 – medium ha sentito: «Monte Lupo» – riascolto large-v3: «Montelupo» – riascolto medium: «Monte Lupo»", False),
]
righe = ["FILE DI CONTROLLO – " + base + "_audio.m4a", "", "Parole da riverificare: 11 su 3412", "",
         "=" * 70, "PAROLE DA RIASCOLTARE E CORREGGERE", "=" * 70]
dati_voci = {}
for i, (ora, prima, parola, dopo, segni, dettagli, confermata) in enumerate(voci, 1):
    numero = f"{i:03d}"
    nome_clip = f"{numero}_{ora.replace(':', '-')}.wav"
    with wave.open(os.path.join(clip, nome_clip), "wb") as w:  # 7 secondi di silenzio
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000); w.writeframes(b"\0\0" * 16000 * 7)
    dati_voci[numero] = {"indice": i, "clip": nome_clip}
    valore = parola if confermata else f"{segni}{parola}{segni}"
    righe += ["", f"[{numero}]  {ora}   ritaglio: {nome_clip}",
              f"       contesto: …{prima} [{parola}] {dopo}…", f"       {dettagli}", f"PAROLA {numero}: {valore}"]
open(os.path.join(cartella, base + "_controllo.txt"), "w", encoding="utf-8").write("\n".join(righe) + "\n")
json.dump({"audio": os.path.join(cartella, base + "_audio.m4a"), "trascrizione": base + "_trascrizione.txt",
           "cartella_clip": base + "_clip", "voci": dati_voci, "parole": []},
          open(os.path.join(cartella, base + "_dati.json"), "w", encoding="utf-8"), ensure_ascii=False)
PY

CONTROLLO="$DEMO/000_IntervistaRossi/000_IntervistaRossi_controllo.txt"
PORTA=8790
NON_APRIRE_BROWSER=1 PORTA=$PORTA HOME="$DEMO" PYTHONDONTWRITEBYTECODE=1 \
  python3 "$QUI/../../trascrizione-comune/schermata_controllo.py" "$CONTROLLO" > "$DEMO/server.log" 2>&1 &
for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q "http://" "$DEMO/server.log" 2>/dev/null && break; sleep 0.5; done
URL=$(grep -o 'http://[^ ]*' "$DEMO/server.log")
TOKEN=${URL##*t=}
echo "Creo le immagini in guida/immagini:"
node "$QUI/crea-immagini.js" "$URL"
curl -s -X POST -H "X-Token: $TOKEN" -d '{}' "http://127.0.0.1:$PORTA/api/chiudi" >/dev/null || true
rm -rf "$DEMO"

# Immagini più leggere (256 colori con retinatura: nessuna differenza visibile, un terzo del peso)
python3 - "$QUI/immagini" <<'PY'
import glob, os, sys
from PIL import Image
for f in glob.glob(os.path.join(sys.argv[1], "*.png")):
    im = Image.open(f).convert("RGB")
    im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(f, optimize=True)
PY
du -sh "$QUI/immagini"
