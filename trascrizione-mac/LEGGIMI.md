# Trascrivi Audio (Mac, offline)

Due comandi da aprire con doppio clic:

| Comando | Cosa fa |
|---|---|
| `Trascrivi-Audio.command` | trascrive l'audio, ricontrolla le parole dubbie e prepara i ritagli da ascoltare |
| `Applica-Correzioni.command` | applica le tue correzioni e le impara per le trascrizioni future |

L'audio non lascia mai il computer. Da internet si scaricano solo il programma
(al primo avvio, circa 300 MB) e i modelli (alla prima trascrizione, circa 4,5 GB).

## 1. Trascrivi-Audio

1. Se Whisper manca, chiede il permesso e lo installa.
2. Chiede il file audio o video e la cartella dove salvare i risultati.
3. **1° e 2° ascolto:** trascrive l'intero audio con **large-v3** e con **medium**.
   Una parola è *dubbia* se large-v3 non ne è sicuro, oppure se i due modelli hanno sentito cose diverse.
4. **3° ascolto:** ritaglia solo le frasi con parole dubbie e le fa riascoltare a large-v3.
   Se ora sente la stessa cosa che aveva sentito medium, il dubbio è risolto.
5. **4° ascolto:** dove ancora non coincidono, riascolta quelle frasi con medium.
   Se coincide con il riascolto di large-v3, il dubbio è risolto; altrimenti resta l'asterisco.
6. Per ogni parola ancora dubbia salva un **ritaglio audio numerato** (3 secondi prima e dopo).
7. Mostra un popup e apre il **file di controllo**.

### File creati

- `NOME_trascrizione.txt`: la trascrizione automatica.
- `NOME_controllo.txt`: le parole da verificare, numerate, ognuna con:
  - il contesto,
  - cosa hanno sentito i vari ascolti,
  - una riga `PAROLA 001: **parola**` da correggere.

  In fondo al file trovi il testo con le parole segnate e l'elenco di quelle risolte in automatico,
  da ricontrollare a colpo d'occhio.
- `NOME_clip/`: un ritaglio audio per ogni voce, con lo stesso numero (`001_00-03-41.wav`).
- `NOME_dati.json`: serve ad Applica-Correzioni. Non spostarlo e non rinominarlo.

Segni usati: `*parola*` = sicurezza bassa **oppure** modelli in disaccordo;
`**parola**` = sicurezza bassa **e** modelli in disaccordo (da controllare per prime).
Se i file esistono già, ai nuovi viene aggiunta la data e l'ora: niente viene sovrascritto.

## 2. Correggere a mano

1. Apri la cartella `NOME_clip`, seleziona il ritaglio `001_…` e premi la **barra spaziatrice** per ascoltarlo.
2. Nel file di controllo, nella riga `PAROLA 001:`, scrivi la parola giusta **senza asterischi**:
   - era già giusta → togli solo gli asterischi;
   - va cancellata → lascia vuoto dopo i due punti;
   - non sei sicuro → lascia gli asterischi.
3. Salva il file (Cmd+S). Non serve correggere tutto in una volta.

## 3. Applica-Correzioni

Scegli il file di controllo corretto. Il programma:

- crea `NOME_trascrizione_corretta.txt`. Le parole non ancora verificate restano tra `*asterischi*`;
- aggiunge al **dizionario personale** ogni correzione (es. `anamesi → anamnesi`) e ogni
  conferma (es. `anamnesi → anamnesi`, quando togli solo gli asterischi).
  Nelle trascrizioni successive:
  - quelle parole vengono suggerite a Whisper;
  - se Whisper sente di nuovo la forma sbagliata, il programma la sostituisce;
  - le parole che hai già verificato (confermate, o la forma giusta di una correzione)
    **non vengono più segnate**.

  Entrambi i casi compaiono tra le «risolte automaticamente», così puoi vederli.
  Attenzione: una parola confermata non verrà più segnata in nessun contesto. Se un giorno
  ti serve di nuovo il controllo su quella parola, cancella la sua riga dal dizionario;
- salva ogni ritaglio corretto, insieme al testo giusto, nella cartella degli esempi.

Puoi rilanciarlo quante volte vuoi, dopo aver corretto altre voci: riparte sempre dalla trascrizione originale.

**Limite:** Whisper non viene riaddestrato, quindi non "impara" davvero.
Il dizionario funziona per parole singole sentite sempre nello stesso modo sbagliato.
Gli esempi salvati potranno servire in futuro per un vero addestramento, che però richiede
centinaia di esempi e un computer potente.

## Primo avvio

1. Scarica la cartella e fai doppio clic su `Trascrivi-Audio.command`.
2. Se macOS dice che il file "non può essere aperto": tasto destro sul file → **Apri** → **Apri**,
   oppure vai in Impostazioni di Sistema → Privacy e sicurezza → **Apri comunque**.
   Lo stesso vale per `Applica-Correzioni.command`.
3. Se dice che non hai i permessi, apri il Terminale e scrivi `chmod +x `, poi trascina il
   file nella finestra e premi Invio.
4. Se manca Python, si apre la finestra di Apple per installare gli "Strumenti da riga di
   comando". Installali e riapri il file.

## Tempi

Sul Mac, Whisper usa solo il processore. Con large-v3 più medium, conta indicativamente
da 1 a 3 volte la durata dell'audio su un Mac con chip Apple (M1 o successivi), e di più
su un Mac Intel. I riascolti aggiungono poco, perché lavorano solo sulle frasi dubbie.
Durante il lavoro, la finestra del Terminale mostra l'avanzamento.

## Impostazioni (facoltative)

Puoi lanciare il programma dal Terminale con impostazioni diverse, per esempio:

```
SOGLIA=0.7 MODELLO_C=large-v3-turbo ./Trascrivi-Audio.command
```

| Variabile | Predefinito | Significato |
|---|---|---|
| `MODELLO_A` | `large-v3` | modello principale |
| `MODELLO_B` | `medium` | modello di confronto |
| `MODELLO_C` | `medium` | modello del 4° ascolto (riascolto delle frasi ancora dubbie) |
| `RIASCOLTO` | `1` | `0` = non riascoltare le frasi dubbie |
| `SOGLIA` | `0.6` | sotto questo valore la parola è considerata dubbia (più alto = più asterischi) |
| `LINGUA` | `it` | lingua dell'audio (vuoto = rilevamento automatico) |

## Dove sono i dati del programma

In `~/Library/Application Support/TrascriviAudio`:

- `venv/` e `modelli/`: il programma e i modelli;
- `dizionario.txt`: il dizionario personale (correzioni e parole confermate), modificabile a mano;
- `esempi/`: i ritagli corretti, con il testo giusto.

Per disinstallare, cancella quella cartella.

## Prova senza Mac

`test/prova-senza-mac.sh file_audio` esegue l'intero ciclo su Linux (o su Mac da Terminale),
simulando le finestre e usando modelli piccoli:

1. trascrizione;
2. correzione a mano simulata (la voce 001 viene sostituita, alla 002 vengono tolti gli asterischi);
3. Applica-Correzioni;
4. una seconda trascrizione che usa il dizionario.

Alla fine mostra le finestre che sarebbero apparse e tutti i file creati.
Aggiungendo `annulla` dopo il nome del file, simula il clic su "Annulla" all'installazione.
