# Trascrivi Audio – Guida rapida

Trascrive file audio in testo **sul tuo Mac**, senza inviarli online, e ti indica le parole
da ricontrollare.

---

## 1. Installare

1. Scarica **Installa-TrascriviAudio.zip** e fai doppio clic: compare il file
   **Installa-TrascriviAudio.command**.
2. Fai **clic destro** su quel file → **Apri** → **Apri**.
   Serve solo la prima volta, perché macOS blocca i programmi scaricati da internet.
   Se non compare il pulsante "Apri": Impostazioni di Sistema → Privacy e sicurezza → **Apri comunque**.
3. Si apre una finestra del Terminale e poi una serie di finestre (vedi sotto).
4. Alla fine compare **Installazione completata** e sulla **Scrivania** trovi due collegamenti:
   **Trascrivi Audio** e **Applica Correzioni**.

### Cosa fa l'installazione, passo per passo

| Passo | Cosa succede | Cosa fai tu |
|---|---|---|
| 1. Benvenuto | spiega cosa verrà fatto | **Continua** (o **Annulla** per uscire) |
| 2. Cartella | chiede dove installare il programma; dentro crea la cartella **Trascrivi Audio** | scegli una cartella, per esempio Documenti |
| 3. File | copia nella cartella i due comandi, questa guida e le istruzioni complete | niente |
| 4. Python | **controlla se Python è già sul Mac**. Se c'è, passa oltre senza chiedere nulla. Se manca, chiede se installarlo: viene scaricato l'installatore ufficiale da python.org (circa 70 MB), ne viene verificata la firma e macOS chiede la **password del Mac** | **Installa Python** (o **Annulla**) |
| 5. Whisper | **controlla se Whisper è già installato**. Se c'è, passa oltre. Se manca, chiede se installarlo (circa 300 MB, in Libreria/Application Support/TrascriviAudio). Ci vogliono alcuni minuti | **Installa** (o **Annulla**) |
| 6. Collegamenti | crea sulla Scrivania **Trascrivi Audio** e **Applica Correzioni** | niente |
| 7. Fine | mostra **Installazione completata** e apre la cartella del programma | **OK** |

> Per installare serve internet. I **modelli** di Whisper (circa 4,5 GB) non vengono scaricati
> ora, ma alla prima trascrizione.
>
> Se premi **Annulla** su Python o su Whisper, l'installazione del programma si completa
> comunque: la richiesta ti verrà ripetuta al primo avvio di **Trascrivi Audio**.
>
> Python si può installare in automatico su macOS 11 (Big Sur) o successivo. Su versioni
> più vecchie installalo a mano da python.org e rilancia l'installatore.

---

## 2. Trascrivere un audio

1. Doppio clic su **Trascrivi Audio** (sulla Scrivania).
2. Scegli il file audio, poi la cartella dove salvare i risultati.
3. Aspetta: la finestra del Terminale mostra l'avanzamento.
   - **La prima volta** vengono scaricati i modelli (circa 4,5 GB): può volerci molto.
   - Conta indicativamente da 1 a 3 volte la durata dell'audio.
4. Alla fine un messaggio ti avvisa, poi si apre il **file di controllo**.

Nella cartella dei risultati trovi:

| File | A cosa serve |
|---|---|
| `NOME_trascrizione.txt` | la trascrizione automatica |
| `NOME_controllo.txt` | le parole da ricontrollare: **è il file che correggi tu** |
| `NOME_clip` (cartella) | un pezzetto di audio per ogni parola dubbia |
| `NOME_dati.json` | serve al programma: non spostarlo e non rinominarlo |

---

## 3. Controllare le parole dubbie

Nel file di controllo ogni parola dubbia ha un numero:

```
[001]  00:03:41   ritaglio: 001_00-03-41.wav
       contesto: …parlerà della nuova [anamesi] dei pazienti…
PAROLA 001: **anamesi**
```

- `*parola*`: da controllare;
- `**parola**`: da controllare per prima.

Per ogni voce:

1. Apri la cartella `NOME_clip`, seleziona il file con lo **stesso numero** (es. `001_…`) e
   premi la **barra spaziatrice** per ascoltarlo (circa 3 secondi prima e dopo la parola).
2. Correggi la riga `PAROLA 001:`:

   | Situazione | Cosa scrivere |
   |---|---|
   | La parola era sbagliata | `PAROLA 001: anamnesi` (giusta, **senza asterischi**) |
   | La parola era giusta | togli solo gli asterischi: `PAROLA 001: anamesi` |
   | La parola va cancellata | lascia vuoto: `PAROLA 001:` |
   | Non sei sicuro | lascia com'è, con gli asterischi |

3. Salva con **Cmd+S**. Non serve fare tutte le voci in una volta.

---

## 4. Applicare le correzioni

1. Doppio clic su **Applica Correzioni** (sulla Scrivania).
2. Scegli il file `NOME_controllo.txt` che hai corretto.
3. Viene creato **`NOME_trascrizione_corretta.txt`**, che si apre da solo.
   Le parole non ancora controllate restano tra `*asterischi*`.

Puoi correggere altre voci e rilanciare **Applica Correzioni** quante volte vuoi.

**Il programma ricorda le tue scelte.** Nelle trascrizioni successive:

- le parole che hai **corretto** vengono sistemate da sole;
- le parole che hai **confermato** non vengono più segnate.

Le trovi in fondo al file di controllo, sotto «Risolte automaticamente», per una verifica veloce.

---

## 5. Aggiornare il programma

1. Scarica la nuova versione di **Installa-TrascriviAudio.zip**.
2. Lanciala come al punto 1 e scegli **la stessa cartella** di prima, poi **Aggiorna**.

I file del programma vengono sostituiti. Il dizionario delle tue correzioni, gli esempi
e le trascrizioni già fatte **non vengono toccati**. Python, Whisper e i modelli già
scaricati vengono trovati e non vengono reinstallati, quindi non ti verrà chiesto nulla.
I collegamenti sulla Scrivania vengono ricreati.

La versione installata è scritta nel file `versione.txt`, nella cartella del programma.

---

## 6. Problemi frequenti

| Problema | Soluzione |
|---|---|
| "Impossibile aprire: sviluppatore non identificato" | clic destro → **Apri** → **Apri** |
| "Non hai i permessi" | nel Terminale scrivi `chmod +x `, trascina il file nella finestra e premi Invio |
| Un collegamento sulla Scrivania non funziona più | hai spostato la cartella del programma: rilancia l'installatore |
| Una parola non deve più essere considerata "confermata" | cancella la sua riga da `dizionario.txt` (vedi sotto) |
| Qualcosa va storto durante la trascrizione | copia il testo della finestra del Terminale e invialo a chi ti assiste |

**Dati del programma**, in `~/Library/Application Support/TrascriviAudio`.
Nel Finder: menu Vai → Vai alla cartella…, poi incolla il percorso.

- `dizionario.txt`: le tue correzioni e conferme;
- `esempi/`: gli audio corretti;
- `venv/` e `modelli/`: Whisper e i modelli.

**Disinstallare:** cancella la cartella del programma, i due collegamenti sulla Scrivania e
la cartella `~/Library/Application Support/TrascriviAudio`. Python, se è stato installato
dal programma, resta sul Mac: si può tenere senza problemi.
