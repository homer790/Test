"""Modelli di Whisper: quali mancano e download (usato dalla versione Windows).

uso: modelli.py mancanti NOME...   stampa i modelli non ancora scaricati, uno per riga
     modelli.py scarica NOME       scarica un modello, mostrando l'avanzamento
I modelli stanno nella cartella CARTELLA_MODELLI (variabile d'ambiente).
"""
import os
import sys

from faster_whisper import download_model

cartella = os.environ["CARTELLA_MODELLI"]
comando = sys.argv[1] if len(sys.argv) > 1 else ""
if comando == "mancanti":
    for nome in dict.fromkeys(a for a in sys.argv[2:] if a):
        try:
            download_model(nome, cache_dir=cartella, local_files_only=True)
        except Exception:  # noqa: BLE001 — qualsiasi errore vuol dire «non c'è»
            print(nome)
elif comando == "scarica" and len(sys.argv) == 3:
    download_model(sys.argv[2], cache_dir=cartella)
else:
    print(__doc__)
    sys.exit(1)
