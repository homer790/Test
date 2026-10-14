#!/bin/bash
# Compila Finestre.cs come lo compila Windows PowerShell 5.1 (C# 5) e prova le finestre con Mono
# su uno schermo virtuale (Xvfb). Le foto delle finestre vanno nella cartella indicata.
# uso: test/prova-finestre.sh [cartella_foto]     (servono mono-mcs, Mono Windows Forms, xvfb-run)
set -eu
QUI=$(cd "$(dirname "$0")/.." && pwd)
FOTO="${1:-$(mktemp -d)}"
mkdir -p "$FOTO"
LAVORO=$(mktemp -d)
mcs -langversion:5 -r:System.Windows.Forms.dll -r:System.Drawing.dll \
    -out:"$LAVORO/prova.exe" "$QUI/programma/Finestre.cs" "$QUI/test/ProvaFinestre.cs"
xvfb-run -a -s "-screen 0 1280x900x24" mono "$LAVORO/prova.exe" "$FOTO" "$QUI/programma/TrascriviAudio.ico"
echo "(foto delle finestre in $FOTO)"
