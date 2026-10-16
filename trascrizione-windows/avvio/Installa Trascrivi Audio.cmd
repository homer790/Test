@echo off
rem Installa (o aggiorna) Trascrivi Audio per questo utente e lo avvia.
rem Doppio clic su questo file nella cartella estratta dallo ZIP.
if not exist "%~dp0programma\TrascriviAudio.ps1" (
  echo Prima estrai lo ZIP: tasto destro sul file ZIP, "Estrai tutto...", poi apri la cartella estratta.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0programma\TrascriviAudio.ps1" -Installa
rem 2 = errore gia' spiegato in una finestra; per gli altri errori la finestra resta aperta
if %errorlevel% neq 0 if %errorlevel% neq 2 pause
