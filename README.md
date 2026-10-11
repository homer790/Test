# Ghostwriter

Un agente in italiano che ti accompagna nella scrittura di un libro, di qualsiasi genere narrativo, dall'idea al testo finale. Ti fa domande, propone risposte possibili originali, analizza ogni risposta e costruisce con te idea, struttura (anche di una collana), personaggi, luoghi, trama, episodi e stile.

## Che cosa lo distingue

- **Genesi ricostruibile.** Ogni domanda, ogni opzione proposta e ogni tua risposta (riportata alla lettera) vengono salvate in `registro.md`, insieme all'analisi di congruità e coerenza. Con il comando «genesi» ottieni il racconto cronologico di come è nato il libro.
- **Tre origini tracciate.** Ogni parte del testo è marcata come scritta da te (`AUTORE`), sviluppata dall'agente su tua indicazione (`SVILUPPO`, `S-`) oppure generata dall'agente senza indicazioni (`AGENTE`, `A-`). Queste ultime sono raccolte a parte in `contributi-agente.md`.
- **Sempre su permesso.** Dopo ogni risposta l'agente ti chiede se vuoi che sviluppi il testo e quali informazioni gli servono per farlo.
- **Originalità e fonti.** L'agente verifica l'idea cercando sul web opere simili; ogni luogo o fatto reale viene citato in `bibliografia.md` (anche Wikipedia).
- **Coerenza.** Ogni risposta viene confrontata con `canone.md`, l'elenco dei fatti già stabiliti.
- **Esportazione.** Google Doc, e su richiesta ePub e PDF impaginato per il cellulare. C'è anche una versione annotata, che evidenzia in colore le parti scritte dall'agente.

## Uso in Claude Code

1. Apri questo repository in Claude Code (terminale, desktop o web).
2. Scrivi `/ghostwriter`, oppure semplicemente «voglio iniziare un libro».
3. I file del libro vengono creati in `libri/<titolo>/`. Puoi chiedere all'agente di fare un commit a fine sessione: la cronologia git diventa parte della genesi.

Requisiti per l'esportazione: `pandoc`; per il PDF, WeasyPrint oppure Chrome/Chromium.

## Uso su claude.ai

1. Crea un **Progetto** chiamato «Ghostwriter – <titolo>».
2. Carica la skill: *Impostazioni → Funzionalità → Skill → Carica* il file `claude-ai/ghostwriter-skill.zip`. Se modifichi la skill, rigenera il file con `claude-ai/crea_zip.sh`.
3. Incolla il contenuto di `claude-ai/ISTRUZIONI-PROGETTO.md` nelle **istruzioni del Progetto**.
4. Attiva la ricerca web (per fonti e verifica di originalità), l'esecuzione di codice (per ePub e PDF) e, se vuoi il Google Doc diretto, il connettore Google Drive.
5. A fine sessione scrivi «salva»: l'agente ti consegna i file aggiornati. Sostituiscili nei file del Progetto, così nella sessione successiva riprende da lì.

## Struttura del repository

```
.claude/skills/ghostwriter/
  SKILL.md                istruzioni principali dell'agente
  riferimenti/            fasi, formato del registro, esportazione
  modelli/                modelli dei file di un nuovo libro
  strumenti/              nuovo_libro.py, esporta.py, fogli di stile
claude-ai/                istruzioni del Progetto e skill in .zip per claude.ai
libri/                    i tuoi libri, uno per cartella
```

## Comandi rapidi

«stato» · «salva» · «genesi» · «contributi» · «fonti» · «torna a <fase>» · «esporta»

## Limiti

La verifica di originalità si basa su ricerche web ed è **indicativa**, non una certificazione antiplagio. Le fonti trovate dall'agente vanno ricontrollate prima della pubblicazione.
