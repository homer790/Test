"""Gestione dei progetti di Trascrivi Audio.

Ogni trascrizione è un progetto, con una cartella dedicata «NNN_NomeSenzaSpazi» dentro la
cartella dei progetti (variabile CARTELLA_PROGETTI, di solito Documenti/Trascrivi Audio/Progetti).
Due file, sempre in quella cartella:

- elenco-progetti.json   file generale: per ogni progetto numero, nome, cartella e lista dei file;
- progetto-in-corso.json file temporaneo: i dati del progetto su cui si sta lavorando. Viene
                         scritto quando si apre o si crea un progetto e cancellato alla fine.

Il programma lavora solo sui file del progetto in corso. Uso (da Trascrivi-Audio.command):
  progetti.py elenco [--trascritti]   nomi dei progetti, uno per riga (crea il file generale se manca)
  progetti.py crea NOME               nuovo progetto (cartella + file generale + file temporaneo)
  progetti.py seleziona NOME          rende NOME il progetto in corso (uscita 3 se la cartella non c'è più)
  progetti.py togli NOME              toglie dall'elenco un progetto la cui cartella non esiste più
  progetti.py imposta-audio PERCORSO  controlla l'audio sorgente e lo copia nel progetto in corso
  progetti.py controlla-audio PERCORSO  controlla che il file contenga audio leggibile
  progetti.py campo CHIAVE            un dato del progetto in corso (i file come percorso completo)
  progetti.py stato STATO             aggiorna lo stato del progetto in corso (es. «trascritto»)
  progetti.py chiudi                  cancella il file temporaneo
  progetti.py migra VECCHIA_CARTELLA  sposta qui i progetti di una versione precedente
"""
import json
import os
import re
import shutil
import sys
import time
import unicodedata

CARTELLA = os.path.abspath(os.environ.get("CARTELLA_PROGETTI")
                           or os.path.expanduser("~/Documents/Trascrivi Audio/Progetti"))
GENERALE = os.path.join(CARTELLA, "elenco-progetti.json")
IN_CORSO = os.path.join(CARTELLA, "progetto-in-corso.json")
MASSIMO = 999


class Errore(Exception):
    codice = 2


class CartellaMancante(Errore):
    codice = 3


def adesso():
    return time.strftime("%Y-%m-%d %H:%M:%S")


def scrivi_json(percorso, dati):
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    temporaneo = percorso + ".tmp"
    with open(temporaneo, "w", encoding="utf-8") as f:
        json.dump(dati, f, ensure_ascii=False, indent=2)
    os.replace(temporaneo, percorso)


def leggi_generale():
    if not os.path.exists(GENERALE):
        scrivi_json(GENERALE, {"descrizione": "Elenco dei progetti di Trascrivi Audio", "progetti": []})
    try:
        with open(GENERALE, encoding="utf-8") as f:
            generale = json.load(f)
    except ValueError as e:
        raise Errore(f"Il file dell'elenco dei progetti è rovinato e non si può leggere:\n{GENERALE}\n"
                     f"({e}). Se l'hai modificato a mano, rimetti com'era il testo che hai cambiato.") from e
    # Se la cartella dei progetti è stata spostata tutta insieme (es. da Windows dentro OneDrive),
    # i progetti si ritrovano accanto a questo file: si aggiornano i loro percorsi
    spostati = False
    for p in generale["progetti"]:
        qui = os.path.join(CARTELLA, os.path.basename(p["cartella"]))
        if not os.path.isdir(p["cartella"]) and os.path.isdir(qui):
            p["cartella"], spostati = qui, True
    if spostati:
        scrivi_json(GENERALE, generale)
    return generale


def leggi_in_corso():
    if not os.path.exists(IN_CORSO):
        raise Errore("Nessun progetto in corso.")
    with open(IN_CORSO, encoding="utf-8") as f:
        return json.load(f)


def salva(progetto):
    """Aggiorna il progetto nel file generale e nel file temporaneo."""
    progetto["aggiornato"] = adesso()
    generale = leggi_generale()
    generale["progetti"] = [p for p in generale["progetti"] if p["numero"] != progetto["numero"]] + [progetto]
    generale["progetti"].sort(key=lambda p: p["numero"])
    scrivi_json(GENERALE, generale)
    scrivi_json(IN_CORSO, progetto)


def nome_cartella(numero, nome):
    compatto = re.sub(r"[^\w-]", "", nome.replace(" ", ""))  # niente spazi né caratteri strani
    while len(compatto.encode("utf-8")) > 120:  # i nomi dei file devono restare sotto i 255 byte
        compatto = compatto[:-1]
    return f"{numero}_{compatto or 'Progetto'}"


def stesso_nome(a, b):
    return unicodedata.normalize("NFC", a).casefold() == unicodedata.normalize("NFC", b).casefold()


def elenco(solo_trascritti=False):
    for p in leggi_generale()["progetti"]:
        if not solo_trascritti or p.get("stato") == "trascritto":
            print(p["nome"])


def crea(nome):
    nome = unicodedata.normalize("NFC", re.sub(r"\s+", " ", nome).strip())
    if not nome:
        raise Errore("Il nome del progetto non può essere vuoto.")
    if len(nome) > 60:
        raise Errore("Il nome del progetto è troppo lungo (massimo 60 caratteri).")
    generale = leggi_generale()
    for p in [p for p in generale["progetti"] if stesso_nome(p["nome"], nome)]:
        if os.path.isdir(p["cartella"]):
            raise Errore(f"Esiste già un progetto chiamato «{nome}». Scegli un altro nome.")
        generale["progetti"].remove(p)  # la sua cartella è stata cancellata: il nome si può riusare
        scrivi_json(GENERALE, generale)
    usati = {int(p["numero"]) for p in generale["progetti"]}
    # niente numeri già usati da cartelle presenti (es. un progetto tolto dall'elenco a mano)
    usati |= {int(c[:3]) for c in os.listdir(CARTELLA) if re.match(r"^\d{3}_", c)}
    liberi = [n for n in range(MASSIMO + 1) if n not in usati]
    if not liberi:
        raise Errore(f"Hai raggiunto il numero massimo di progetti ({MASSIMO + 1}).")
    numero = f"{liberi[0]:03d}"
    base = nome_cartella(numero, nome)
    cartella = os.path.join(CARTELLA, base)
    os.makedirs(cartella, exist_ok=False)
    progetto = {
        "numero": numero, "nome": nome, "cartella": cartella, "creato": adesso(), "stato": "nuovo",
        "audio_originale": "",
        "file": {  # nomi dei file, dentro la cartella del progetto
            "audio": "",
            "trascrizione": f"{base}_trascrizione.txt",
            "trascrizione_corretta": f"{base}_trascrizione_corretta.txt",
            "controllo": f"{base}_controllo.txt",
            "dati": f"{base}_dati.json",
            "clip": f"{base}_clip",
        },
    }
    salva(progetto)
    print(cartella)


def seleziona(nome):
    for p in leggi_generale()["progetti"]:
        if p["nome"] == nome:
            if not os.path.isdir(p["cartella"]):
                raise CartellaMancante(f"La cartella del progetto «{nome}» non esiste più:\n{p['cartella']}")
            controllo = os.path.join(p["cartella"], p["file"]["controllo"])
            if p.get("stato") != "trascritto" and os.path.exists(controllo):
                # trascrizione finita ma stato non aggiornato (es. programma chiuso proprio alla fine)
                p["stato"] = "trascritto"
                salva(p)
            else:
                scrivi_json(IN_CORSO, p)
            print(p["cartella"])
            return
    raise Errore(f"Progetto «{nome}» non trovato.")


def togli(nome):
    generale = leggi_generale()
    for p in generale["progetti"]:
        if p["nome"] == nome:
            if os.path.isdir(p["cartella"]):
                raise Errore(f"La cartella del progetto «{nome}» esiste: il progetto resta nell'elenco.")
            generale["progetti"].remove(p)
            scrivi_json(GENERALE, generale)
            return
    raise Errore(f"Progetto «{nome}» non trovato.")


def controlla_audio(percorso):
    """Controlla che il file si possa leggere e contenga audio (un file rovinato o un video senza
    audio farebbero fallire la trascrizione ogni volta)."""
    nome = os.path.basename(percorso)
    try:
        with open(percorso, "rb"):
            pass
    except PermissionError as e:
        if sys.platform == "darwin":
            aiuto = ("Il Mac non permette al Terminale di leggere questa cartella: in Impostazioni di Sistema › "
                     "Privacy e sicurezza › File e cartelle › Terminale attiva la cartella (es. Download o "
                     "Volumi rimovibili), poi riprova.")
        else:
            aiuto = "Forse è aperto in un altro programma o è protetto: chiudilo o copialo altrove, poi riprova."
        raise Errore(f"Non ho il permesso di leggere il file «{nome}».\n{aiuto}") from e
    except OSError as e:
        raise Errore(f"File audio non trovato:\n{percorso}") from e
    try:
        import av  # PyAV, installato con Whisper
    except ImportError:
        return
    try:
        with av.open(percorso) as contenitore:
            if not contenitore.streams.audio:
                raise Errore(f"Il file «{nome}» non contiene audio. Scegli un altro file.")
            next(contenitore.decode(audio=0))  # si prova a leggere l'inizio dell'audio
    except Errore:
        raise
    except Exception as e:  # noqa: BLE001 — qualsiasi errore di lettura vale «non leggibile»
        raise Errore(f"Il file «{nome}» non è un audio leggibile: forse è danneggiato o di un tipo "
                     "non supportato. Scegli un altro file.") from e


def imposta_audio(percorso):
    progetto = leggi_in_corso()
    controlla_audio(percorso)
    estensione = os.path.splitext(percorso)[1].lower()
    nome = f"{os.path.basename(progetto['cartella'])}_audio{estensione}"
    destinazione = os.path.join(progetto["cartella"], nome)
    if not (os.path.exists(destinazione) and os.path.samefile(percorso, destinazione)):
        shutil.copyfile(percorso, destinazione)
    precedente = progetto["file"].get("audio")
    if precedente and precedente != nome:  # l'audio di prima (altro tipo di file) non serve più
        try:
            os.remove(os.path.join(progetto["cartella"], precedente))
        except OSError:
            pass
    progetto["file"]["audio"] = nome
    progetto["audio_originale"] = os.path.abspath(percorso)
    salva(progetto)


def campo(chiave):
    progetto = leggi_in_corso()
    if chiave in progetto.get("file", {}):
        valore = progetto["file"][chiave]
        print(os.path.join(progetto["cartella"], valore) if valore else "")
    elif chiave in progetto:
        print(progetto[chiave])
    else:
        raise Errore(f"Dato sconosciuto: {chiave}")


def stato(valore):
    progetto = leggi_in_corso()
    progetto["stato"] = valore
    salva(progetto)


def chiudi():
    if os.path.exists(IN_CORSO):
        os.remove(IN_CORSO)


def migra(vecchia):
    """Sposta nella cartella dei progetti quelli di una versione precedente (altra cartella)."""
    vecchia = os.path.abspath(vecchia)
    vecchio_generale = os.path.join(vecchia, "elenco-progetti.json")
    if vecchia == CARTELLA or not os.path.exists(vecchio_generale):
        return
    with open(vecchio_generale, encoding="utf-8") as f:
        vecchi = json.load(f).get("progetti", [])
    generale = leggi_generale()
    if generale["progetti"]:
        raise Errore(f"Ci sono già progetti nella nuova cartella: quelli precedenti restano in {vecchia}")
    rimasti = []
    for p in vecchi:
        sorgente = p.get("cartella") or ""
        if not os.path.isdir(sorgente):
            sorgente = os.path.join(vecchia, os.path.basename(sorgente))
        destinazione = os.path.join(CARTELLA, os.path.basename(sorgente))
        if not os.path.isdir(sorgente) or os.path.exists(destinazione):
            rimasti.append(p)  # mancante, o c'è già una cartella con quel nome: resta dov'è
            continue
        shutil.move(sorgente, destinazione)
        p["cartella"] = destinazione
        generale["progetti"].append(p)
        generale["progetti"].sort(key=lambda p: p["numero"])
        scrivi_json(GENERALE, generale)  # subito: se qualcosa si interrompe, nessun progetto si perde
    if rimasti:  # i progetti non spostati restano registrati nella cartella vecchia
        with open(vecchio_generale, encoding="utf-8") as f:
            vecchio = json.load(f)
        vecchio["progetti"] = rimasti
        scrivi_json(vecchio_generale, vecchio)
        print(f"Progetti spostati in {CARTELLA}: {len(generale['progetti'])}; "
              f"rimasti in {vecchia}: {len(rimasti)}")
        return
    for nome in ("elenco-progetti.json", "progetto-in-corso.json"):
        if os.path.exists(os.path.join(vecchia, nome)):
            os.remove(os.path.join(vecchia, nome))
    try:
        os.rmdir(vecchia)  # solo se è rimasta vuota
    except OSError:
        pass
    print(f"Progetti spostati in {CARTELLA}: {len(generale['progetti'])}")


if __name__ == "__main__":
    comandi = {"elenco": lambda *a: elenco("--trascritti" in a), "crea": crea, "seleziona": seleziona,
               "togli": togli, "imposta-audio": imposta_audio, "controlla-audio": controlla_audio,
               "campo": campo, "stato": stato, "chiudi": chiudi, "migra": migra}
    if len(sys.argv) < 2 or sys.argv[1] not in comandi:
        print(__doc__)
        sys.exit(1)
    try:
        comandi[sys.argv[1]](*sys.argv[2:])
    except Errore as e:
        print(e, file=sys.stderr)
        sys.exit(e.codice)
