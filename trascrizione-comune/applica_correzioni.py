"""Applica le correzioni scritte nel file di controllo (righe «PAROLA 001: ...»).

Usato alla fine di ogni trascrizione e dalla schermata di controllo (schermata_controllo.py),
quando si apre e quando si preme «Salva»:
- crea NOME_trascrizione_corretta.txt (le parole non ancora verificate restano tra asterischi);
- aggiorna il dizionario personale: «sbagliata → giusta» per le correzioni e «parola → parola»
  per le conferme, così le trascrizioni future le usano. Ogni voce del file di controllo viene
  imparata una volta sola (le voci imparate sono annotate nel file _dati.json): una riga
  cancellata a mano dal dizionario non ricompare;
- salva i ritagli corretti, con il testo giusto, nella cartella degli esempi.
Si può rilanciare quante volte si vuole: riparte sempre dalla trascrizione originale (file _dati.json).
"""
import copy
import json
import os
import re
import shutil
import sys

if sys.platform == "win32":
    SUPPORTO = os.path.join(os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "TrascriviAudio")
else:
    SUPPORTO = os.path.join(os.path.expanduser("~"), "Library", "Application Support", "TrascriviAudio")
DIZIONARIO = os.environ.get("DIZIONARIO") or os.path.join(SUPPORTO, "dizionario.txt")
ESEMPI = os.environ.get("ESEMPI") or os.path.join(SUPPORTO, "esempi")
RIGA_PAROLA = re.compile(r"^\s*PAROLA\s+(\d+)\s*:(.*)$")
FRECCIA = re.compile(r"\s*(?:→|->)\s*")  # «sbagliata → giusta» (scrivendo a mano si può usare ->)
INTESTAZIONE = [
    "# Dizionario personale di Trascrivi Audio: «parola sentita male → parola giusta».",
    "# «parola → parola» = parola confermata: nelle prossime trascrizioni non verrà più segnata.",
    "# Si può modificare a mano (anche cancellare righe; al posto di → si può scrivere ->).",
    "# Le righe che iniziano con # sono ignorate.",
]
APOSTROFI = str.maketrans({"’": "'", "‘": "'", "ʼ": "'"})  # l'apostrofo tipografico vale come '

norm = lambda t: re.sub(r"[^\w']", "", t.lower().translate(APOSTROFI))  # senza maiuscole né punteggiatura
nucleo = lambda t: re.sub(r"^[^\w']+|[^\w']+$", "", t) or t  # senza punteggiatura iniziale e finale


def leggi_testo(percorso):
    """Testo di un file che si può modificare a mano: UTF-8 (anche con BOM) oppure, se è stato
    salvato con la codifica di Windows (ANSI), quella."""
    with open(percorso, "rb") as f:
        contenuto = f.read()
    try:
        return contenuto.decode("utf-8-sig")
    except UnicodeDecodeError:
        return contenuto.decode("cp1252", errors="replace")


def scrivi_testo(percorso, testo):
    """Scrive un file in modo sicuro: prima una copia temporanea, poi la sostituzione (se il
    programma si interrompe a metà, il file di prima resta intero)."""
    os.makedirs(os.path.dirname(percorso) or ".", exist_ok=True)
    temporaneo = percorso + ".tmp"
    with open(temporaneo, "w", encoding="utf-8") as f:
        f.write(testo)
    os.replace(temporaneo, percorso)


def voce_dizionario(riga):
    """(sbagliata, giusta) di una riga del dizionario; None per i commenti e le altre righe."""
    if riga.lstrip().startswith("#"):
        return None
    parti = FRECCIA.split(riga.strip(), maxsplit=1)
    if len(parti) == 2 and norm(parti[0]) and parti[1]:
        return parti[0], parti[1]
    return None


def leggi_dizionario():
    """{sbagliata senza maiuscole e punteggiatura: giusta} dal dizionario (vale l'ultima riga)."""
    voci = {}
    if os.path.exists(DIZIONARIO):
        for riga in leggi_testo(DIZIONARIO).splitlines():
            voce = voce_dizionario(riga)
            if voce:
                voci[norm(voce[0])] = voce[1]
    return voci


def aggiorna_dizionario(nuove):
    """Scrive nel dizionario le voci {sbagliata: giusta}: cambia le righe che ci sono già e aggiunge
    le altre in fondo, lasciando com'è tutto il resto (commenti, righe scritte a mano).
    Restituisce quante voci sono nuove o cambiate."""
    esiste = os.path.exists(DIZIONARIO)
    righe = leggi_testo(DIZIONARIO).splitlines() if esiste else list(INTESTAZIONE)
    dove = {}
    for i, riga in enumerate(righe):
        voce = voce_dizionario(riga)
        if voce:
            dove[norm(voce[0])] = i
    cambiate = 0
    for sbagliata, giusta in nuove.items():
        i = dove.get(norm(sbagliata))
        if i is not None and voce_dizionario(righe[i])[1] == giusta:
            continue
        riga = f"{sbagliata} → {giusta}"
        if i is None:
            dove[norm(sbagliata)] = len(righe)
            righe.append(riga)
        else:
            righe[i] = riga
        cambiate += 1
    if cambiate or not esiste:
        scrivi_testo(DIZIONARIO, "\n".join(righe) + "\n")
    return cambiate


def percorsi(file_controllo):
    """Dal file NOME_controllo.txt ricava i file NOME_dati.json e NOME_trascrizione_corretta.txt."""
    cartella, nome = os.path.split(file_controllo)
    base = nome[:-4] if nome.endswith(".txt") else nome
    if "_controllo" not in base:
        raise ValueError("Il nome del file deve contenere «_controllo» e finire con .txt.")
    prima, _, dopo = base.rpartition("_controllo")  # l'ultima: il nome del progetto potrebbe contenerla
    dati = os.path.join(cartella, f"{prima}_dati{dopo}.json")
    corretta = os.path.join(cartella, f"{prima}_trascrizione_corretta{dopo}.txt")
    return dati, corretta


def leggi_parole_scritte(file_controllo):
    """Righe «PAROLA 001: valore» del file di controllo → {"001": "valore"}."""
    scritte = {}
    for riga in leggi_testo(file_controllo).splitlines():
        m = RIGA_PAROLA.match(riga)
        if m:
            scritte[m.group(1).zfill(3)] = m.group(2).strip()
    return scritte


def minuscola_iniziale(parola):
    """«Perché» → «perché» (non le sigle come «INPS»)."""
    if parola[:1].isupper() and not parola[1:2].isupper():
        return parola[0].lower() + parola[1:]
    return parola


def da_imparare(parole, i, valore):
    """La riga del dizionario per la parola i corretta (o confermata) con valore: senza la
    punteggiatura di questa frase e, a inizio frase, senza la maiuscola dovuta alla posizione
    (altrimenti «Perché» finirebbe con la maiuscola anche a metà frase)."""
    sbagliata, giusta = nucleo(parole[i]["testo"]), nucleo(valore)
    if i == 0 or parole[i - 1]["testo"].rstrip()[-1:] in ".!?…":
        sbagliata, giusta = minuscola_iniziale(sbagliata), minuscola_iniziale(giusta)
    return sbagliata, giusta


def applica(file_controllo):
    file_dati, file_corretta = percorsi(file_controllo)
    if not os.path.exists(file_dati):
        raise FileNotFoundError(f"Non trovo il file {os.path.basename(file_dati)} accanto al file di controllo. "
                                "Serve per applicare le correzioni: non spostarlo e non rinominarlo.")
    with open(file_dati, encoding="utf-8") as f:
        dati = json.load(f)
    parole = copy.deepcopy(dati["parole"])  # nel file dati resta la trascrizione originale
    gia_imparate = set(dati.get("imparate", []))
    cartella = os.path.dirname(file_controllo)
    nome_audio = os.path.splitext(os.path.basename(dati["audio"]))[0]
    scritte = leggi_parole_scritte(file_controllo)

    corrette, confermate, rimaste, mancanti, imparate, nuove_voci = 0, 0, 0, [], {}, []
    segnate = set()
    for numero, voce in dati["voci"].items():
        i = voce["indice"]
        if numero not in scritte:
            mancanti.append(numero)
            segnate.add(i)
            continue
        valore = scritte[numero]
        if "*" in valore:  # non ancora verificata
            rimaste += 1
            segnate.add(i)
            continue
        originale = parole[i]["testo"]
        nuova = numero not in gia_imparate  # ogni voce si impara una volta sola
        if nuova:
            nuove_voci.append(numero)
            if valore:  # «x → x» = parola confermata, da non segnare più
                sbagliata, giusta = da_imparare(parole, i, valore)
                imparate[sbagliata] = giusta
        if valore == originale:
            confermate += 1
            continue
        corrette += 1
        spazio = parole[i]["raw"][:len(parole[i]["raw"]) - len(parole[i]["raw"].lstrip())]  # «Ehlers-Danlos»
        parole[i]["testo"], parole[i]["raw"] = valore, (spazio + valore if valore else "")
        # Esempio per il futuro: ritaglio audio + testo giusto di quel tratto
        clip = os.path.join(cartella, dati["cartella_clip"], voce["clip"])
        if nuova and os.path.exists(clip):
            os.makedirs(ESEMPI, exist_ok=True)
            nome = f"{nome_audio}_{voce['clip'][:-4]}"
            shutil.copyfile(clip, os.path.join(ESEMPI, nome + ".wav"))
            t0, t1 = parole[i]["start"] - 3, parole[i]["end"] + 3
            tratto = "".join(p["raw"] for p in parole if t0 <= p["start"] and p["end"] <= t1).strip()
            scrivi_testo(os.path.join(ESEMPI, nome + ".txt"), f"parola: {originale} → {valore}\ntesto: {tratto}\n")

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
    scrivi_testo(file_corretta, "\n".join(r for r in righe if r) + "\n")

    # Dizionario personale, usato dalle prossime trascrizioni; poi le voci imparate nel file dati
    nuove = aggiorna_dizionario(imparate) if imparate else 0
    if nuove_voci:
        dati["imparate"] = sorted(gia_imparate | set(nuove_voci))
        scrivi_testo(file_dati, json.dumps(dati, ensure_ascii=False, indent=1))

    return {"corrette": corrette, "confermate": confermate, "rimaste": rimaste + len(mancanti),
            "nuove": nuove, "mancanti": mancanti, "trascrizione_corretta": file_corretta}


if __name__ == "__main__":
    r = applica(sys.argv[1])
    print(f"{r['corrette']}|{r['confermate']}|{r['rimaste']}|{r['nuove']}|{','.join(r['mancanti'])}")
