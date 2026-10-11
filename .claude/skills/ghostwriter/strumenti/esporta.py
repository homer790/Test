#!/usr/bin/env python3
"""Esporta un libro Ghostwriter in DOCX (per Google Doc), ePub e PDF per cellulare.

Uso:
    python3 esporta.py libri/<slug> [--formati docx,epub,pdf] [--annotata] [--bibliografia]

Richiede pandoc. Per il PDF usa WeasyPrint se presente, altrimenti Chromium/Chrome
in modalità headless (percorso personalizzabile con la variabile GW_CHROME).
"""

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

QUI = os.path.dirname(os.path.abspath(__file__))
CSS_CELLULARE = os.path.join(QUI, "cellulare.css")
CSS_EPUB = os.path.join(QUI, "epub.css")

COMMENTO = re.compile(r"<!--.*?-->", re.S)
INIZIO = re.compile(r"<!--\s*gw:inizio\s+([SA]-\d+)\s*-->")
FINE = re.compile(r"<!--\s*gw:fine\s+([SA]-\d+)\s*-->")
FONTE = re.compile(r"<!--\s*gw:fonte\s+(B-\d+)\s*-->")


def errore(msg):
    sys.exit(f"Errore: {msg}")


def leggi(percorso):
    with open(percorso, encoding="utf-8") as f:
        return f.read()


def frontespizio(cartella):
    """Restituisce (yaml_front_matter, corpo) dal file frontespizio.md."""
    percorso = os.path.join(cartella, "frontespizio.md")
    if not os.path.exists(percorso):
        errore(f"manca {percorso}")
    testo = leggi(percorso)
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", testo, re.S)
    if not m:
        errore("frontespizio.md deve iniziare con un blocco YAML tra due righe '---'")
    return m.group(1), COMMENTO.sub("", m.group(2)).strip()


def annota(testo):
    """Rende visibili le origini: S- (sviluppo) e A- (agente) e le fonti B-."""
    testo = INIZIO.sub(
        lambda m: f'\n<div class="gw gw-{m.group(1)[0]}" title="{m.group(1)}">\n'
        f'<p class="gw-etichetta">{m.group(1)}</p>\n',
        testo,
    )
    testo = FINE.sub("\n</div>\n", testo)
    return FONTE.sub(lambda m: f'<sup class="gw-fonte">[{m.group(1)}]</sup>', testo)


def componi(cartella, annotata, bibliografia):
    yaml, dedica = frontespizio(cartella)
    capitoli = sorted(glob.glob(os.path.join(cartella, "testo", "*.md")))
    if not capitoli:
        errore("nessun capitolo in testo/")
    parti = [f"---\n{yaml}\n---\n"]
    if dedica:
        parti.append(f'::: {{.dedica}}\n{dedica}\n:::\n')
    for c in capitoli:
        t = leggi(c)
        parti.append(annota(t) if annotata else COMMENTO.sub("", t))
    if bibliografia:
        bib = os.path.join(cartella, "bibliografia.md")
        if os.path.exists(bib):
            corpo = COMMENTO.sub("", leggi(bib))
            corpo = re.sub(r"^# .*\n", "", corpo, count=1, flags=re.M)
            parti.append("# Note e fonti {.unnumbered}\n\n" + corpo)
    return "\n\n".join(p.strip() + "\n" for p in parti)


def pandoc(args):
    if not shutil.which("pandoc"):
        errore("pandoc non è installato (https://pandoc.org/installing.html)")
    subprocess.run(["pandoc", *args], check=True)


def trova_chrome():
    candidati = [os.environ.get("GW_CHROME")]
    for nome in ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable", "chrome"):
        candidati.append(shutil.which(nome))
    candidati += glob.glob("/opt/pw-browsers/chromium-*/chrome-linux/chrome")
    candidati.append("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    for c in candidati:
        if c and os.path.exists(c):
            return c
    return None


def html_a_pdf(html, pdf):
    try:
        import weasyprint  # noqa: F401

        subprocess.run([sys.executable, "-m", "weasyprint", html, pdf], check=True)
        return
    except ImportError:
        pass
    if shutil.which("weasyprint"):
        subprocess.run(["weasyprint", html, pdf], check=True)
        return
    chrome = trova_chrome()
    if not chrome:
        errore("per il PDF serve WeasyPrint (pip install weasyprint) oppure Chromium/Chrome")
    subprocess.run(
        [chrome, "--headless", "--no-sandbox", "--disable-gpu", "--no-pdf-header-footer",
         f"--print-to-pdf={os.path.abspath(pdf)}", "file://" + os.path.abspath(html)],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("cartella", help="cartella del libro, es. libri/il-faro")
    p.add_argument("--formati", default="docx,epub,pdf")
    p.add_argument("--annotata", action="store_true",
                   help="versione di lavoro con le parti S-/A- e le fonti evidenziate (solo HTML e PDF)")
    p.add_argument("--bibliografia", action="store_true", help="aggiunge 'Note e fonti' in fondo")
    a = p.parse_args()

    cartella = os.path.abspath(a.cartella)
    slug = os.path.basename(cartella.rstrip("/"))
    uscita = os.path.join(cartella, "esportazioni")
    os.makedirs(uscita, exist_ok=True)
    formati = {f.strip() for f in a.formati.split(",") if f.strip()}
    if a.annotata:
        formati &= {"pdf", "html"}
        formati = formati or {"pdf"}
        slug += "-annotata"

    md = componi(cartella, a.annotata, a.bibliografia)
    with tempfile.TemporaryDirectory() as tmp:
        sorgente = os.path.join(tmp, "libro.md")
        with open(sorgente, "w", encoding="utf-8") as f:
            f.write(md)
        comuni = [sorgente, "--from", "markdown", "--toc", "--toc-depth=1",
                  "--metadata", "lang=it", "--metadata", "toc-title=Indice"]
        prodotti = []

        if "docx" in formati:
            out = os.path.join(uscita, f"{slug}.docx")
            pandoc([*comuni, "-o", out])
            prodotti.append(out)
        if "epub" in formati:
            out = os.path.join(uscita, f"{slug}.epub")
            extra = []
            copertina = os.path.join(cartella, "copertina.jpg")
            if os.path.exists(copertina):
                extra = [f"--epub-cover-image={copertina}"]
            pandoc([*comuni, "--split-level=1", f"--css={CSS_EPUB}", *extra, "-o", out])
            prodotti.append(out)
        if formati & {"pdf", "html"}:
            html = os.path.join(uscita if "html" in formati else tmp, f"{slug}.html")
            pandoc([*comuni, "--standalone", "--embed-resources", f"--css={CSS_CELLULARE}", "-o", html])
            if "html" in formati:
                prodotti.append(html)
            if "pdf" in formati:
                out = os.path.join(uscita, f"{slug}.pdf")
                html_a_pdf(html, out)
                prodotti.append(out)

    for x in prodotti:
        print(os.path.relpath(x))


if __name__ == "__main__":
    main()
