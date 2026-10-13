# Trascrivi Audio – Guida rapida

Trascrive file audio in testo **sul tuo Mac**, senza inviarli online. Ti indica le parole
da ricontrollare e ti permette di correggerle ascoltando il punto esatto dell'audio.

---

## 1. Installare

1. Scarica **Installa-TrascriviAudio.zip** e fai doppio clic: compare il file
   **Installa-TrascriviAudio.command**.
2. Fai **clic destro** su quel file → **Apri** → **Apri**.
   Serve solo la prima volta, perché macOS blocca i programmi scaricati da internet.
   Se non compare il pulsante "Apri": Impostazioni di Sistema → Privacy e sicurezza → **Apri comunque**.
3. Si apre una finestra del Terminale e poi una serie di finestre (vedi sotto).
4. Alla fine compare **Installazione completata** e sulla **Scrivania** trovi due collegamenti:
   **Trascrivi Audio** e **Controlla Parole**.

### Cosa fa l'installazione, passo per passo

| Passo | Cosa succede | Cosa fai tu |
|---|---|---|
| 1. Benvenuto | spiega cosa verrà fatto | **Continua** (o **Annulla** per uscire) |
| 2. Cartella | chiede dove installare il programma; dentro crea la cartella **Trascrivi Audio** | scegli una cartella, per esempio Documenti |
| 3. File | copia nella cartella i comandi, questa guida e le istruzioni complete | niente |
| 4. Python | **controlla se Python è già sul Mac**. Se c'è, passa oltre senza chiedere nulla. Se manca, chiede se installarlo: viene scaricato l'installatore ufficiale da python.org (circa 70 MB), ne viene verificata la firma e macOS chiede la **password del Mac** | **Installa Python** (o **Annulla**) |
| 5. Whisper | **controlla se Whisper è già installato**. Se c'è, passa oltre. Se manca, chiede se installarlo (circa 300 MB, in Libreria/Application Support/TrascriviAudio). Ci vogliono alcuni minuti | **Installa** (o **Annulla**) |
| 6. Collegamenti | crea sulla Scrivania **Trascrivi Audio** e **Controlla Parole** | niente |
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

## 2. Come funziona la trascrizione

Il programma usa **Whisper**, un sistema di riconoscimento vocale che lavora **solo sul tuo
Mac**. Ogni audio viene ascoltato più volte, da due modelli diversi, per scoprire dove la
trascrizione potrebbe essere sbagliata.

| Ascolto | Cosa succede |
|---|---|
| 1° – modello **large-v3** | trascrive tutto l'audio e dà a ogni parola un punteggio di **sicurezza** |
| 2° – modello **medium** | ritrascrive tutto l'audio, come seconda opinione |
| Confronto | una parola è **dubbia** se large-v3 non ne è sicuro **oppure** se i due modelli hanno sentito cose diverse |
| 3° – **riascolto** con large-v3 | ritaglia solo le frasi con parole dubbie e le fa riascoltare. Se ora sente la stessa cosa di medium, il dubbio è risolto |
| 4° – **riascolto** con medium | dove ancora non coincidono, medium riascolta. Se coincide con il riascolto di large-v3, il dubbio è risolto; altrimenti la parola **resta da verificare** |
| Il tuo dizionario | le parole che hai già corretto vengono sistemate da sole; quelle che hai confermato non vengono più segnate |

Per ogni parola che resta dubbia, il programma salva un **ritaglio audio** con 3 secondi
prima e 3 dopo, così puoi ascoltarla nel suo contesto.

**I segni sulle parole:**

- `*parola*`: da controllare;
- `**parola**`: da controllare per prima, perché i dubbi sono due (sicurezza bassa e modelli in disaccordo).

**Tempi:** contano indicativamente da 1 a 3 volte la durata dell'audio. La prima volta vengono
anche scaricati i modelli. Durante il lavoro, la finestra del Terminale mostra l'avanzamento.

---

## 3. Trascrivere un audio

1. Doppio clic su **Trascrivi Audio** (sulla Scrivania).
2. Scegli il file audio, poi la cartella dove salvare i risultati.
3. Aspetta la fine: un messaggio ti avvisa e si apre da sola la **schermata di controllo**
   (vedi il punto 4). Se non ci sono parole dubbie, si apre direttamente la trascrizione.

Nella cartella dei risultati trovi:

| File | A cosa serve |
|---|---|
| `NOME_trascrizione.txt` | la trascrizione automatica |
| `NOME_trascrizione_corretta.txt` | la trascrizione con le tue correzioni, aggiornata a ogni salvataggio |
| `NOME_controllo.txt` | il **file delle parole dubbie**: lo legge e lo aggiorna la schermata di controllo |
| `NOME_clip` (cartella) | un ritaglio audio per ogni parola dubbia |
| `NOME_dati.json` | serve al programma: non spostarlo e non rinominarlo |

---

## 4. La schermata di controllo delle parole

La schermata si apre nel **browser** (Safari o Chrome), ma funziona **solo sul tuo Mac**:
non usa internet e non è raggiungibile da altri computer.

- **In alto:** il nome dell'audio e i conteggi (**da verificare**, **confermate**, **totale**),
  il pulsante **Apri trascrizione corretta** e il pulsante **Chiudi**.
- **Al centro:** le parole dubbie, **10 per pagina**. Ogni riga contiene:

| Elemento | A cosa serve |
|---|---|
| Numero e orario | dove si trova la parola nell'audio (es. 00:03:41) |
| Contesto | la frase, con la parola dubbia evidenziata in giallo, e cosa hanno sentito i vari ascolti |
| Audio | il lettore del ritaglio (▶ per ascoltare) e il link per aprirlo a parte |
| Campo della parola | la parola tra asterischi, **modificabile** |
| Casella **Confermata** | da spuntare quando la parola è giusta |

- **In fondo:** i numeri di pagina (✓ = pagina completata) e i pulsanti **Salva** e **Annulla**.

### Come si controlla una parola

1. Premi ▶ e ascolta il ritaglio.
2. Se la parola è sbagliata, scrivi nel campo quella giusta.
   Se va **cancellata**, svuota il campo.
3. Spunta **Confermata**: gli asterischi spariscono e il campo **non è più modificabile**.
   Se hai sbagliato, togli la spunta: finché non salvi puoi ancora cambiare.
   Scorciatoia: scrivi la parola e premi **Invio**, la casella si spunta da sola.
4. Passa alle altre parole e alle altre pagine: le modifiche restano in memoria.
   Il riquadro blu indica una riga modificata e non ancora salvata.

### Salva e Annulla

| Pulsante | Cosa fa |
|---|---|
| **Salva** | scrive le modifiche nel file delle parole dubbie, aggiorna la **trascrizione corretta**, registra le parole nel tuo **dizionario personale** (correzioni e conferme) e salva gli esempi audio. Poi **ricarica il contenuto del file**: le parole confermate restano bloccate per sempre |
| **Annulla** | scarta le modifiche non ancora salvate e mostra di nuovo il contenuto del file |

> Una parola modificata ma **non** confermata viene salvata come bozza: resta tra asterischi
> e potrai confermarla più tardi.
>
> **Cosa vuol dire "registrare" la parola:** Whisper non viene riaddestrato, ma il programma
> ricorda le tue scelte nel dizionario personale. Nelle trascrizioni successive le parole
> corrette vengono suggerite a Whisper e sistemate da sole, e quelle confermate non vengono più segnate.

Quando hai finito premi **Chiudi**. Se chiudi solo la scheda del browser, la schermata si
chiude da sola dopo qualche minuto. Se provi a chiudere con modifiche non salvate, il
programma ti avvisa.

---

## 5. Riprendere il lavoro più tardi

Non serve controllare tutte le parole in una volta.

1. Doppio clic su **Controlla Parole** (sulla Scrivania).
2. Scegli il file **`NOME_controllo.txt`** dell'audio su cui stavi lavorando.
3. La schermata si apre sulla **prima pagina con parole ancora da verificare**.
   Le parole già confermate sono verdi e bloccate.

Lascia aperta la finestra del Terminale mentre lavori: si chiude da sola quando premi **Chiudi**.

> In alternativa puoi correggere a mano `NOME_controllo.txt` con TextEdit, sulle righe
> `PAROLA 001: …`, togliendo gli asterischi. Poi fai doppio clic su **Applica-Correzioni.command**,
> nella cartella del programma.

---

## 6. Aggiornare il programma

1. Scarica la nuova versione di **Installa-TrascriviAudio.zip**.
2. Lanciala come al punto 1 e scegli **la stessa cartella** di prima, poi **Aggiorna**.

I file del programma vengono sostituiti. Il dizionario delle tue correzioni, gli esempi
e le trascrizioni già fatte **non vengono toccati**. Python, Whisper e i modelli già
scaricati vengono trovati e non vengono reinstallati, quindi non ti verrà chiesto nulla.
I collegamenti sulla Scrivania vengono ricreati.

La versione installata è scritta nel file `versione.txt`, nella cartella del programma.

---

## 7. Problemi frequenti

| Problema | Soluzione |
|---|---|
| "Impossibile aprire: sviluppatore non identificato" | clic destro → **Apri** → **Apri** |
| "Non hai i permessi" | nel Terminale scrivi `chmod +x `, trascina il file nella finestra e premi Invio |
| Un collegamento sulla Scrivania non funziona più | hai spostato la cartella del programma: rilancia l'installatore |
| La schermata di controllo non si apre | controlla la finestra del Terminale: c'è l'indirizzo da copiare nel browser |
| L'audio di una riga non parte | usa il link «Apri l'audio» sotto il lettore |
| Una parola non deve più essere considerata "confermata" | cancella la sua riga da `dizionario.txt` (vedi sotto) |
| Qualcosa va storto | copia il testo della finestra del Terminale e invialo a chi ti assiste |

**Dati del programma**, in `~/Library/Application Support/TrascriviAudio`.
Nel Finder: menu Vai → Vai alla cartella…, poi incolla il percorso.

- `dizionario.txt`: le tue correzioni e conferme;
- `esempi/`: gli audio corretti;
- `venv/` e `modelli/`: Whisper e i modelli.

**Disinstallare:** cancella la cartella del programma, i due collegamenti sulla Scrivania e
la cartella `~/Library/Application Support/TrascriviAudio`. Python, se è stato installato
dal programma, resta sul Mac: si può tenere senza problemi.
