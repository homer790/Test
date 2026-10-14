@echo off
rem Installa (o aggiorna) Trascrivi Audio per questo utente e lo avvia.
rem Doppio clic su questo file nella cartella estratta dallo ZIP.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0programma\TrascriviAudio.ps1" -Installa
