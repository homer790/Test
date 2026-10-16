"""Trascrizione con parole dubbie segnate (usato dal programma su Mac e su Windows).

uso: trascrivi_dubbi.py AUDIO TRASCRIZIONE CONTROLLO DATI CARTELLA_CLIP
Impostazioni dalle variabili d'ambiente MODELLO_A, MODELLO_B, MODELLO_C, SOGLIA, LINGUA,
RIASCOLTO, CARTELLA_MODELLI e DIZIONARIO (vedi Trascrivi-Audio.command e TrascriviAudio.ps1).
"""
import difflib
import json
import os
import re
import sys
import time
import wave

from faster_whisper import WhisperModel
from faster_whisper.audio import decode_audio

import applica_correzioni
from applica_correzioni import leggi_dizionario, norm, nucleo
from modelli import tieni_sveglio

audio, file_trascrizione, file_controllo, file_dati, cartella_clip = sys.argv[1:6]
MODELLO_A = os.environ.get("MODELLO_A", "large-v3")
MODELLO_B = os.environ.get("MODELLO_B", "medium")
MODELLO_C = os.environ.get("MODELLO_C", "") or MODELLO_B  # terzo ascolto delle frasi ancora dubbie
SOGLIA = float(os.environ.get("SOGLIA", "0.6"))
LINGUA = os.environ.get("LINGUA", "it") or None
RIASCOLTO = os.environ.get("RIASCOLTO", "1") != "0"
CARTELLA_MODELLI = os.environ.get("CARTELLA_MODELLI")
FREQ = 16000        # campioni al secondo dell'audio decodificato
MARGINE = 0.5       # secondi aggiunti prima e dopo ogni frase riascoltata
MARGINE_CLIP = 3.0  # secondi aggiunti prima e dopo ogni parola nei ritagli per l'ascolto manuale
FASI = 4 if RIASCOLTO else 2


def tempo(secondi):
    s = int(secondi)
    return f"{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d}"


# Parole brevi (e/è, a/ha, o/ho, ce/c'è...): se sono giuste dipende dalla frase, quindi una
# correzione fatta una volta non viene applicata da sola alle trascrizioni successive
PAROLA_BREVE = 3


def dipende_dalla_frase(sbagliata, giusta):
    """Correzioni giuste solo in certe frasi, che non si applicano da sole: parole brevi
    e coppie che differiscono solo per l'acca iniziale (anno/hanno)."""
    s, g = norm(sbagliata), norm(giusta)
    return len(s) <= PAROLA_BREVE or s == "h" + g or g == "h" + s


def con_punteggiatura(originale, giusta):
    """La parola giusta con la punteggiatura (e la maiuscola iniziale) della parola originale:
    «racu.» con la correzione «raku» diventa «raku.», non «raku,» come la volta in cui è stata corretta."""
    prima, centro, dopo = re.match(r"^([^\w']*)(.*?)([^\w']*)$", originale).groups()
    nuova = nucleo(giusta) or giusta
    if centro[:1].isupper() and nuova[:1].islower():
        nuova = nuova[0].upper() + nuova[1:]
    return prima + nuova + dopo


# Dizionario personale, aggiornato dalla schermata di controllo: righe «sbagliata → giusta»
correzioni_note = leggi_dizionario()
# Parole già verificate da te (confermate, o forma giusta di una correzione che non dipende dalla
# frase): non vanno più segnate
verificate = {norm(g) for s, g in correzioni_note.items() if norm(g) == s or not dipende_dalla_frase(s, g)}


def da_suggerire(parole):
    """Parole senza punteggiatura (una virgola finale farebbe iniziare la trascrizione in minuscolo),
    senza doppioni e senza parole brevi (spingerebbero Whisper a scriverle dove non servono)."""
    return list(dict.fromkeys(nucleo(g) for g in parole if len(norm(g)) > PAROLA_BREVE))


# Parole suggerite a Whisper (al massimo 40, le più recenti): prima le tue correzioni, poi le conferme
corrette = da_suggerire(g for s, g in correzioni_note.items() if norm(g) != s and not dipende_dalla_frase(s, g))[-40:]
confermate = [g for g in da_suggerire(g for s, g in correzioni_note.items() if norm(g) == s) if g not in corrette]
suggerimenti = " ".join((confermate[-(40 - len(corrette)):] if len(corrette) < 40 else []) + corrette) or None


class Parola:
    def __init__(self, seg, w):
        self.seg = seg
        self.raw = w.word  # con lo spazio iniziale originale, per il testo pulito
        self.testo, self.start, self.end, self.prob = w.word.strip(), w.start, w.end, w.probability
        self.alternativa = None  # cosa ha sentito il modello di confronto, se diverso
        self.medio = ""          # cosa ha sentito il modello di confronto nello stesso punto
        self.riascolto_a = ""
        self.risolta = None      # come è stato risolto il dubbio
        self.note = []

    def sostituisci(self, nuovo):
        spazio = self.raw[:len(self.raw) - len(self.raw.lstrip())]  # parola attaccata alla precedente: resta così
        self.testo, self.raw = nuovo, spazio + nuovo


def carica(nome_modello, fase):
    print(f"\n[{fase}/{FASI}] Carico il modello {nome_modello} "
          "(la prima volta viene scaricato, può volerci molto)...", flush=True)
    return WhisperModel(nome_modello, device="cpu", compute_type="int8", download_root=CARTELLA_MODELLI)


def trascrivi(modello, nome_modello, fase):
    segmenti, info = modello.transcribe(audio, language=LINGUA, word_timestamps=True, beam_size=5,
                                        vad_filter=True, hotwords=suggerimenti)
    durata = info.duration or 1
    inizio = time.time()
    parole, frasi = [], {}
    for n, seg in enumerate(segmenti):
        frasi[n] = (seg.start, seg.end)
        for w in seg.words or []:
            parole.append(Parola(n, w))
        print(f"\r[{fase}/{FASI}] {nome_modello}: {min(seg.end / durata, 1):6.1%} "
              f"({tempo(seg.end)} di {tempo(durata)})", end="", flush=True)
    print(f"\n[{fase}/{FASI}] {nome_modello} completato in {tempo(time.time() - inizio)}.", flush=True)
    return parole, frasi


def nello_stesso_punto(parole, p):
    """Testo delle parole (start, end, testo) che cadono nello stesso punto dell'audio della parola p:
    quelle che stanno per più di metà dentro p. Così ogni parola appartiene a una sola parola di p:
    se il confronto è incerto (es. «ne anche» contro «neanche») la parola resta da verificare,
    invece di essere sostituita due volte («neanche neanche»)."""
    return " ".join(t for s, e, t in parole if min(e, p.end) - max(s, p.start) > 0.5 * max(e - s, 0.01))


def dubbia(p):
    return p.risolta is None and (p.prob < SOGLIA or p.alternativa is not None)


def riascolta(modello, nome_modello, fase, campioni, frasi_da_rifare, contesto):
    """Riascolta solo le frasi indicate, ritagliate dall'audio. Restituisce {frase: [(start, end, testo)]}."""
    durata_audio = len(campioni) / FREQ
    risultato = {}
    for k, n in enumerate(frasi_da_rifare, 1):
        print(f"\r[{fase}/{FASI}] Riascolto con {nome_modello}: frase {k} di {len(frasi_da_rifare)}",
              end="", flush=True)
        s0, s1 = frasi[n]
        t0, t1 = max(0.0, s0 - MARGINE), min(durata_audio, s1 + MARGINE)
        segmenti, _ = modello.transcribe(
            campioni[int(t0 * FREQ):int(t1 * FREQ)], language=LINGUA, word_timestamps=True,
            beam_size=10, best_of=5, initial_prompt=contesto(n) or None, hotwords=suggerimenti,
            condition_on_previous_text=False, vad_filter=False)
        risultato[n] = [(w.start + t0, w.end + t0, w.word.strip())
                        for seg in segmenti for w in (seg.words or [])]
    print(flush=True)
    return risultato


def applica(p, sentito, come, esatto=False):
    """Risolve il dubbio sulla parola p con quanto «sentito»: la parola cambia se è diversa
    (con esatto=True conta anche una differenza di maiuscole, es. milano → Milano)."""
    if (sentito != p.testo) if esatto else (norm(sentito) != norm(p.testo)):
        p.note.append(f"corretta: «{p.testo}» → «{sentito}» ({come})")
        p.sostituisci(sentito)
    else:
        p.note.append(f"confermata: «{p.testo}» ({come})")
    p.risolta = come


# --- 1° e 2° ascolto: due modelli diversi sull'intero audio
tieni_sveglio()  # una trascrizione può durare ore: il computer non deve andare in stop
modello_a = carica(MODELLO_A, 1)
a, frasi = trascrivi(modello_a, MODELLO_A, 1)
modello_b = carica(MODELLO_B, 2)
b, _ = trascrivi(modello_b, MODELLO_B, 2)

sm = difflib.SequenceMatcher(a=[norm(p.testo) for p in a], b=[norm(p.testo) for p in b], autojunk=False)
for op, i1, i2, j1, j2 in sm.get_opcodes():
    if op in ("replace", "delete"):
        sentito = " ".join(p.testo for p in b[j1:j2]) or "(niente)"
        for i in range(i1, i2):
            a[i].alternativa = sentito
parole_b = [(p.start, p.end, p.testo) for p in b]
for p in a:
    p.medio = nello_stesso_punto(parole_b, p)

# Dizionario personale, solo per le parole dubbie (quelle sicure e uguali per i due modelli non si
# toccano): errori già corretti a mano (non quelli che dipendono dalla frase) e parole già verificate
for p in a:
    if p.prob >= SOGLIA and p.alternativa is None:
        continue
    giusta = correzioni_note.get(norm(p.testo))
    if giusta and nucleo(giusta) != nucleo(p.testo):  # correzione, anche solo di maiuscole
        if not dipende_dalla_frase(p.testo, giusta):
            applica(p, con_punteggiatura(p.testo, giusta), "dal tuo dizionario", esatto=True)
    elif norm(p.testo) in verificate:
        applica(p, p.testo, "già verificata da te")

dubbie_iniziali = sum(dubbia(p) for p in a)
contesto = lambda n: " ".join(p.testo for p in a if p.seg == n - 1)  # la frase precedente aiuta il modello
campioni = decode_audio(audio, sampling_rate=FREQ)

# --- Riascolto delle sole frasi con parole dubbie
if RIASCOLTO and dubbie_iniziali:
    # 3° ascolto: large riascolta; se coincide con quanto sentito da medium, il dubbio è risolto
    frasi_dubbie = sorted({p.seg for p in a if dubbia(p)})
    print(f"\n[3/{FASI}] {len(frasi_dubbie)} frasi con parole dubbie da riascoltare", flush=True)
    riascolto_a = riascolta(modello_a, MODELLO_A, 3, campioni, frasi_dubbie, contesto)
    for p in a:
        if dubbia(p):
            p.riascolto_a = nello_stesso_punto(riascolto_a[p.seg], p)
            p.note.append(f"riascolto {MODELLO_A}: «{p.riascolto_a or '(niente)'}»")
            if p.riascolto_a and norm(p.riascolto_a) == norm(p.medio):
                applica(p, p.riascolto_a, f"riascolto {MODELLO_A} = {MODELLO_B}")

    # 4° ascolto: dove ancora non coincidono, ascolta di nuovo con il modello C
    frasi_dubbie = sorted({p.seg for p in a if dubbia(p)})
    if frasi_dubbie:
        if MODELLO_C != MODELLO_B:
            del modello_b
            modello_b = carica(MODELLO_C, 4)
        riascolto_c = riascolta(modello_b, MODELLO_C, 4, campioni, frasi_dubbie, contesto)
        for p in a:
            if dubbia(p):
                sentito_c = nello_stesso_punto(riascolto_c[p.seg], p)
                p.note.append(f"riascolto {MODELLO_C}: «{sentito_c or '(niente)'}»")
                if p.riascolto_a and norm(sentito_c) == norm(p.riascolto_a):
                    applica(p, p.riascolto_a, f"riascolto {MODELLO_A} = riascolto {MODELLO_C}")

# --- Ritagli audio (3 secondi prima e dopo) per le parole ancora dubbie
dubbie = [i for i, p in enumerate(a) if dubbia(p)]
os.makedirs(cartella_clip, exist_ok=True)
durata_audio = len(campioni) / FREQ
voci = {}  # numero voce -> indice parola
for numero, i in enumerate(dubbie, 1):
    p = a[i]
    t0, t1 = max(0.0, p.start - MARGINE_CLIP), min(durata_audio, p.end + MARGINE_CLIP)
    pezzo = (campioni[int(t0 * FREQ):int(t1 * FREQ)].clip(-1, 1) * 32767).astype("<i2")
    nome_clip = f"{numero:03d}_{tempo(p.start).replace(':', '-')}.wav"
    with wave.open(os.path.join(cartella_clip, nome_clip), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(FREQ)
        w.writeframes(pezzo.tobytes())
    voci[f"{numero:03d}"] = {"indice": i, "clip": nome_clip}

# --- Risultati
def testo_pulito(parole):
    righe, riga, corrente = [], [], None
    for p in parole:
        if p.seg != corrente and riga:
            righe.append("".join(riga).strip())
            riga = []
        corrente = p.seg
        riga.append(p.raw)
    if riga:
        righe.append("".join(riga).strip())
    return "\n".join(righe) + "\n"


def segna(p):
    if not dubbia(p):
        return p.testo
    return f"**{p.testo}**" if p.prob < SOGLIA and p.alternativa is not None else f"*{p.testo}*"


righe_segnate, riga, corrente = [], [], None
for p in a:
    if p.seg != corrente:
        if riga:
            righe_segnate.append(" ".join(riga))
        riga, corrente = [f"[{tempo(frasi[p.seg][0])}]"], p.seg
    riga.append(segna(p))
if riga:
    righe_segnate.append(" ".join(riga))

risolte = [f"{tempo(p.start)}  {p.note[-1]}" for p in a if p.risolta]

with open(file_trascrizione, "w", encoding="utf-8") as f:
    f.write(testo_pulito(a))

with open(file_dati, "w", encoding="utf-8") as f:
    json.dump({"audio": audio, "trascrizione": os.path.basename(file_trascrizione),
               "cartella_clip": os.path.basename(cartella_clip), "voci": voci,
               "parole": [{"seg": p.seg, "raw": p.raw, "testo": p.testo, "start": p.start, "end": p.end}
                          for p in a]}, f, ensure_ascii=False, indent=1)

with open(file_controllo, "w", encoding="utf-8") as f:
    f.write(f"FILE DI CONTROLLO – {os.path.basename(audio)}\n")
    f.write(f"Creato il {time.strftime('%d/%m/%Y alle %H:%M')}\n")
    f.write(f"Modello principale: {MODELLO_A} – confronto: {MODELLO_B} – terzo ascolto: {MODELLO_C} – "
            f"soglia di sicurezza: {SOGLIA}\n\n")
    f.write("COME CORREGGERE\n")
    f.write("  Apri Trascrivi Audio, scegli «Apri un progetto», questo progetto e «Analisi delle parole»:\n")
    f.write("  nella schermata di controllo ascolti il ritaglio di ogni parola, la correggi, spunti\n")
    f.write("  «Confermata» e premi «Salva». Le correzioni vengono scritte qui, nelle righe «PAROLA».\n")
    f.write(f"  (I ritagli audio sono nella cartella «{os.path.basename(cartella_clip)}», con lo stesso numero\n")
    f.write("  della voce qui sotto.)\n\n")
    f.write("LEGENDA\n")
    f.write("  *parola*    da controllare: sicurezza bassa OPPURE i modelli non concordano\n")
    f.write("  **parola**  da controllare per prima: sicurezza bassa E i modelli non concordano\n\n")
    f.write(f"Parole da riverificare: {len(dubbie)} su {len(a)}\n")
    f.write(f"(prima del riascolto erano {dubbie_iniziali}, {len(risolte)} risolte automaticamente)\n\n")
    f.write("=" * 70 + "\nPAROLE DA RIASCOLTARE E CORREGGERE\n" + "=" * 70 + "\n")
    if not dubbie:
        f.write("Nessuna parola dubbia.\n")
    for numero, v in voci.items():
        i = v["indice"]
        p = a[i]
        prima = " ".join(x.testo for x in a[max(0, i - 6):i])
        dopo = " ".join(x.testo for x in a[i + 1:i + 7])
        dettagli = f"sicurezza {p.prob:.2f}"
        if p.alternativa is not None:  # (accorciato: con un audio disturbato può essere lunghissimo)
            alt = p.alternativa if len(p.alternativa) <= 80 else p.alternativa[:79] + "…"
            dettagli += f" – {MODELLO_B} ha sentito: «{alt}»"
        dettagli += "".join(f" – {x}" for x in p.note)
        f.write(f"\n[{numero}]  {tempo(p.start)}   ritaglio: {v['clip']}\n")
        f.write(f"       contesto: …{prima} [{p.testo}] {dopo}…\n")
        f.write(f"       {dettagli}\n")
        f.write(f"PAROLA {numero}: {segna(p)}\n")
    f.write("\n" + "=" * 70 + "\nTESTO CON LE PAROLE SEGNATE (solo da leggere)\n" + "=" * 70 + "\n")
    f.write("\n".join(righe_segnate) + "\n")
    f.write("\n" + "=" * 70 + "\nRISOLTE AUTOMATICAMENTE (per controllo)\n" + "=" * 70 + "\n")
    f.write("\n".join(risolte) if risolte else "Nessuna.")
    f.write("\n")

# Trascrizione corretta subito disponibile (uguale alla trascrizione, con le parole dubbie segnate)
try:
    applica_correzioni.applica(file_controllo)
except Exception as e:  # noqa: BLE001 — si potrà creare dalla schermata di controllo
    print(f"Attenzione: trascrizione corretta non creata ({e})", flush=True)

print(f"\nParole da riverificare: {len(dubbie)} su {len(a)} (prima del riascolto: {dubbie_iniziali})")
