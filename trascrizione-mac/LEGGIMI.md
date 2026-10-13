# Trascrivi Audio (Mac, offline)

Doppio clic su `Trascrivi-Audio.command` e il programma:

1. installa Whisper sul Mac, se manca (prima chiede il permesso);
2. chiede il file audio o video e la cartella dove salvare i risultati;
3. trascrive due volte, con i modelli **large-v3** e **medium**, e confronta le due trascrizioni;
4. mostra un popup e apre il **file di controllo**.

L'audio non lascia mai il computer. Da internet si scaricano solo il programma
(al primo avvio, circa 300 MB) e i modelli (alla prima trascrizione, circa 4,5 GB).

## File creati

- `NOME_trascrizione.txt`: la trascrizione pulita.
- `NOME_controllo.txt`: l'elenco delle parole da riascoltare, con l'orario nell'audio,
  e il testo completo con le parole segnate:
  - `*parola*`: sicurezza bassa **oppure** i due modelli non concordano
  - `**parola**`: sicurezza bassa **e** i due modelli non concordano (controllale per prime)

Se i file esistono già, ai nuovi viene aggiunta la data e l'ora: niente viene sovrascritto.

## Primo avvio

1. Scarica la cartella e fai doppio clic su `Trascrivi-Audio.command`.
2. Se macOS dice che il file "non può essere aperto": tasto destro sul file → **Apri** → **Apri**,
   oppure vai in Impostazioni di Sistema → Privacy e sicurezza → **Apri comunque**.
3. Se dice che non hai i permessi, apri il Terminale e scrivi `chmod +x `, poi trascina il
   file nella finestra e premi Invio.
4. Se manca Python, si apre la finestra di Apple per installare gli "Strumenti da riga di
   comando". Installali e riapri il file.

## Tempi

Sul Mac, Whisper usa solo il processore. Con large-v3 più medium, conta indicativamente
da 1 a 3 volte la durata dell'audio su un Mac con chip Apple (M1 o successivi), e di più
su un Mac Intel. Durante il lavoro, la finestra del Terminale mostra l'avanzamento.

## Impostazioni (facoltative)

Puoi lanciare il programma dal Terminale con impostazioni diverse, per esempio:

```
SOGLIA=0.7 MODELLO_B=small ./Trascrivi-Audio.command
```

| Variabile | Predefinito | Significato |
|---|---|---|
| `MODELLO_A` | `large-v3` | modello principale |
| `MODELLO_B` | `medium` | modello di confronto |
| `SOGLIA` | `0.6` | sotto questo valore la parola è considerata dubbia (più alto = più asterischi) |
| `LINGUA` | `it` | lingua dell'audio (vuoto = rilevamento automatico) |

## Disinstallare

Cancella la cartella `~/Library/Application Support/TrascriviAudio`.

## Prova senza Mac

`test/prova-senza-mac.sh file_audio` esegue tutto il programma su Linux (o su Mac da
Terminale) simulando le finestre e usando modelli piccoli. Alla fine mostra quali finestre
sarebbero apparse e il contenuto dei file creati. Aggiungendo `annulla` dopo il nome del
file, simula il clic su "Annulla" alla richiesta di installazione.
