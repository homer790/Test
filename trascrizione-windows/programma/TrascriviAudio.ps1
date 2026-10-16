<#
.SYNOPSIS
    Trascrivi Audio per Windows 11: trascrive file audio sul computer, senza inviarli online.

.DESCRIPTION
    - Con -Installa (doppio clic su «Installa Trascrivi Audio» nella cartella estratta dallo ZIP):
      copia il programma in %LOCALAPPDATA%\Programs\Trascrivi Audio (installazione per l'utente,
      senza richieste di amministratore), toglie il blocco «scaricato da internet» e lo avvia da lì.
    - All'avvio prepara tutto SENZA CHIEDERE, solo se manca qualcosa:
        * Python portatile 3.12 (python-build-standalone), privato del programma, verificato con
          SHA-256, con i componenti Microsoft (msvc-runtime) che servono a Whisper;
        * Whisper (faster-whisper) e i modelli large-v3 e medium (circa 4,5 GB).
      Alla prima installazione e dopo un aggiornamento crea l'icona sulla Scrivania e nel menu
      Start e la voce in Impostazioni > App > App installate.
    - Menu principale: Nuovo progetto, Apri un progetto, Guida rapida, Disinstalla Trascrivi Audio
      (si torna al menu dopo ogni operazione; «Esci» chiude).
    - Progetti in Documenti\Trascrivi Audio\Progetti. Se la cartella Documenti è sincronizzata con
      OneDrive, i progetti vanno in %USERPROFILE%\Trascrivi Audio, così l'audio non finisce online.
    - Con -Disinstalla (da Impostazioni > App installate): disinstallazione.

    La finestra di PowerShell mostra l'avanzamento delle operazioni. L'audio non viene mai inviato
    online: da internet si scaricano solo Python, Whisper e i modelli, una volta sola.

    Prove automatiche: con TRASCRIVI_FINTO=1 le finestre sono simulate (risposte lette dal file
    $env:RISPOSTE, finestre registrate in $env:LOG) e non si toccano registro e collegamenti veri.
#>
param(
    [switch]$Installa,     # dalla cartella estratta: installa (o aggiorna) e poi avvia
    [switch]$Disinstalla   # da Impostazioni > App installate
)

$ErrorActionPreference = 'Continue'
if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    # Criteri di sicurezza di Windows (es. «Controllo intelligente delle app») o regole aziendali
    # permettono a PowerShell solo comandi limitati: il programma non può funzionare
    Write-Host 'Trascrivi Audio non può funzionare su questo PC: i criteri di sicurezza di Windows'
    Write-Host '(per esempio «Controllo intelligente delle app» o le regole di un PC aziendale)'
    Write-Host 'permettono a PowerShell solo comandi limitati. Vedi la guida, «Problemi frequenti».'
    [void](Read-Host 'Premi Invio per chiudere')
    exit 2   # 2 = errore già spiegato (il file .cmd non aspetta un altro tasto)
}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { $Host.UI.RawUI.WindowTitle = 'Trascrivi Audio' } catch { }
$env:PYTHONUTF8 = '1'                          # Python legge e scrive in UTF-8
$env:PYTHONIOENCODING = 'utf-8'
$env:PYTHONDONTWRITEBYTECODE = '1'             # niente file di cache nella cartella del programma
$env:HF_HUB_DISABLE_TELEMETRY = '1'            # nessuna statistica inviata durante i download
$env:HF_HUB_DISABLE_SYMLINKS_WARNING = '1'
$env:PYTHONNOUSERSITE = '1'                    # niente pacchetti di altri Python dell'utente
Remove-Item Env:\PYTHONHOME, Env:\PYTHONPATH -ErrorAction SilentlyContinue   # impostati da altri programmi

$SuWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ($IsWindows -eq $true)
$FINTO = -not [string]::IsNullOrEmpty($env:TRASCRIVI_FINTO)
$QUI = $PSScriptRoot
$TITOLO = 'Trascrivi Audio'
$VERSIONE = ''
if (Test-Path -LiteralPath (Join-Path $QUI 'versione.txt')) {
    $VERSIONE = (Get-Content -LiteralPath (Join-Path $QUI 'versione.txt') -Raw).Trim()
}

# Cartelle del programma
$SUPPORTO = Join-Path $env:LOCALAPPDATA 'TrascriviAudio'                    # Python, Whisper, modelli, dizionario
$DEST = [IO.Path]::Combine($env:LOCALAPPDATA, 'Programs', 'Trascrivi Audio') # il programma installato
$PYTHON_DIR = Join-Path $SUPPORTO 'python'
if ($SuWindows) { $PY = Join-Path $PYTHON_DIR 'python.exe' } else { $PY = [IO.Path]::Combine($PYTHON_DIR, 'bin', 'python3') }
$MARCATORE = Join-Path $SUPPORTO 'installazione-da-completare'
$FILE_CARTELLA = Join-Path $SUPPORTO 'cartella-progetti.txt'
$CHIAVE_DISINSTALLA = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\TrascriviAudio'
$env:CARTELLA_MODELLI = Join-Path $SUPPORTO 'modelli'
# File temporanei dei download nella cartella dei dati: la disinstallazione toglie tutto
if (-not $env:PIP_CACHE_DIR) { $env:PIP_CACHE_DIR = Join-Path $SUPPORTO 'cache-pip' }
if (-not $env:HF_HOME) { $env:HF_HOME = Join-Path $SUPPORTO 'huggingface' }
$env:DIZIONARIO = Join-Path $SUPPORTO 'dizionario.txt'
$env:ESEMPI = Join-Path $SUPPORTO 'esempi'

# Impostazioni modificabili (variabili d'ambiente)
if (-not $env:MODELLO_A) { $env:MODELLO_A = 'large-v3' }   # trascrizione principale
if (-not $env:MODELLO_B) { $env:MODELLO_B = 'medium' }     # trascrizione di confronto
if (-not $env:MODELLO_C) { $env:MODELLO_C = 'medium' }     # terzo ascolto delle frasi ancora dubbie
if (-not $env:SOGLIA) { $env:SOGLIA = '0.6' }              # sotto questa sicurezza la parola è dubbia
if (-not $env:LINGUA) { $env:LINGUA = 'it' }
if (-not $env:RIASCOLTO) { $env:RIASCOLTO = '1' }          # 0 = non riascoltare le frasi dubbie

# Python portatile (python-build-standalone): file e impronta SHA-256 fissati qui
$PYTHON_VERSIONE = '3.12.15'
$PYTHON_RILASCIO = '20261013'
$PYTHON_URL = "https://github.com/astral-sh/python-build-standalone/releases/download/${PYTHON_RILASCIO}/cpython-${PYTHON_VERSIONE}%2B${PYTHON_RILASCIO}-x86_64-pc-windows-msvc-install_only.tar.gz"
$PYTHON_SHA256 = 'bbc902d4d187ac4914915bf538196a064b49109a33a104965b5164ced5b80a1e'
if ($SuWindows) { $CURL = 'curl.exe'; $TAR = 'tar.exe' } else { $CURL = 'curl'; $TAR = 'tar' }   # inclusi in Windows 11
if ($env:SystemRoot) { $POWERSHELL = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' }
else { $POWERSHELL = 'powershell.exe' }

# ============================================================================================
# Finestre di dialogo (Windows Forms, vedi Finestre.cs) o simulate nelle prove
# ============================================================================================

function Registra([string]$riga) {
    Add-Content -LiteralPath $env:LOG -Value $riga -Encoding UTF8
}

function Prossima-Risposta([string]$descrizione) {
    # Prove: registra la finestra e restituisce la prossima risposta della coda ($null = Annulla)
    Registra "== $descrizione"
    $righe = @(Get-Content -LiteralPath $env:RISPOSTE -Encoding UTF8)
    if ($righe.Count -eq 0 -or [string]::IsNullOrEmpty($righe[0])) {
        Registra '   !! RISPOSTA MANCANTE'
        return $null
    }
    $risposta = $righe[0]
    Set-Content -LiteralPath $env:RISPOSTE -Value @($righe | Select-Object -Skip 1) -Encoding UTF8
    Registra "   -> $risposta"
    if ($risposta -eq 'ANNULLA') { return $null }
    return $risposta
}

function Prepara-Finestre {
    if ($FINTO) { return }
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    if (-not ('Finestre' -as [type])) {
        Add-Type -Path (Join-Path $QUI 'Finestre.cs') -ReferencedAssemblies System.Windows.Forms, System.Drawing
    }
    [Finestre]::Titolo = $TITOLO
    [Finestre]::Icona = Join-Path $QUI 'TrascriviAudio.ico'
    [Finestre]::Prepara()
    [Finestre]::BloccaSelezioneConsole()   # un clic nella finestra di PowerShell non mette in pausa il programma
}

function Avviso([string]$testo, [switch]$ComeErrore) {
    if ($FINTO) { Registra "== avviso: $testo"; return }
    [void][Finestre]::Mostra($testo, $null, $false, [string[]]@('OK'), $null, [bool]$ComeErrore)
}

function Domanda([string]$testo, [string]$si, [switch]$PredefinitoAnnulla) {
    # Pulsanti «Annulla» e $si: $true se si conferma. Con -PredefinitoAnnulla il tasto Invio vale
    # «Annulla» (per le conferme che cancellano qualcosa)
    if ($FINTO) { return ($null -ne (Prossima-Risposta "finestra: $testo | Annulla | $si")) }
    if ($PredefinitoAnnulla) { [Finestre]::Predefinito = 'Annulla' }
    $esito = [Finestre]::Mostra($testo, $null, $false, [string[]]@('Annulla', $si), 'Annulla', $false)
    return ($esito.Pulsante -eq $si)
}

function Scelta([string]$testo, [string[]]$pulsanti) {
    # Il primo pulsante è «Annulla»: restituisce il pulsante scelto, $null se annullato
    if ($FINTO) { return Prossima-Risposta ("finestra: $testo | " + ($pulsanti -join ' | ')) }
    $esito = [Finestre]::Mostra($testo, $null, $false, $pulsanti, 'Annulla', $false)
    return $esito.Pulsante
}

function Chiedi-Testo([string]$testo) {
    if ($FINTO) { return Prossima-Risposta "finestra: $testo | [campo di testo] | Annulla | Avanti" }
    $esito = [Finestre]::Mostra($testo, $null, $true, [string[]]@('Annulla', 'Avanti'), 'Annulla', $false)
    if ($esito.Pulsante -ne 'Avanti') { return $null }
    return $esito.Testo
}

function Scegli-Voce([string]$testo, [string[]]$voci, [string]$esci = 'Annulla') {
    # Lista di scelte con pulsanti di opzione, «Avanti» e $esci: restituisce la voce, $null se si esce
    if ($FINTO) { return Prossima-Risposta ("finestra: $testo | " + ($voci -join ' | ') + " | $esci | Avanti") }
    $esito = [Finestre]::Mostra($testo, $voci, $false, [string[]]@($esci, 'Avanti'), $esci, $false)
    if ($esito.Pulsante -ne 'Avanti') { return $null }
    return $esito.Voce
}

function Scegli-FileAudio([string]$titolo) {
    if ($FINTO) { return Prossima-Risposta "prompt: $titolo" }
    $filtro = 'Audio e video|*.mp3;*.m4a;*.wav;*.aac;*.flac;*.ogg;*.opus;*.wma;*.amr;*.mp4;*.m4v;*.mov;*.mkv;*.webm;*.avi|Tutti i file|*.*'
    return [Finestre]::ScegliFile($titolo, $filtro)
}

function Errore([string]$testo) {
    Avviso "$testo`n`nDettagli nella finestra di PowerShell." -ComeErrore
    Write-Host ''
    Write-Host "ERRORE: $testo" -ForegroundColor Red
    if (-not $FINTO) { [void](Read-Host 'Premi Invio per chiudere') }
    exit 2   # 2 = errore già spiegato (il file .cmd non aspetta un altro tasto)
}

function Apri-ConProgrammaPredefinito([string]$file) {
    if ($FINTO) { Registra "== aperto: $file"; return }
    Start-Process -FilePath $file
}

# ============================================================================================
# Progetti (vedi progetti.py)
# ============================================================================================

$PROGETTI_PY = Join-Path $QUI 'progetti.py'
$script:EsitoProgetto = 0

function Progetto {
    # Esegue progetti.py con gli argomenti dati e restituisce il testo stampato
    if (-not (Test-Path -LiteralPath $PY)) { $script:EsitoProgetto = 1; return '' }
    $uscita = & $PY $PROGETTI_PY @args 2>&1 | ForEach-Object { "$_" }
    $script:EsitoProgetto = $LASTEXITCODE
    return (($uscita -join "`n").Trim())
}

function Trova-CartellaDocumenti {
    # Dove stanno i progetti: decisa alla prima installazione e poi sempre la stessa
    if ($env:CARTELLA_DOCUMENTI) { return $env:CARTELLA_DOCUMENTI }
    if (Test-Path -LiteralPath $FILE_CARTELLA) {
        $salvata = (Get-Content -LiteralPath $FILE_CARTELLA -Raw -Encoding UTF8).Trim()
        if ($salvata) { return $salvata }
    }
    $documenti = $env:TRASCRIVI_DOCUMENTI   # solo per le prove
    if (-not $documenti) { $documenti = [Environment]::GetFolderPath('MyDocuments') }
    # Documenti sincronizzata con OneDrive: i progetti andrebbero online, quindi si usa una
    # cartella locale nel profilo dell'utente, che OneDrive non sincronizza
    foreach ($onedrive in @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial)) {
        if ($onedrive -and $documenti.StartsWith($onedrive, [StringComparison]::OrdinalIgnoreCase)) {
            return Join-Path $env:USERPROFILE 'Trascrivi Audio'
        }
    }
    return Join-Path $documenti 'Trascrivi Audio'
}

function Documenti-Attuale {
    if ($env:TRASCRIVI_DOCUMENTI) { return $env:TRASCRIVI_DOCUMENTI }   # solo per le prove
    return [Environment]::GetFolderPath('MyDocuments')
}

function In-OneDrive([string]$cartella) {
    foreach ($onedrive in @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial)) {
        if ($onedrive -and $cartella.StartsWith($onedrive, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Imposta-CartellaDocumenti([string]$cartella) {
    $script:CARTELLA_DOCUMENTI = $cartella
    $env:CARTELLA_DOCUMENTI = $cartella
    $env:CARTELLA_PROGETTI = Join-Path $cartella 'Progetti'
}

function Ritrova-Progetti {
    # Se i progetti non sono più dove li avevamo lasciati ma si trovano nella cartella Documenti
    # attuale, Windows ha spostato Documenti insieme a loro (succede attivando il backup di OneDrive)
    if (-not (Test-Path -LiteralPath $PY) -or $CARTELLA_SCELTA) { return }   # (cartella scelta a mano: non si tocca)
    if (Test-Path -LiteralPath (Join-Path $env:CARTELLA_PROGETTI 'elenco-progetti.json')) { return }
    $documenti = Documenti-Attuale
    $trovata = Join-Path $documenti 'Trascrivi Audio'
    if ($trovata -eq $CARTELLA_DOCUMENTI) { return }
    if (-not (Test-Path -LiteralPath (Join-Path $trovata 'Progetti\elenco-progetti.json'))) { return }
    if (-not (In-OneDrive $documenti)) {
        Imposta-CartellaDocumenti $trovata
        Set-Content -LiteralPath $FILE_CARTELLA -Value $trovata -Encoding UTF8
        Avviso "La cartella Documenti è stata spostata: i tuoi progetti sono ora in:`n$($env:CARTELLA_PROGETTI)"
        return
    }
    # Finiti in OneDrive: si riportano in una cartella che OneDrive non sincronizza
    $vecchiaProgetti = Join-Path $trovata 'Progetti'
    $locale = Join-Path $env:USERPROFILE 'Trascrivi Audio'
    Imposta-CartellaDocumenti $locale
    New-Item -ItemType Directory -Force -Path $env:CARTELLA_PROGETTI | Out-Null
    Write-Host 'Riporto i progetti fuori da OneDrive...'
    $messaggio = Progetto migra $vecchiaProgetti
    if ($script:EsitoProgetto -ne 0) {
        Imposta-CartellaDocumenti $trovata   # si continua a usarli dove sono
        Set-Content -LiteralPath $FILE_CARTELLA -Value $trovata -Encoding UTF8
        Avviso ("Windows ha spostato la cartella Documenti in OneDrive, insieme ai tuoi progetti, e non sono riuscito a riportarli fuori:`n$messaggio`n`n" +
            "I progetti restano in $($env:CARTELLA_PROGETTI), sincronizzata con OneDrive.") -ComeErrore
        return
    }
    Set-Content -LiteralPath $FILE_CARTELLA -Value $locale -Encoding UTF8
    $guida = Join-Path $trovata 'Guida rapida.pdf'
    if (Test-Path -LiteralPath $guida) { Move-Item -LiteralPath $guida -Destination $locale -Force -ErrorAction SilentlyContinue }
    if (-not (Get-ChildItem -LiteralPath $trovata -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $trovata -Force -ErrorAction SilentlyContinue
    }
    Avviso ("Windows ha spostato la cartella Documenti in OneDrive, insieme ai tuoi progetti.`n`n" +
        "Per non tenere l'audio online li ho riportati in una cartella che OneDrive non sincronizza:`n$($env:CARTELLA_PROGETTI)`n`n" +
        "Nel frattempo OneDrive potrebbe averli già caricati: sul sito di OneDrive restano nel Cestino per qualche settimana, se vuoi puoi svuotarlo.")
}

$CARTELLA_SCELTA = -not [string]::IsNullOrEmpty($env:CARTELLA_DOCUMENTI)   # impostata a mano (variabile d'ambiente)
$CARTELLA_DOCUMENTI = Trova-CartellaDocumenti
$env:CARTELLA_DOCUMENTI = $CARTELLA_DOCUMENTI
$env:CARTELLA_PROGETTI = Join-Path $CARTELLA_DOCUMENTI 'Progetti'
$FUORI_DA_DOCUMENTI = -not $CARTELLA_DOCUMENTI.StartsWith(
    $(if ($env:TRASCRIVI_DOCUMENTI) { $env:TRASCRIVI_DOCUMENTI } else { [Environment]::GetFolderPath('MyDocuments') }),
    [StringComparison]::OrdinalIgnoreCase)

# ============================================================================================
# 1. Installazione e preparazione (senza domande)
# ============================================================================================

function Installa-DaPacchetto {
    # Dalla cartella estratta dallo ZIP: copia il programma in %LOCALAPPDATA%\Programs e lo avvia da lì
    $tipo = 'installazione'
    if (Test-Path -LiteralPath (Join-Path $DEST 'TrascriviAudio.ps1')) { $tipo = 'aggiornamento' }
    if ($QUI -ne $DEST) {
        Write-Host "Copio Trascrivi Audio in $DEST ..."
        if (Test-Path -LiteralPath $DEST) {
            Get-ChildItem -LiteralPath $DEST -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Force -Path $DEST | Out-Null
        Get-ChildItem -LiteralPath $QUI -Force | Copy-Item -Destination $DEST -Recurse -Force
        $guida = Join-Path (Split-Path -Parent $QUI) 'Guida rapida.pdf'
        if (Test-Path -LiteralPath $guida) { Copy-Item -LiteralPath $guida -Destination $DEST -Force }
        if (-not (Test-Path -LiteralPath (Join-Path $DEST 'TrascriviAudio.ps1'))) {
            Errore "Non sono riuscito a copiare Trascrivi Audio in $DEST."
        }
        # Toglie il blocco «scaricato da internet», così i prossimi avvii non mostrano avvisi
        if ($SuWindows) { Get-ChildItem -LiteralPath $DEST -Recurse -File | Unblock-File -ErrorAction SilentlyContinue }
    }
    New-Item -ItemType Directory -Force -Path $SUPPORTO | Out-Null
    Set-Content -LiteralPath $MARCATORE -Value $tipo -Encoding UTF8
    & (Join-Path $DEST 'TrascriviAudio.ps1')
    exit $LASTEXITCODE
}

function Whisper-Installato {
    if (-not (Test-Path -LiteralPath $PY)) { return $false }
    & $PY -c 'import faster_whisper, ctranslate2, onnxruntime' 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Installa-PythonPortatile {
    $url = $PYTHON_URL
    $sha = $PYTHON_SHA256
    if ($env:PYTHON_PORTATILE_URL) { $url = $env:PYTHON_PORTATILE_URL }        # le prove usano un file locale
    if ($env:PYTHON_PORTATILE_SHA256) { $sha = $env:PYTHON_PORTATILE_SHA256 }
    $temporanea = Join-Path ([IO.Path]::GetTempPath()) ('TrascriviAudio-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $temporanea | Out-Null
    $archivio = Join-Path $temporanea 'python.tar.gz'
    Write-Host "Scarico Python $PYTHON_VERSIONE portatile (circa 44 MB)..."
    $opzioni = @('-fL', '--progress-bar')
    if ($SuWindows) { $opzioni += '--ssl-no-revoke' }   # alcuni antivirus e proxy bloccano il controllo di revoca
    & $CURL @opzioni -o $archivio $url
    if ($LASTEXITCODE -ne 0) {
        Errore 'Download di Python non riuscito. Controlla la connessione a internet e riapri Trascrivi Audio.'
    }
    # Il file deve essere identico a quello pubblicato (impronta SHA-256 fissata qui)
    $impronta = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivio).Hash.ToLowerInvariant()
    if ($impronta -ne $sha.ToLowerInvariant()) {
        Remove-Item -LiteralPath $temporanea -Recurse -Force -ErrorAction SilentlyContinue
        Errore 'Il file di Python scaricato non è integro: installazione interrotta per sicurezza.'
    }
    if (Test-Path -LiteralPath $PYTHON_DIR) { Remove-Item -LiteralPath $PYTHON_DIR -Recurse -Force }
    & $TAR -xzf $archivio -C $SUPPORTO
    if ($LASTEXITCODE -ne 0) { Errore 'Estrazione di Python non riuscita.' }
    Remove-Item -LiteralPath $temporanea -Recurse -Force -ErrorAction SilentlyContinue
    & $PY -c 'import ssl, venv'
    if ($LASTEXITCODE -ne 0) {
        Errore 'Python portatile installato ma non si avvia. Forse un antivirus o il «Controllo intelligente delle app» di Windows lo blocca: vedi la guida, «Problemi frequenti».'
    }
    Write-Host 'Python portatile installato.' -ForegroundColor Green
}

function Prepara {
    New-Item -ItemType Directory -Force -Path $SUPPORTO, $env:CARTELLA_PROGETTI | Out-Null
    if (-not (Whisper-Installato)) {
        if (-not (Test-Path -LiteralPath $PY)) { Installa-PythonPortatile }
        Write-Host "Python: $PY"
        Write-Host 'Installo Whisper (circa 300 MB, alcuni minuti)...'
        & $PY -m pip --version *> $null
        if ($LASTEXITCODE -ne 0) { & $PY -m ensurepip --upgrade }
        & $PY -m pip install --upgrade pip
        if ($LASTEXITCODE -ne 0) { Errore 'Installazione di Whisper non riuscita: controlla la connessione a internet e lo spazio libero sul disco (i dettagli sono nella finestra di PowerShell).' }
        # Versioni provate: av<19 (PyAV 19 ha tolto un'opzione usata da faster-whisper 1.2, errore
        # «metadata_errors») e huggingface_hub<3; truststore fa usare i certificati di Windows nei
        # download (necessario con alcuni antivirus che controllano le connessioni protette)
        $pacchetti = @('faster-whisper==1.2.1', 'av<19', 'huggingface_hub<3', 'truststore')
        # msvc-runtime: i componenti Microsoft (MSVCP140) che servono a Whisper, dentro il Python
        # del programma: non serve installarli in Windows né confermare come amministratore
        if ($SuWindows) { $pacchetti += 'msvc-runtime' }
        & $PY -m pip install @pacchetti
        if ($LASTEXITCODE -ne 0) { Errore 'Installazione di Whisper non riuscita: controlla la connessione a internet e lo spazio libero sul disco (i dettagli sono nella finestra di PowerShell).' }
        if (-not (Whisper-Installato)) { Errore 'Whisper risulta installato ma non si avvia.' }
        Write-Host 'Whisper installato.' -ForegroundColor Green
    }
    $modelli = Join-Path $QUI 'modelli.py'
    $mancanti = @(& $PY $modelli mancanti $env:MODELLO_A $env:MODELLO_B $env:MODELLO_C)
    foreach ($m in $mancanti) {
        if (-not $m) { continue }
        Write-Host "Scarico il modello $m (una volta sola, può volerci un po')..."
        & $PY $modelli scarica $m
        if ($LASTEXITCODE -ne 0) { Errore "Download del modello $m non riuscito: controlla la connessione a internet e lo spazio libero sul disco (circa 5 GB), poi riapri Trascrivi Audio." }
    }
}

function Cartella-Scrivania {
    if ($env:TRASCRIVI_SCRIVANIA) { return $env:TRASCRIVI_SCRIVANIA }
    return [Environment]::GetFolderPath('Desktop')
}

function Cartella-Start {
    if ($env:TRASCRIVI_START) { return $env:TRASCRIVI_START }
    return [Environment]::GetFolderPath('Programs')
}

function Crea-Collegamento([string]$file) {
    $script = Join-Path $DEST 'TrascriviAudio.ps1'
    if ($FINTO) { Set-Content -LiteralPath $file -Value "collegamento a $script" -Encoding UTF8; return }
    $shell = New-Object -ComObject WScript.Shell
    $collegamento = $shell.CreateShortcut($file)
    $collegamento.TargetPath = $POWERSHELL
    $collegamento.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $script + '"'
    $collegamento.WorkingDirectory = $DEST
    $collegamento.IconLocation = (Join-Path $DEST 'TrascriviAudio.ico') + ',0'
    $collegamento.Description = 'Trascrivi Audio: trascrive file audio sul computer'
    $collegamento.Save()
}

function Registra-InAppInstallate {
    # Voce in Impostazioni > App > App installate, da cui si può anche disinstallare
    $valori = [ordered]@{
        DisplayName     = 'Trascrivi Audio'
        DisplayVersion  = $VERSIONE
        Publisher       = 'Trascrivi Audio'
        DisplayIcon     = Join-Path $DEST 'TrascriviAudio.ico'
        InstallLocation = $DEST
        UninstallString = '"' + $POWERSHELL + '" -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $DEST 'TrascriviAudio.ps1') + '" -Disinstalla'
        NoModify        = 1
        NoRepair        = 1
        EstimatedSize   = 5300000   # KB: programma, Python, Whisper e modelli
    }
    if ($FINTO) { $valori | ConvertTo-Json | Set-Content -LiteralPath $env:TRASCRIVI_REGISTRO -Encoding UTF8; return }
    New-Item -Path $CHIAVE_DISINSTALLA -Force | Out-Null
    foreach ($nome in $valori.Keys) {
        $valore = $valori[$nome]
        if ($valore -is [int]) { $tipo = 'DWord' } else { $tipo = 'String' }
        New-ItemProperty -Path $CHIAVE_DISINSTALLA -Name $nome -Value $valore -PropertyType $tipo -Force | Out-Null
    }
}

function Crea-Icone {
    Crea-Collegamento (Join-Path (Cartella-Scrivania) 'Trascrivi Audio.lnk')
    Crea-Collegamento (Join-Path (Cartella-Start) 'Trascrivi Audio.lnk')
}

function Completa-Installazione {
    if (-not (Test-Path -LiteralPath $MARCATORE)) { return }
    $tipo = (Get-Content -LiteralPath $MARCATORE -Raw -Encoding UTF8).Trim()
    # La posizione dei progetti resta questa anche se in futuro Documenti cambiasse
    Set-Content -LiteralPath $FILE_CARTELLA -Value $CARTELLA_DOCUMENTI -Encoding UTF8
    $problemi = @()
    try { Crea-Icone } catch { $problemi += "icone sulla Scrivania e nel menu Start ($($_.Exception.Message))" }
    try { Registra-InAppInstallate } catch { $problemi += "voce in «App installate» ($($_.Exception.Message))" }
    try {
        $guida = Join-Path $QUI 'Guida rapida.pdf'
        if (Test-Path -LiteralPath $guida) { Copy-Item -LiteralPath $guida -Destination $CARTELLA_DOCUMENTI -Force }
    }
    catch { $problemi += "copia della guida ($($_.Exception.Message))" }
    foreach ($problema in $problemi) { Write-Host "Attenzione: non sono riuscito a creare: $problema" -ForegroundColor Yellow }
    Remove-Item -LiteralPath $MARCATORE -Force
    if ($tipo -eq 'aggiornamento') {
        Avviso "Aggiornamento completato.`n`nI tuoi progetti sono rimasti dove erano:`n$($env:CARTELLA_PROGETTI)"
        return
    }
    $nota = ''
    if ($FUORI_DA_DOCUMENTI) {
        $nota = "`n`nLa cartella Documenti è sincronizzata con OneDrive: per non mettere l'audio online, i progetti vengono salvati in una cartella che OneDrive non sincronizza."
    }
    Avviso ("Installazione completata.`n`n" +
        "• Sulla Scrivania e nel menu Start trovi «Trascrivi Audio»: aprilo ogni volta che vuoi usare il programma.`n" +
        "• I progetti verranno salvati in:`n   $($env:CARTELLA_PROGETTI)`n" +
        "• La guida è in:`n   $(Join-Path $CARTELLA_DOCUMENTI 'Guida rapida.pdf')" + $nota +
        "`n`nOra si apre il menu principale.")
}

# ============================================================================================
# 2. Progetti
# ============================================================================================

function Scegli-Audio {
    # Chiede l'audio sorgente, lo controlla e lo copia nel progetto in corso; $false se annullato
    while ($true) {
        $sorgente = Scegli-FileAudio 'Scegli il file audio (o video) da trascrivere'
        if (-not $sorgente) { return $false }
        Write-Host "Copio l'audio nel progetto..."
        $messaggio = Progetto imposta-audio $sorgente
        if ($script:EsitoProgetto -eq 0) { return $true }
        Avviso $messaggio   # file rovinato, senza audio...: se ne sceglie un altro
    }
}

function Nuovo-Progetto {
    $messaggio = 'Scrivi il nome del nuovo progetto:'
    while ($true) {
        $nome = Chiedi-Testo $messaggio
        if ($null -eq $nome) { return }
        $nome = ($nome -replace '"', "'").Trim()
        if (-not $nome) {
            $messaggio = "Il nome del progetto non può essere vuoto.`n`nScrivi il nome del nuovo progetto:"
            continue
        }
        $risposta = Progetto crea $nome
        if ($script:EsitoProgetto -eq 0) { break }
        $messaggio = "$risposta`n`nScrivi il nome del nuovo progetto:"
    }
    if (-not (Scegli-Audio)) { return }
    Trascrivi-Progetto
}

function Apri-Progetto {
    $elenco = Progetto elenco
    if ($script:EsitoProgetto -ne 0) { Avviso $elenco; return }
    $nomi = @($elenco -split "`n" | Where-Object { $_ })
    if ($nomi.Count -eq 0) {
        Avviso 'Non ci sono ancora progetti: ne creiamo uno nuovo.'
        Nuovo-Progetto
        return
    }
    $nome = Scegli-Voce 'Scegli il progetto da aprire:' $nomi
    if (-not $nome) { return }
    $messaggio = Progetto seleziona $nome
    if ($script:EsitoProgetto -eq 3) {
        # La cartella del progetto è stata cancellata, spostata o rinominata
        $cosa = Scelta ("$messaggio`n`nSe l'hai spostata o rinominata, rimettila in Trascrivi Audio › Progetti con il nome di prima. " +
            "Se l'hai cancellata, puoi togliere il progetto dall'elenco.") @('Annulla', "Togli dall'elenco")
        if (-not $cosa) { return }
        $messaggio = Progetto togli $nome
        if ($script:EsitoProgetto -eq 0) { Avviso "Il progetto «$nome» è stato tolto dall'elenco."; return }
    }
    if ($script:EsitoProgetto -ne 0) { Avviso $messaggio; return }
    if ((Progetto campo stato) -eq 'trascritto') {
        $cosa = Scelta "Progetto «$nome»: cosa vuoi fare?" @('Annulla', 'Rielabora la trascrizione', 'Analisi delle parole')
        if (-not $cosa) { return }
        if ($cosa -eq 'Analisi delle parole') { Analisi-Parole; return }
        $conferma = Domanda ("Rielaborare la trascrizione del progetto «$nome»?`n`n" +
            'La trascrizione e le parole da controllare verranno rifatte da capo: le correzioni fatte in questo progetto andranno perse (il tuo dizionario personale resta e verrà usato).') 'Rielabora' -PredefinitoAnnulla
        if (-not $conferma) { return }
    }
    else {
        Avviso "Il progetto «$nome» non ha ancora una trascrizione completa: la avvio ora."
    }
    $audio = Progetto campo audio
    if ($audio -and (Test-Path -LiteralPath $audio)) {
        $messaggio = Progetto controlla-audio $audio
        if ($script:EsitoProgetto -ne 0) {
            Avviso $messaggio   # es. un audio rovinato, scelto con una versione precedente del programma
            $audio = ''
        }
    }
    if (-not $audio -or -not (Test-Path -LiteralPath $audio)) {
        if (-not (Scegli-Audio)) { return }
    }
    Trascrivi-Progetto
}

function Leggi-Riga([string]$file, [string]$schema) {
    # Prima riga del file (UTF-8) che corrisponde allo schema, $null se nessuna
    foreach ($riga in [IO.File]::ReadAllLines($file, [Text.Encoding]::UTF8)) {
        if ($riga -match $schema) { return $riga }
    }
    return $null
}

function Trascrivi-Progetto {
    $nome = Progetto campo nome
    $audio = Progetto campo audio
    $trascrizione = Progetto campo trascrizione
    $corretta = Progetto campo trascrizione_corretta
    $controllo = Progetto campo controllo
    $dati = Progetto campo dati
    $clip = Progetto campo clip
    # Una nuova trascrizione sostituisce i risultati precedenti del progetto
    foreach ($vecchio in @($clip, $controllo, $dati, $corretta, $trascrizione)) {
        if ($vecchio -and (Test-Path -LiteralPath $vecchio)) { Remove-Item -LiteralPath $vecchio -Recurse -Force }
    }
    Progetto stato 'in trascrizione' | Out-Null
    Write-Host ''
    Write-Host "Progetto:     $(Progetto campo numero) – $nome"
    Write-Host "Cartella:     $(Progetto campo cartella)"
    Write-Host "Audio:        $(Split-Path -Leaf $audio)"
    Write-Host 'Non chiudere questa finestra: qui vedi l''avanzamento della trascrizione.'

    $env:HF_HUB_OFFLINE = '1'   # i modelli sono già sul computer: durante la trascrizione niente internet
    & $PY (Join-Path $QUI 'trascrivi_dubbi.py') $audio $trascrizione $controllo $dati $clip
    $esito = $LASTEXITCODE
    Remove-Item Env:\HF_HUB_OFFLINE -ErrorAction SilentlyContinue
    if ($esito -ne 0) {
        Write-Host 'ERRORE: la trascrizione non è riuscita.' -ForegroundColor Red
        Avviso "La trascrizione del progetto «$nome» non è riuscita.`n`nDettagli nella finestra di PowerShell. Puoi riprovare da «Apri un progetto»." -ComeErrore
        return
    }
    Progetto stato trascritto | Out-Null

    $quante = (Leggi-Riga $controllo '^Parole da riverificare:') -replace '^Parole da riverificare:\s*', ''
    $prima = Leggi-Riga $controllo '^\(prima del riascolto'
    if ($quante -match ' su 0$') {   # nessuna parola riconosciuta
        Avviso "Trascrizione del progetto «$nome» completata, ma nell'audio non è stato riconosciuto nessun parlato.`n`nControlla di aver scelto il file giusto e che l'audio non sia muto."
        return
    }
    if ($quante -match '^0 ') {
        Avviso "Trascrizione del progetto «$nome» completata.`n`nNon ci sono parole da riverificare: ora si apre la trascrizione."
        Apri-ConProgrammaPredefinito $trascrizione
        return
    }
    Avviso ("Trascrizione del progetto «$nome» completata.`n`nParole da riverificare: $quante`n$prima`n`n" +
        'Ora si apre nel browser la schermata di controllo delle parole: ascolta ogni ritaglio, correggi la parola e spunta «Confermata», poi premi «Salva».')
    Analisi-Parole
}

function Analisi-Parole {
    $controllo = Progetto campo controllo
    if (-not $controllo -or -not (Test-Path -LiteralPath $controllo)) {
        Avviso "Il progetto «$(Progetto campo nome)» non ha ancora parole da controllare: rielabora prima la trascrizione."
        return
    }
    Write-Host ''
    Write-Host "Progetto: $(Progetto campo numero) – $(Progetto campo nome)"
    if ($env:SALTA_SCHERMATA) { Write-Host "SCHERMATA (test): $controllo"; return }   # solo per le prove
    Write-Host 'Apro la schermata di controllo nel browser.'
    Write-Host 'Quando hai finito premi «Chiudi» nella pagina: tornerai al menu principale.'
    & $PY (Join-Path $QUI 'schermata_controllo.py') $controllo
    if ($LASTEXITCODE -ne 0) { Avviso "La schermata di controllo si è chiusa con un errore.`n`nDettagli nella finestra di PowerShell." -ComeErrore }
}

# ============================================================================================
# 3. Disinstallazione
# ============================================================================================

function Rimuovi-Cartella([string]$cartella, [string]$deveFinireCon) {
    # Cancella una cartella del programma, solo se il nome è quello atteso (sicurezza)
    if ($cartella -and $cartella.EndsWith($deveFinireCon) -and (Test-Path -LiteralPath $cartella)) {
        Remove-Item -LiteralPath $cartella -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Disinstalla-Programma {
    $risposta = Scelta ("Vuoi disinstallare Trascrivi Audio?`n`n" +
        "Verranno cancellati il programma, le icone sulla Scrivania e nel menu Start, Whisper con i modelli (circa 5 GB) e il dizionario delle tue correzioni.`n`n" +
        "I progetti (audio e trascrizioni) sono in:`n$CARTELLA_DOCUMENTI`npuoi conservarli o cancellarli.") @('Annulla', 'Cancella anche i progetti', 'Conserva i progetti')
    if (-not $risposta) { return }
    $tutto = ($risposta -eq 'Cancella anche i progetti')
    if ($tutto) {
        if (-not (Domanda 'Sei sicuro? Tutti i progetti, con audio e trascrizioni, verranno cancellati definitivamente.' 'Cancella tutto' -PredefinitoAnnulla)) { return }
    }
    Write-Host 'Disinstallo Trascrivi Audio...'
    Progetto chiudi | Out-Null
    # Windows non cancella la cartella da cui si sta lavorando: ci si sposta altrove
    $altrove = [IO.Path]::GetTempPath()
    Set-Location -LiteralPath $altrove
    [Environment]::CurrentDirectory = $altrove
    foreach ($icona in @((Join-Path (Cartella-Scrivania) 'Trascrivi Audio.lnk'), (Join-Path (Cartella-Start) 'Trascrivi Audio.lnk'))) {
        if (Test-Path -LiteralPath $icona) { Remove-Item -LiteralPath $icona -Force }
    }
    if ($FINTO) { Remove-Item -LiteralPath $env:TRASCRIVI_REGISTRO -Force -ErrorAction SilentlyContinue }
    elseif (Test-Path -Path $CHIAVE_DISINSTALLA) { Remove-Item -Path $CHIAVE_DISINSTALLA -Recurse -Force }
    Rimuovi-Cartella $SUPPORTO 'TrascriviAudio'
    if ($tutto) {
        Rimuovi-Cartella $CARTELLA_DOCUMENTI 'Trascrivi Audio'
    }
    else {
        $guida = Join-Path $CARTELLA_DOCUMENTI 'Guida rapida.pdf'
        if (Test-Path -LiteralPath $guida) { Remove-Item -LiteralPath $guida -Force }
    }
    Rimuovi-Cartella $DEST 'Trascrivi Audio'
    if ($tutto) {
        Avviso 'Trascrivi Audio è stato disinstallato, insieme ai progetti.'
    }
    else {
        Avviso "Trascrivi Audio è stato disinstallato.`n`nI progetti sono stati conservati in:`n$($env:CARTELLA_PROGETTI)"
    }
    Write-Host 'Disinstallazione completata.'
    exit 0
}

# ============================================================================================
# Avvio
# ============================================================================================

Prepara-Finestre

# Un solo Trascrivi Audio alla volta: due finestre userebbero lo stesso progetto in corso, e
# un aggiornamento o una disinstallazione toglierebbero i file a quella già aperta
$script:UnSoloAvvio = New-Object System.Threading.Mutex($false, 'Local\TrascriviAudio')
$libero = $false
try { $libero = $script:UnSoloAvvio.WaitOne(0) }
catch [System.Threading.AbandonedMutexException] { $libero = $true }   # l'altra finestra è stata chiusa di colpo
if (-not $libero) {
    if ($Installa -or $Disinstalla) {
        Avviso "Trascrivi Audio è aperto in un'altra finestra: chiudilo (scegli «Esci» nel menu) e poi riprova."
    }
    else {
        Avviso "Trascrivi Audio è già aperto in un'altra finestra di PowerShell: continua da quella (la trovi sulla barra delle applicazioni)."
    }
    exit 0
}

if ($Installa) { Installa-DaPacchetto }
if ($Disinstalla) { Disinstalla-Programma; exit 0 }

Write-Host "Trascrivi Audio $VERSIONE"
Write-Host 'Questa finestra mostra l''avanzamento: lasciala aperta mentre usi il programma.'
New-Item -ItemType Directory -Force -Path $SUPPORTO | Out-Null
if (-not (Test-Path -LiteralPath $PY) -and -not (Test-Path -LiteralPath $MARCATORE)) {
    Set-Content -LiteralPath $MARCATORE -Value 'installazione' -Encoding UTF8   # programma copiato a mano
}
try {
    if (Test-Path -LiteralPath $MARCATORE) { try { Crea-Icone } catch { } }
    Ritrova-Progetti
    Prepara
    Completa-Installazione
    while ($true) {
        $scelta = Scegli-Voce 'Cosa vuoi fare?' @('Nuovo progetto', 'Apri un progetto', 'Guida rapida', 'Disinstalla Trascrivi Audio') 'Esci'
        if (-not $scelta) { break }
        switch ($scelta) {
            'Nuovo progetto' { Nuovo-Progetto }
            'Apri un progetto' { Apri-Progetto }
            'Guida rapida' { Apri-ConProgrammaPredefinito (Join-Path $QUI 'Guida rapida.pdf') }
            'Disinstalla Trascrivi Audio' { Disinstalla-Programma }
        }
        Progetto chiudi | Out-Null   # il file del progetto in corso è temporaneo
    }
}
catch {
    # Qualsiasi errore imprevisto: messaggio chiaro invece di una chiusura senza spiegazioni
    Errore ("Si è verificato un errore imprevisto:`n" + $_.Exception.Message)
}
finally {
    Progetto chiudi | Out-Null
}
Write-Host 'Arrivederci.'
