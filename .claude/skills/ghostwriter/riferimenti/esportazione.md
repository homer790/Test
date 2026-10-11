# Esportazione

Prima di esportare:
1. completa il blocco YAML di `frontespizio.md` (titolo, autore) e l'eventuale dedica sotto il blocco;
2. controlla che i capitoli in `testo/` abbiano nomi ordinabili (`01-…`, `02-…`) e che ogni capitolo inizi con `# Titolo`;
3. segnala all'autore i fatti ancora `DA VERIFICARE` in `canone.md` e i contributi `A-` ancora nello stato «proposto»;
4. chiedi se includere la bibliografia in fondo come «Note e fonti».

I marcatori `<!-- gw:… -->` vengono rimossi automaticamente: il testo esportato è pulito.

## Claude Code

```bash
# DOCX (base del Google Doc), ePub e PDF per cellulare
python3 .claude/skills/ghostwriter/strumenti/esporta.py libri/<slug> --bibliografia

# solo alcuni formati
python3 .claude/skills/ghostwriter/strumenti/esporta.py libri/<slug> --formati docx

# versione di lavoro annotata: parti SVILUPPO in blu, AGENTE in giallo, fonti [B-xxx]
python3 .claude/skills/ghostwriter/strumenti/esporta.py libri/<slug> --annotata
```

I file finiscono in `libri/<slug>/esportazioni/`. Servono `pandoc` e, per il PDF, WeasyPrint oppure Chromium/Chrome (variabile `GW_CHROME` per indicarne il percorso). Il PDF è impaginato a 90×160 mm, con caratteri grandi e margini stretti, per leggerlo comodamente sul telefono. Se c'è `libri/<slug>/copertina.jpg`, viene usata come copertina dell'ePub.

## Google Doc (sempre prodotto alla fine)

- **Se è disponibile il connettore Google Drive:** carica il `.docx` con lo strumento di creazione file del connettore, codificato in base64, con `contentMimeType` = `application/vnd.openxmlformats-officedocument.wordprocessingml.document` e titolo uguale al titolo del libro. Drive lo converte automaticamente in Google Doc. Comunica all'autore il link restituito.
- **Altrimenti:** consegna il `.docx` e spiega come procedere: «caricalo su Google Drive, poi tasto destro → Apri con → Documenti Google».
- Su richiesta, crea in Drive anche un secondo documento «<titolo> – Genesi», con il racconto del comando «genesi», il registro e i contributi dell'agente.

## claude.ai

Se l'esecuzione di codice è attiva, puoi usare lo stesso script, caricato con la skill, oppure generare gli stessi formati con pandoc o Python nella sandbox, con le stesse regole: rimozione dei marcatori, PDF a 90×160 mm, indice, frontespizio. Consegna i file come download. Per il Google Doc segui le istruzioni qui sopra.
