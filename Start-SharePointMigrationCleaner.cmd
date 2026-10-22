@echo off
rem Startet SharePointMigrationCleaner.ps1 per Doppelklick.
rem -ExecutionPolicy Bypass gilt nur fuer diesen Aufruf, -STA wird von Windows Forms benoetigt.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0SharePointMigrationCleaner.ps1"
rem Bei einem Fehler Fenster offen lassen, damit die Meldung lesbar bleibt.
if errorlevel 1 pause
