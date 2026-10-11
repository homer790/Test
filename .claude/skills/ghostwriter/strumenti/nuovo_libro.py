#!/usr/bin/env python3
"""Crea la cartella di un nuovo libro Ghostwriter a partire dai modelli.

Uso:
    python3 nuovo_libro.py "Titolo provvisorio" [--radice libri]
"""

import argparse
import datetime
import os
import re
import sys
import unicodedata

MODELLI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "modelli")


def slug(testo):
    t = unicodedata.normalize("NFKD", testo).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", t.lower()).strip("-") or "libro"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("titolo")
    p.add_argument("--radice", default="libri")
    a = p.parse_args()

    cartella = os.path.join(a.radice, slug(a.titolo))
    if os.path.exists(cartella):
        sys.exit(f"Esiste già: {cartella}")
    os.makedirs(os.path.join(cartella, "testo"))
    oggi = datetime.date.today().isoformat()
    for nome in sorted(os.listdir(MODELLI)):
        with open(os.path.join(MODELLI, nome), encoding="utf-8") as f:
            testo = f.read().replace("{{TITOLO}}", a.titolo).replace("{{DATA}}", oggi)
        with open(os.path.join(cartella, nome), "w", encoding="utf-8") as f:
            f.write(testo)
    open(os.path.join(cartella, "testo", ".gitkeep"), "w").close()
    print(cartella)


if __name__ == "__main__":
    main()
