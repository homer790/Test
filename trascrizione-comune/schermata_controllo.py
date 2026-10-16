"""Schermata di controllo delle parole dubbie.

uso: python schermata_controllo.py NOME_controllo.txt

Avvia un piccolo server solo sul computer (127.0.0.1, non raggiungibile da fuori) e apre il
browser. Per ogni parola dubbia: audio del ritaglio, campo modificabile e casella «Confermata».
«Salva» scrive le righe PAROLA nel file di controllo, applica le correzioni (trascrizione
corretta, dizionario personale, esempi) e ricarica il file. Il server si chiude con il pulsante
«Chiudi» o pochi secondi dopo che la scheda del browser è stata chiusa.
"""
import json
import os
import platform
import re
import secrets
import subprocess
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from applica_correzioni import RIGA_PAROLA, applica, leggi_testo, percorsi  # noqa: E402

PER_PAGINA = 10
# Il server si chiude quando la pagina avvisa che la scheda è stata chiusa (dopo qualche secondo:
# se la pagina è stata solo ricaricata si rifà viva subito) oppure, per sicurezza, dopo mezz'ora
# senza notizie dalla pagina. Il tempo in cui il computer è in stop non conta: al risveglio la
# pagina deve poter salvare le modifiche fatte prima.
ATTESA_DOPO_CHIUSURA = 10
ATTESA_CHIUSURA = int(os.environ.get("ATTESA_CHIUSURA") or 30 * 60)

file_controllo = os.path.abspath(sys.argv[1])
file_dati, file_corretta = percorsi(file_controllo)
TOKEN = secrets.token_urlsafe(16)  # solo questa pagina può usare il server
blocco = threading.Lock()
ultimo_contatto = [None]
pagina_chiusa = [None]


def apri(percorso_o_url):
    """Apre un indirizzo nel browser o un file con il programma predefinito del sistema."""
    sistema = platform.system()
    if sistema == "Darwin":
        subprocess.run(["open", percorso_o_url], check=False)
    elif sistema == "Windows" and not percorso_o_url.startswith("http"):
        os.startfile(percorso_o_url)  # noqa: S606 — file del progetto, scelto dal programma
    else:
        webbrowser.open(percorso_o_url)


def leggi_voci():
    """Legge il file di controllo (e il file dati per i ritagli) e restituisce le voci da mostrare."""
    with open(file_dati, encoding="utf-8") as f:
        dati = json.load(f)
    righe = leggi_testo(file_controllo).splitlines()
    parole = dati.get("parole", [])
    voci, corrente = [], None
    for riga in righe:
        m = re.match(r"^\[(\d+)\]\s+(\S+)", riga)
        if m:
            corrente = {"numero": m.group(1).zfill(3), "tempo": m.group(2), "contesto": "", "dettagli": ""}
            continue
        if corrente is None:
            continue
        m = RIGA_PAROLA.match(riga)
        if m:
            valore = m.group(2).strip()
            corrente["valore"] = valore
            corrente["confermata"] = "*" not in valore
            corrente["stile"] = "**" if valore.startswith("**") else "*"
            voce = dati["voci"].get(corrente["numero"])
            corrente["clip"] = voce["clip"] if voce else ""
            if voce and voce["indice"] < len(parole):
                i = voce["indice"]
                corrente["prima"] = " ".join(x["testo"] for x in parole[max(0, i - 6):i])
                corrente["parola"] = parole[i]["testo"]
                corrente["dopo"] = " ".join(x["testo"] for x in parole[i + 1:i + 7])
            voci.append(corrente)
            corrente = None
        elif riga.strip().startswith("contesto:"):
            corrente["contesto"] = riga.strip()[len("contesto:"):].strip()
        elif riga.strip():
            corrente["dettagli"] = riga.strip()
    return {"titolo": os.path.basename(dati["audio"]), "file": os.path.basename(file_controllo),
            "voci": voci, "per_pagina": PER_PAGINA}


def salva(modifiche):
    """Scrive le righe PAROLA modificate nel file di controllo e applica le correzioni."""
    attuali = {v["numero"]: v for v in leggi_voci()["voci"]}
    nuove_righe = {}
    for m in modifiche:
        numero = str(m.get("numero", "")).zfill(3)
        voce = attuali.get(numero)
        if not voce or voce["confermata"]:  # le parole già confermate non si toccano più
            continue
        testo = re.sub(r"\s+", " ", str(m.get("valore", "")).replace("*", "")).strip()
        if m.get("confermata"):
            nuove_righe[numero] = f"PAROLA {numero}: {testo}".rstrip()
        elif testo:  # bozza non confermata: resta tra asterischi
            nuove_righe[numero] = f"PAROLA {numero}: {voce['stile']}{testo}{voce['stile']}"
    with open(file_controllo, encoding="utf-8") as f:
        righe = f.read().split("\n")
    for i, riga in enumerate(righe):
        m = RIGA_PAROLA.match(riga)
        if m and m.group(1).zfill(3) in nuove_righe:
            righe[i] = nuove_righe[m.group(1).zfill(3)]
    temporaneo = file_controllo + ".tmp"
    with open(temporaneo, "w", encoding="utf-8") as f:
        f.write("\n".join(righe))
    os.replace(temporaneo, file_controllo)
    risultato = applica(file_controllo)
    risultato.pop("trascrizione_corretta", None)
    return risultato


class Gestore(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def autorizzato(self):
        q = parse_qs(urlparse(self.path).query)
        return self.headers.get("X-Token") == TOKEN or q.get("t", [""])[0] == TOKEN

    def rispondi(self, codice, corpo, tipo="application/json; charset=utf-8"):
        if isinstance(corpo, (dict, list)):
            corpo = json.dumps(corpo, ensure_ascii=False)
        if isinstance(corpo, str):
            corpo = corpo.encode("utf-8")
        self.send_response(codice)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(corpo)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(corpo)

    def do_GET(self):
        percorso = urlparse(self.path).path
        if not self.autorizzato():
            return self.rispondi(403, {"errore": "accesso non autorizzato"})
        ultimo_contatto[0] = time.time()
        if percorso == "/":
            return self.rispondi(200, PAGINA.replace("@TOKEN@", TOKEN), "text/html; charset=utf-8")
        if percorso == "/api/voci":
            with blocco:
                return self.rispondi(200, leggi_voci())
        if percorso.startswith("/clip/"):
            return self.invia_clip(os.path.basename(percorso[len("/clip/"):]))
        self.rispondi(404, {"errore": "non trovato"})

    def invia_clip(self, nome):
        with open(file_dati, encoding="utf-8") as f:
            dati = json.load(f)
        if nome not in {v["clip"] for v in dati["voci"].values()}:
            return self.rispondi(404, {"errore": "ritaglio non trovato"})
        percorso = os.path.join(os.path.dirname(file_controllo), dati["cartella_clip"], nome)
        if not os.path.exists(percorso):
            return self.rispondi(404, {"errore": "ritaglio non trovato"})
        dimensione = os.path.getsize(percorso)
        inizio, fine = 0, dimensione - 1
        intervallo = re.match(r"bytes=(\d*)-(\d*)", self.headers.get("Range", ""))
        if intervallo:  # Safari chiede l'audio a pezzi
            if intervallo.group(1):
                inizio = int(intervallo.group(1))
                if intervallo.group(2):
                    fine = min(int(intervallo.group(2)), dimensione - 1)
            elif intervallo.group(2):
                inizio = max(0, dimensione - int(intervallo.group(2)))
            if inizio > fine:  # intervallo impossibile
                self.send_response(416)
                self.send_header("Content-Range", f"bytes */{dimensione}")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
        with open(percorso, "rb") as f:
            f.seek(inizio)
            corpo = f.read(fine - inizio + 1)
        self.send_response(206 if intervallo else 200)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(len(corpo)))
        if intervallo:
            self.send_header("Content-Range", f"bytes {inizio}-{fine}/{dimensione}")
        self.end_headers()
        self.wfile.write(corpo)

    def do_POST(self):
        percorso = urlparse(self.path).path
        if not self.autorizzato():
            return self.rispondi(403, {"errore": "accesso non autorizzato"})
        if percorso == "/api/chiusa":  # la scheda è stata chiusa (o ricaricata)
            pagina_chiusa[0] = time.time()
            return self.rispondi(200, {"ok": True})
        ultimo_contatto[0] = time.time()
        lunghezza = int(self.headers.get("Content-Length", 0) or 0)
        corpo = json.loads(self.rfile.read(lunghezza) or b"{}")
        if percorso == "/api/ping":
            return self.rispondi(200, {"ok": True})
        if percorso == "/api/salva":
            try:
                with blocco:
                    risultato = salva(corpo.get("voci", []))
                    stato = leggi_voci()
                print(f"Salvato: {risultato['corrette']} corrette, {risultato['confermate']} confermate, "
                      f"{risultato['rimaste']} ancora da verificare.", flush=True)
                return self.rispondi(200, {"risultato": risultato, **stato})
            except Exception as e:  # noqa: BLE001 — l'errore va mostrato nella pagina
                print(f"ERRORE durante il salvataggio: {e}", flush=True)
                return self.rispondi(500, {"errore": str(e)})
        if percorso == "/api/apri-trascrizione":
            if os.path.exists(file_corretta):
                apri(file_corretta)
                return self.rispondi(200, {"ok": True})
            return self.rispondi(404, {"errore": "La trascrizione corretta non esiste ancora: salva prima."})
        if percorso == "/api/chiudi":
            self.rispondi(200, {"ok": True})
            threading.Thread(target=server.shutdown, daemon=True).start()
            return
        self.rispondi(404, {"errore": "non trovato"})


def sorveglia():
    """Chiude il server quando la scheda è stata chiusa o la pagina non si fa sentire da molto tempo."""
    precedente = time.time()
    while True:
        time.sleep(2)
        adesso = time.time()
        if adesso - precedente > 60 and ultimo_contatto[0]:  # il computer era in stop: si riparte da ora
            ultimo_contatto[0] = adesso
        precedente = adesso
        chiusa, contatto = pagina_chiusa[0], ultimo_contatto[0] or 0
        if chiusa and contatto <= chiusa and adesso - chiusa > ATTESA_DOPO_CHIUSURA:
            print("La scheda del browser è stata chiusa: chiudo la schermata di controllo.", flush=True)
        elif contatto and adesso - contatto > ATTESA_CHIUSURA:
            print("La pagina non si fa sentire da molto tempo: chiudo la schermata di controllo.", flush=True)
        else:
            continue
        server.shutdown()
        return


PAGINA = r"""<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Controllo parole</title>
<style>
:root {
  --sfondo: #f5f5f7; --carta: #ffffff; --testo: #1d1d1f; --tenue: #6e6e73; --bordo: #d2d2d7;
  --blu: #0b5cad; --blu-chiaro: #e8f0fa; --verde: #1e7f3c; --verde-chiaro: #e7f5ec;
  --giallo: #fff4d6; --rosso: #b42318;
}
@media (prefers-color-scheme: dark) {
  :root {
    --sfondo: #1c1c1e; --carta: #2c2c2e; --testo: #f5f5f7; --tenue: #a1a1a6; --bordo: #3a3a3c;
    --blu: #5aa2f0; --blu-chiaro: #1f3550; --verde: #4cc472; --verde-chiaro: #1d3a27;
    --giallo: #4a3d14; --rosso: #ff6b5e;
  }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--sfondo); color: var(--testo);
  font: 15px/1.45 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif; }
header { position: sticky; top: 0; z-index: 2; background: var(--carta); border-bottom: 1px solid var(--bordo);
  padding: 12px 20px; display: flex; flex-wrap: wrap; gap: 8px 20px; align-items: center; }
header h1 { font-size: 18px; margin: 0; flex: 1 1 auto; }
header .file { color: var(--tenue); font-weight: normal; font-size: 14px; }
.conteggi { display: flex; gap: 14px; font-size: 14px; color: var(--tenue); }
.conteggi b { color: var(--testo); }
main { max-width: 1100px; margin: 0 auto; padding: 16px 20px 120px; }
.voce { background: var(--carta); border: 1px solid var(--bordo); border-radius: 10px; padding: 12px 14px;
  margin-bottom: 10px; display: grid; gap: 8px 16px;
  grid-template-columns: 92px minmax(0, 1fr) 260px; align-items: start; }
.voce.confermata { background: var(--verde-chiaro); }
.voce.modificata { border-color: var(--blu); box-shadow: 0 0 0 1px var(--blu); }
.numero { font-weight: 600; }
.tempo { color: var(--tenue); font-size: 13px; font-variant-numeric: tabular-nums; }
.contesto { overflow-wrap: anywhere; }
.contesto mark { background: var(--giallo); color: inherit; padding: 0 2px; border-radius: 3px; font-weight: 600; }
.dettagli { color: var(--tenue); font-size: 12.5px; margin-top: 4px; overflow-wrap: anywhere; }
.audio audio { width: 100%; height: 36px; }
.audio a { font-size: 12.5px; color: var(--blu); }
.correzione { grid-column: 2 / 4; display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
.correzione input[type=text] { flex: 1 1 260px; font-size: 16px; padding: 8px 10px; border-radius: 8px;
  border: 1px solid var(--bordo); background: var(--carta); color: var(--testo); }
.correzione input[type=text]:read-only { background: transparent; border-style: dashed; color: var(--verde); font-weight: 600; }
.correzione label { display: flex; gap: 6px; align-items: center; font-weight: 600; cursor: pointer; white-space: nowrap; }
.correzione input[type=checkbox] { width: 20px; height: 20px; accent-color: var(--verde); }
.nota { font-size: 12.5px; color: var(--tenue); }
.paginazione { display: flex; gap: 6px; justify-content: center; align-items: center; flex-wrap: wrap; margin: 16px 0; }
button { font: inherit; border-radius: 8px; border: 1px solid var(--bordo); background: var(--carta);
  color: var(--testo); padding: 7px 14px; cursor: pointer; }
button:disabled { opacity: .45; cursor: default; }
button.pagina.attuale { background: var(--blu); border-color: var(--blu); color: #fff; }
button.primario { background: var(--blu); border-color: var(--blu); color: #fff; font-weight: 600; }
footer { position: fixed; bottom: 0; left: 0; right: 0; background: var(--carta); border-top: 1px solid var(--bordo);
  padding: 12px 20px; display: flex; gap: 12px; align-items: center; justify-content: flex-end; flex-wrap: wrap; z-index: 2; }
#stato { flex: 1 1 300px; font-size: 14px; color: var(--tenue); }
#stato.errore { color: var(--rosso); font-weight: 600; }
#stato.ok { color: var(--verde); font-weight: 600; }
.vuoto { text-align: center; padding: 40px; color: var(--tenue); }
@media (max-width: 760px) {
  .voce { grid-template-columns: 1fr; }
  .correzione { grid-column: 1; }
}
</style>
</head>
<body>
<header>
  <h1>Controllo parole <span class="file" id="titolo"></span></h1>
  <div class="conteggi">
    <span>Da verificare: <b id="n-da-fare">–</b></span>
    <span>Confermate: <b id="n-confermate">–</b></span>
    <span>Totale: <b id="n-totale">–</b></span>
  </div>
  <button id="apri-trascrizione" title="Apre la trascrizione corretta">Apri trascrizione corretta</button>
  <button id="chiudi" title="Chiude la schermata">Chiudi</button>
</header>
<main>
  <div id="elenco"></div>
  <nav class="paginazione" id="paginazione"></nav>
</main>
<footer>
  <div id="stato">Ascolta il ritaglio, scrivi la parola giusta e spunta «Confermata».</div>
  <button id="annulla" disabled>Annulla</button>
  <button id="salva" class="primario" disabled>Salva</button>
</footer>
<script>
const TOKEN = "@TOKEN@";
let voci = [], perPagina = 10, pagina = 0;
const modifiche = new Map();  // numero -> {valore, confermata}

const $ = s => document.querySelector(s);
const esc = s => String(s).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const senzaAsterischi = s => s.replace(/\*/g, "").replace(/\s+/g, " ").trim();

async function chiama(percorso, dati) {
  const r = await fetch(percorso, {method: dati === undefined ? "GET" : "POST",
    headers: {"X-Token": TOKEN, "Content-Type": "application/json"},
    body: dati === undefined ? undefined : JSON.stringify(dati)});
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.errore || ("errore " + r.status));
  return j;
}

function stato(testo, tipo) { const s = $("#stato"); s.textContent = testo; s.className = tipo || ""; }

function carica(dati, primaVolta) {
  voci = dati.voci; perPagina = dati.per_pagina || 10;
  $("#titolo").textContent = "– " + dati.titolo;
  document.title = "Controllo parole – " + dati.titolo;
  modifiche.clear();
  if (primaVolta) {  // si parte dalla prima pagina con parole ancora da verificare
    const i = voci.findIndex(v => !v.confermata);
    pagina = i < 0 ? 0 : Math.floor(i / perPagina);
  }
  pagina = Math.min(pagina, Math.max(0, Math.ceil(voci.length / perPagina) - 1));
  disegna();
}

function attuale(v) { return modifiche.get(v.numero) || {valore: v.valore, confermata: v.confermata}; }

function aggiornaConteggi() {
  const confermate = voci.filter(v => attuale(v).confermata).length;
  $("#n-totale").textContent = voci.length;
  $("#n-confermate").textContent = confermate;
  $("#n-da-fare").textContent = voci.length - confermate;
  const n = modifiche.size;
  $("#salva").disabled = n === 0; $("#annulla").disabled = n === 0;
  if (n) stato(`Modifiche non salvate: ${n}. Premi «Salva» per registrarle.`);
}

function disegna() {
  const elenco = $("#elenco");
  if (!voci.length) { elenco.innerHTML = '<div class="vuoto">Nessuna parola da controllare. 🎉</div>'; }
  else {
    const parte = voci.slice(pagina * perPagina, (pagina + 1) * perPagina);
    elenco.innerHTML = parte.map(v => {
      const a = attuale(v), bloccata = v.confermata;
      const contesto = v.parola !== undefined
        ? `…${esc(v.prima)} <mark>${esc(v.parola)}</mark> ${esc(v.dopo)}…`
        : esc(v.contesto).replace(/\[([^\]]*)\]/, "<mark>$1</mark>");
      const url = `/clip/${encodeURIComponent(v.clip)}?t=${TOKEN}`;
      return `<section class="voce ${a.confermata ? "confermata" : ""} ${modifiche.has(v.numero) ? "modificata" : ""}" data-numero="${v.numero}">
        <div><div class="numero">${v.numero}</div><div class="tempo">${esc(v.tempo)}</div></div>
        <div><div class="contesto">${contesto}</div><div class="dettagli">${esc(v.dettagli)}</div></div>
        <div class="audio">${v.clip ? `<audio controls preload="none" src="${url}"></audio>
          <a href="${url}" target="_blank" rel="noopener">Apri l'audio ${esc(v.clip)}</a>` : '<span class="nota">ritaglio non disponibile</span>'}</div>
        <div class="correzione">
          <input type="text" aria-label="Parola ${v.numero}" value="${esc(a.valore)}" ${a.confermata ? "readonly" : ""}>
          <label><input type="checkbox" ${a.confermata ? "checked" : ""} ${bloccata ? "disabled" : ""}> Confermata</label>
          <span class="nota">${bloccata ? "Confermata e salvata: non più modificabile." :
            (a.confermata && !senzaAsterischi(a.valore) ? "La parola verrà cancellata dal testo." : "")}</span>
        </div></section>`;
    }).join("");
  }
  elenco.querySelectorAll(".voce").forEach(el => {
    const v = voci.find(x => x.numero === el.dataset.numero);
    const campo = el.querySelector("input[type=text]"), casella = el.querySelector("input[type=checkbox]");
    campo.addEventListener("input", () => segna(v, campo.value, casella.checked, el));
    casella.addEventListener("change", () => {
      if (casella.checked) campo.value = senzaAsterischi(campo.value);
      campo.readOnly = casella.checked;
      segna(v, campo.value, casella.checked, el);
      disegnaVoce(el, v);
    });
    campo.addEventListener("keydown", e => { if (e.key === "Enter" && !casella.disabled) { casella.checked = true; casella.dispatchEvent(new Event("change")); } });
  });
  disegnaPaginazione();
  aggiornaConteggi();
}

function disegnaVoce(el, v) {
  const a = attuale(v);
  el.classList.toggle("confermata", a.confermata);
  el.querySelector(".nota").textContent = a.confermata && !senzaAsterischi(a.valore) ? "La parola verrà cancellata dal testo." : "";
}

function segna(v, valore, confermata, el) {
  if (valore === v.valore && confermata === v.confermata) modifiche.delete(v.numero);
  else modifiche.set(v.numero, {valore, confermata});
  el.classList.toggle("modificata", modifiche.has(v.numero));
  aggiornaConteggi();
}

function disegnaPaginazione() {
  const pagine = Math.ceil(voci.length / perPagina), nav = $("#paginazione");
  if (pagine <= 1) { nav.innerHTML = ""; return; }
  let html = `<button data-p="${pagina - 1}" ${pagina === 0 ? "disabled" : ""}>‹ Precedente</button>`;
  for (let p = 0; p < pagine; p++) {
    const daFare = voci.slice(p * perPagina, (p + 1) * perPagina).some(v => !attuale(v).confermata);
    html += `<button class="pagina ${p === pagina ? "attuale" : ""}" data-p="${p}" title="${daFare ? "contiene parole da verificare" : "tutte confermate"}">${p + 1}${daFare ? "" : " ✓"}</button>`;
  }
  html += `<button data-p="${pagina + 1}" ${pagina === pagine - 1 ? "disabled" : ""}>Successiva ›</button>`;
  nav.innerHTML = html;
  nav.querySelectorAll("button").forEach(b => b.addEventListener("click", () => {
    pagina = +b.dataset.p; disegna(); window.scrollTo(0, 0);
  }));
}

$("#salva").addEventListener("click", async () => {
  $("#salva").disabled = true; $("#annulla").disabled = true; $("#chiudi").disabled = true;
  stato("Salvataggio e aggiornamento in corso…");
  try {
    const elenco = [...modifiche].map(([numero, m]) => ({numero, ...m}));
    const r = await chiama("/api/salva", {voci: elenco});
    carica(r, false);
    const x = r.risultato;
    stato(`Salvato. Corrette: ${x.corrette}, confermate: ${x.confermate}, ancora da verificare: ${x.rimaste}. ` +
          `Trascrizione corretta e dizionario aggiornati.`, "ok");
  } catch (e) {  // prima i conteggi, poi l'errore: altrimenti «Modifiche non salvate» lo coprirebbe
    aggiornaConteggi(); stato("Salvataggio non riuscito: " + e.message, "errore");
  }
  $("#chiudi").disabled = false;
});

$("#annulla").addEventListener("click", async () => {
  if (!confirm("Annullare le modifiche non salvate?")) return;
  carica(await chiama("/api/voci"), false);
  stato("Modifiche annullate: la schermata mostra di nuovo il contenuto del file.");
});

$("#apri-trascrizione").addEventListener("click", async () => {
  try { await chiama("/api/apri-trascrizione", {}); } catch (e) { stato(e.message, "errore"); }
});

// La pagina dice al programma che è aperta: poco dopo l'apertura (così, se è stata solo
// ricaricata, il programma non si chiude) e poi ogni 20 secondi
let pingFalliti = 0;
const faiPing = () => chiama("/api/ping", {}).then(() => { pingFalliti = 0; }).catch(() => {
  if (++pingFalliti === 2) stato("Collegamento con Trascrivi Audio interrotto: la schermata è stata chiusa. " +
    "Per continuare riaprila da Trascrivi Audio (Apri un progetto › Analisi delle parole).", "errore");
});
setTimeout(faiPing, 3000);
const ping = setInterval(faiPing, 20000);
window.addEventListener("pageshow", e => { if (e.persisted) faiPing(); });  // pagina ripresa dalla cache

$("#chiudi").addEventListener("click", async () => {
  if (modifiche.size && !confirm("Ci sono modifiche non salvate. Chiudere comunque?")) return;
  clearInterval(ping);
  await chiama("/api/chiudi", {}).catch(() => {});
  modifiche.clear();
  document.body.innerHTML = '<main><div class="vuoto">Schermata chiusa. Puoi chiudere questa scheda.<br>' +
    'Per riprendere il lavoro: apri Trascrivi Audio, scegli «Apri un progetto» e poi «Analisi delle parole».</div></main>';
});

window.addEventListener("beforeunload", e => { if (modifiche.size) { e.preventDefault(); e.returnValue = ""; } });
// Scheda chiusa senza «Chiudi»: il programma torna al menu dopo pochi secondi
window.addEventListener("pagehide", () => navigator.sendBeacon("/api/chiusa?t=" + encodeURIComponent(TOKEN)));
chiama("/api/voci").then(d => carica(d, true)).catch(e => stato("Impossibile leggere il file: " + e.message, "errore"));
</script>
</body>
</html>
"""

class Server(ThreadingHTTPServer):
    daemon_threads = False  # alla chiusura si aspetta la fine dei salvataggi in corso

    def handle_error(self, request, client_address):
        if isinstance(sys.exc_info()[1], (ConnectionError, TimeoutError)):
            return  # il browser ha interrotto la richiesta: nessun problema
        super().handle_error(request, client_address)


# All'apertura le correzioni già scritte nel file vengono applicate (es. un salvataggio
# interrotto, o righe corrette a mano): trascrizione corretta e dizionario restano allineati
try:
    applica(file_controllo)
except Exception as e:  # noqa: BLE001 — la schermata si apre lo stesso
    print(f"Attenzione: correzioni non applicate ({e})", flush=True)

server = Server(("127.0.0.1", int(os.environ.get("PORTA", "0"))), Gestore)
url = f"http://127.0.0.1:{server.server_address[1]}/?t={TOKEN}"
print(f"Schermata di controllo per: {os.path.basename(file_controllo)}", flush=True)
print(f"Indirizzo (solo su questo computer): {url}", flush=True)
print("Per chiudere: pulsante «Chiudi» nella pagina.", flush=True)
threading.Thread(target=sorveglia, daemon=True).start()
if not os.environ.get("NON_APRIRE_BROWSER"):
    apri(url)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
server.server_close()  # aspetta i salvataggi in corso
print("Schermata di controllo chiusa.", flush=True)
