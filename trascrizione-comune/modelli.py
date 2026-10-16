"""Modelli di Whisper: quali mancano e download, con l'avanzamento.

uso: modelli.py mancanti NOME...   stampa i modelli non ancora scaricati, uno per riga
     modelli.py scarica NOME       scarica un modello, mostrando l'avanzamento
I modelli stanno nella cartella CARTELLA_MODELLI (variabile d'ambiente).
"""
import os
import subprocess
import sys

os.environ.setdefault("HF_HUB_VERBOSITY", "error")  # niente avvisi tecnici in inglese durante il download


def tieni_sveglio():
    """Evita che il computer vada in stop mentre il programma lavora (download o trascrizioni di ore):
    l'attività del processore da sola non basta a tenerlo sveglio. Vale finché il programma è aperto."""
    try:
        if sys.platform == "win32":
            import ctypes
            ctypes.windll.kernel32.SetThreadExecutionState(0x80000001)  # ES_CONTINUOUS | ES_SYSTEM_REQUIRED
        elif sys.platform == "darwin":
            subprocess.Popen(["caffeinate", "-i", "-w", str(os.getpid())],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:  # noqa: BLE001, S110 — se non si può, si lavora lo stesso
        pass


def usa_certificati_del_computer():
    """Per i download usa i certificati del computer, come il browser: così funzionano anche con gli
    antivirus che controllano le connessioni protette e con le reti aziendali."""
    try:
        import truststore
        truststore.inject_into_ssl()
    except Exception:  # noqa: BLE001, S110 — senza truststore restano i certificati di Python
        pass


def scarica(nome, cartella):
    import faster_whisper.utils
    from tqdm.auto import tqdm
    # faster-whisper nasconde l'avanzamento del download (gigabyte per large-v3): lo rimettiamo
    faster_whisper.utils.disabled_tqdm = tqdm
    faster_whisper.utils.download_model(nome, cache_dir=cartella)


def mancanti(nomi, cartella):
    from faster_whisper import download_model
    for nome in dict.fromkeys(n for n in nomi if n):
        try:
            download_model(nome, cache_dir=cartella, local_files_only=True)
        except Exception:  # noqa: BLE001 — qualsiasi errore vuol dire «non c'è»
            print(nome)


if __name__ == "__main__":
    comando = sys.argv[1] if len(sys.argv) > 1 else ""
    if comando == "mancanti":
        mancanti(sys.argv[2:], os.environ["CARTELLA_MODELLI"])
    elif comando == "scarica" and len(sys.argv) == 3:
        tieni_sveglio()
        usa_certificati_del_computer()
        scarica(sys.argv[2], os.environ["CARTELLA_MODELLI"])
    else:
        print(__doc__)
        sys.exit(1)
