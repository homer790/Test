#!/bin/bash
# Crea le immagini della guida per Windows in guida/immagini/:
#  1. le illustrazioni disegnate in guida/illustrazioni.html (crea-immagini.js, con Chromium);
#  2. le immagini reali della schermata di controllo, uguali alla versione Mac (si aprono nel
#     browser): copiate da ../trascrizione-mac/guida/immagini (crearle con il suo crea-immagini.sh);
#  3. alleggerisce le immagini (Python con Pillow).
# uso: guida/crea-immagini.sh   (variabili: PLAYWRIGHT = modulo playwright, CHROME = Chromium)
set -eu
QUI=$(cd "$(dirname "$0")" && pwd)
MAC="$QUI/../../trascrizione-mac/guida/immagini"
mkdir -p "$QUI/immagini"
echo "Creo le immagini in guida/immagini:"
node "$QUI/crea-immagini.js"
cp "$MAC/p06-schermata.png" "$MAC/p08-schermata-parti.png" "$QUI/immagini/"
python3 - "$QUI/immagini" <<'PY'
import glob, os, sys
from PIL import Image
for f in glob.glob(os.path.join(sys.argv[1], "*.png")):
    im = Image.open(f)
    if im.mode == "P":
        continue  # già alleggerita
    im.convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT,
                               dither=Image.Dither.FLOYDSTEINBERG).save(f, optimize=True)
PY
du -sh "$QUI/immagini"
