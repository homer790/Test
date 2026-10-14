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
  progetti.py seleziona NOME          rende NOME il progetto in corso
  progetti.py imposta-audio PERCORSO  copia l'audio sorgente nel progetto in corso
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

CARTELLA = os.path.abspath(os.environ.get("CARTELLA_PROGETTI")
                           or os.path.expanduser("~/Documents/Trascrivi Audio/Progetti"))
GENERALE = os.path.join(CARTELLA, "elenco-progetti.json")
IN_CORSO = os.path.join(CARTELLA, "progetto-in-corso.json")
MASSIMO = 999


class Errore(Exception):
    pass


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
    with open(GENERALE, encoding="utf-8") as f:
        return json.load(f)


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
    return f"{numero}_{compatto or 'Progetto'}"


def elenco(solo_trascritti=False):
    for p in leggi_generale()["progetti"]:
        if not solo_trascritti or p.get("stato") == "trascritto":
            print(p["nome"])


def crea(nome):
    nome = re.sub(r"\s+", " ", nome).strip()
    if not nome:
        raise Errore("Il nome del progetto non può essere vuoto.")
    if len(nome) > 60:
        raise Errore("Il nome del progetto è troppo lungo (massimo 60 caratteri).")
    generale = leggi_generale()
    if any(p["nome"].lower() == nome.lower() for p in generale["progetti"]):
        raise Errore(f"Esiste già un progetto chiamato «{nome}». Scegli un altro nome.")
    usati = {int(p["numero"]) for p in generale["progetti"]}
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
                raise Errore(f"La cartella del progetto «{nome}» non esiste più:\n{p['cartella']}")
            scrivi_json(IN_CORSO, p)
            print(p["cartella"])
            return
    raise Errore(f"Progetto «{nome}» non trovato.")


def imposta_audio(percorso):
    progetto = leggi_in_corso()
    if not os.path.isfile(percorso):
        raise Errore(f"File audio non trovato: {percorso}")
    estensione = os.path.splitext(percorso)[1].lower()
    nome = f"{os.path.basename(progetto['cartella'])}_audio{estensione}"
    shutil.copyfile(percorso, os.path.join(progetto["cartella"], nome))
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
    for p in vecchi:
        sorgente = p.get("cartella") or ""
        if not os.path.isdir(sorgente):
            sorgente = os.path.join(vecchia, os.path.basename(sorgente))
        if not os.path.isdir(sorgente):
            continue
        destinazione = os.path.join(CARTELLA, os.path.basename(sorgente))
        shutil.move(sorgente, destinazione)
        p["cartella"] = destinazione
        generale["progetti"].append(p)
    generale["progetti"].sort(key=lambda p: p["numero"])
    scrivi_json(GENERALE, generale)
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
               "imposta-audio": imposta_audio, "campo": campo, "stato": stato, "chiudi": chiudi,
               "migra": migra}
    if len(sys.argv) < 2 or sys.argv[1] not in comandi:
        print(__doc__)
        sys.exit(1)
    try:
        comandi[sys.argv[1]](*sys.argv[2:])
    except Errore as e:
        print(e, file=sys.stderr)
        sys.exit(2)
