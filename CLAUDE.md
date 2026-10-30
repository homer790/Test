# Ghostwriter

Questo repository contiene **Ghostwriter**, un agente in italiano che accompagna un autore nella scrittura di un libro, dall'idea al testo esportato. Rispondi sempre in italiano, anche nei commit e nei commenti del codice.

Il repository ha due ruoli: è il **prodotto** (la skill che l'agente esegue) ed è il **cantiere** in cui la skill viene sviluppata. Capisci prima in quale dei due ruoli ti trovi.

## Quando l'utente vuole scrivere un libro

- Se l'utente vuole iniziare, riprendere, consultare o esportare un libro, o scrive `/ghostwriter`, carica la skill `ghostwriter` (`.claude/skills/ghostwriter/SKILL.md`) e seguine le regole. SKILL.md rimanda a `riferimenti/registro.md` (obbligatorio), `riferimenti/fasi.md` e `riferimenti/esportazione.md`: leggili quando la skill lo indica, non riassumerli da memoria.
- I libri stanno in `libri/<slug>/`, uno per cartella. `libri/testprimolibro/` è un libro di prova in fase 0: trattalo come un libro vero.
- Per gli script usa sempre i comandi qui sotto; non ricreare a mano i file di un libro né l'esportazione.

## Comandi

```bash
# nuovo libro: crea libri/<slug>/ dai modelli in .claude/skills/ghostwriter/modelli/
python3 .claude/skills/ghostwriter/strumenti/nuovo_libro.py "Titolo provvisorio"

# esportazione in libri/<slug>/esportazioni/ (richiede pandoc; per il PDF WeasyPrint o Chrome, variabile GW_CHROME)
python3 .claude/skills/ghostwriter/strumenti/esporta.py libri/<slug> --bibliografia
python3 .claude/skills/ghostwriter/strumenti/esporta.py libri/<slug> --formati docx,epub,pdf,html
python3 .claude/skills/ghostwriter/strumenti/esporta.py libri/<slug> --annotata   # SVILUPPO in blu, AGENTE in giallo

# dopo ogni modifica alla skill: rigenera il pacchetto per claude.ai
sh claude-ai/crea_zip.sh
```

Non ci sono test automatici. Dopo aver toccato gli script, verificali eseguendoli su un libro di prova in una cartella temporanea (`nuovo_libro.py --radice /tmp/prova`).

## Struttura

```
.claude/skills/ghostwriter/
  SKILL.md          istruzioni principali dell'agente (ciclo di lavoro, origini del testo, comandi rapidi)
  riferimenti/      fasi.md (fasi 0–7), registro.md (formati dei file e degli ID), esportazione.md
  modelli/          modelli dei file di un nuovo libro; segnaposto {{TITOLO}} e {{DATA}}
  strumenti/        nuovo_libro.py, esporta.py, cellulare.css (PDF 90×160 mm), epub.css
claude-ai/          ISTRUZIONI-PROGETTO.md (istruzioni del Progetto claude.ai) e ghostwriter-skill.zip (generato)
libri/<slug>/       un libro: stato.md, registro.md, canone.md, contributi-agente.md, bibliografia.md,
                    idea/struttura/personaggi/luoghi/trama/stile.md, frontespizio.md, testo/NN-titolo.md
```

## Regole inviolabili sui file di un libro

- `registro.md`, `contributi-agente.md` e `bibliografia.md` si aggiornano **solo in aggiunta**: non riscrivere né cancellare le voci passate. Un ripensamento è una nuova voce «Revoca/modifica di D-xxxx».
- La risposta dell'autore si riporta **alla lettera**. Il testo scritto dall'autore non va mai modificato senza il suo consenso esplicito: correzioni e suggerimenti si propongono a parte.
- Gli ID (`D-`, `S-`, `A-`, `B-`, `C-`) sono progressivi e non si riusano mai; i contatori vivono in `stato.md`.
- Le parti scritte dall'agente vanno racchiuse tra `<!-- gw:inizio S-/A-xxxx -->` e `<!-- gw:fine … -->`, ciascun marcatore su una riga a sé; le fonti con `<!-- gw:fonte B-xxx -->`. `esporta.py` si basa su questi marcatori: non cambiarne la forma.
- Non scrivere testo narrativo senza aver prima chiesto il permesso all'autore.
- `libri/<slug>/esportazioni/` è generato: non modificarlo a mano.

## Quando si modifica la skill

- La skill viene usata in due ambienti: Claude Code (file system persistente) e claude.ai (file del Progetto, senza persistenza). Ogni regola nuova deve funzionare in entrambi, o dichiarare esplicitamente a quale ambiente si applica.
- Tre copie devono restare coerenti: `SKILL.md` con i suoi riferimenti, `claude-ai/ISTRUZIONI-PROGETTO.md` (versione ridotta, autosufficiente se la skill non è disponibile) e il `README.md`. Se cambi comandi rapidi, fasi, ID o marcatori, aggiorna tutte e tre e rigenera lo zip con `claude-ai/crea_zip.sh`.
- I modelli in `modelli/` e i formati in `riferimenti/registro.md` sono il contratto tra skill e script: una modifica a `frontespizio.md` (blocco YAML iniziale), ai nomi dei capitoli (`testo/NN-titolo.md`) o ai marcatori richiede l'aggiornamento di `esporta.py`.
- Gli script sono Python 3 senza dipendenze esterne oltre a pandoc (e WeasyPrint o Chrome per il PDF): non aggiungere librerie.
- Nomi di file, funzioni, variabili e messaggi sono in italiano, come il resto del repository.

## Commit

- Lavoro su un libro: `ghostwriter: <fase> – <sintesi>` (ad esempio `ghostwriter: Fase 0 – varianti scelte per delega (A-0005)`). La cronologia git fa parte della genesi del libro, quindi un commit per ogni scambio significativo.
- Lavoro sulla skill o sugli script: messaggio descrittivo in italiano che dice che cosa cambia per l'autore.
- Non committare `__pycache__/` (già in `.gitignore`).
