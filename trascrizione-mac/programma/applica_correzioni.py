"""Applica le correzioni scritte nel file di controllo (righe «PAROLA 001: ...»).

Usato da Applica-Correzioni.command e dalla schermata di controllo (schermata_controllo.py).
- crea NOME_trascrizione_corretta.txt;
- aggiorna il dizionario personale: «sbagliata → giusta» per le correzioni e
  «parola → parola» per le conferme, così le trascrizioni future le usano;
- salva i ritagli corretti, con il testo giusto, nella cartella degli esempi.
Si può rilanciare quante volte si vuole: riparte sempre dalla trascrizione originale (file _dati.json).
"""
import json
import os
import re
import shutil
import sys

SUPPORTO = os.path.join(os.path.expanduser("~"), "Library", "Application Support", "TrascriviAudio")
DIZIONARIO = os.environ.get("DIZIONARIO") or os.path.join(SUPPORTO, "dizionario.txt")
ESEMPI = os.environ.get("ESEMPI") or os.path.join(SUPPORTO, "esempi")
RIGA_PAROLA = re.compile(r"^\s*PAROLA\s+(\d+)\s*:(.*)$")

norm = lambda t: re.sub(r"[^\w']", "", t.lower())


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
    with open(file_controllo, encoding="utf-8") as f:
        for riga in f:
            m = RIGA_PAROLA.match(riga)
            if m:
                scritte[m.group(1).zfill(3)] = m.group(2).strip()
    return scritte


def applica(file_controllo):
    file_dati, file_corretta = percorsi(file_controllo)
    if not os.path.exists(file_dati):
        raise FileNotFoundError(f"Non trovo il file {os.path.basename(file_dati)} accanto al file di controllo. "
                                "Serve per applicare le correzioni: non spostarlo e non rinominarlo.")
    with open(file_dati, encoding="utf-8") as f:
        dati = json.load(f)
    parole = dati["parole"]
    cartella = os.path.dirname(file_controllo)
    nome_audio = os.path.splitext(os.path.basename(dati["audio"]))[0]
    scritte = leggi_parole_scritte(file_controllo)

    corrette, confermate, rimaste, mancanti, imparate = 0, 0, 0, [], {}
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
        if valore:
            imparate[originale] = valore  # «x → x» = parola confermata, da non segnare più
        if valore == originale:
            confermate += 1
            continue
        corrette += 1
        parole[i]["testo"], parole[i]["raw"] = valore, (" " + valore if valore else "")
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
        with open(DIZIONARIO, encoding="utf-8") as f:
            for r in f:
                if "→" in r and not r.lstrip().startswith("#"):
                    s, g = (x.strip() for x in r.split("→", 1))
                    voci_diz[s] = g
    nuove = sum(1 for s, g in imparate.items() if voci_diz.get(s) != g)
    voci_diz.update(imparate)
    os.makedirs(os.path.dirname(DIZIONARIO), exist_ok=True)
    with open(DIZIONARIO, "w", encoding="utf-8") as f:
        f.write("# Dizionario personale di Trascrivi-Audio: «parola sentita male → parola giusta».\n")
        f.write("# «parola → parola» = parola confermata: nelle prossime trascrizioni non verrà più segnata.\n")
        f.write("# Si può modificare a mano (anche cancellare righe). Le righe che iniziano con # sono ignorate.\n")
        for s, g in voci_diz.items():
            f.write(f"{s} → {g}\n")

    return {"corrette": corrette, "confermate": confermate, "rimaste": rimaste + len(mancanti),
            "nuove": nuove, "mancanti": mancanti, "trascrizione_corretta": file_corretta}


if __name__ == "__main__":
    r = applica(sys.argv[1])
    print(f"{r['corrette']}|{r['confermate']}|{r['rimaste']}|{r['nuove']}|{','.join(r['mancanti'])}")
