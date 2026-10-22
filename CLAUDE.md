# CLAUDE.md

Kontext für Claude Code in diesem Repository.

## Worum es geht

`SharePointMigrationCleaner.ps1` ist ein Windows-Forms-Tool (PowerShell), das vor einer Migration nach SharePoint/OneDrive Office-Sperrdateien (`~$*`) und 0-Byte-Dateien aus einem Quellordner in einen Sicherungsordner verschiebt (Struktur wird gespiegelt, Schema `C:\esc\<laufwerk>\...` bzw. `C:\esc\unc\<server>\<share>\...`). Eingesetzt wird es von elbcloud Tech Solutions GmbH bei Kundenmigrationen.

## Regeln für Änderungen

- **Kompatibel mit Windows PowerShell 5.1 bleiben** (kein `??`, kein `?.`, keine ternären Operatoren, keine PS7-only-Cmdlets). PowerShell 7 soll ebenfalls laufen.
- **Nichts löschen.** Das Tool verschiebt nur. Daran nichts ändern, ohne ausdrücklich gefragt worden zu sein.
- **Dry Run bleibt Standard** (`$cbDryRun.Checked = $true`).
- Oberfläche, Log und Meldungen sind **deutsch**; geschlechtsneutral formulieren.
- Datei als **UTF-8 mit BOM und CRLF** speichern – sonst zeigt PowerShell 5.1 Umlaute falsch an (siehe Baustellen).
- Bei neuen Versionen die Versionsnummer im README anpassen; keine Versionsnummer im Dateinamen (Git übernimmt die Historie).

## Testen

Die GUI läuft nur unter Windows. In einer Linux-Umgebung höchstens:
- Syntaxprüfung mit `pwsh` (falls installiert): `pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('SharePointMigrationCleaner.ps1',[ref]$null,[ref]$null)"`
- Statische Analyse mit PSScriptAnalyzer.

Wenn Logik testbar gemacht werden soll: Such- und Verschiebelogik in Funktionen ohne GUI-Abhängigkeit auslagern und mit Pester testen.

## Bekannte Baustellen / Ideen

1. **Encoding:** Die Datei liegt aktuell als UTF-8 *ohne* BOM vor. PowerShell 5.1 liest sie dann als ANSI → Umlaute in der Oberfläche werden verstümmelt. Als UTF-8 mit BOM speichern.
2. **GUI friert ein:** Scan und Verschieben laufen im UI-Thread. Bei großen Freigaben zeigt Windows „Keine Rückmeldung". Lösung: Arbeit in Runspace/Background-Job, Fortschritt per Timer/Dispatcher.
3. **Zugriffsfehler beim Scan werden verschluckt:** `Get-ChildItem` ohne `-ErrorAction`/`-ErrorVariable` → nicht lesbare Ordner tauchen weder im Log noch in der Zusammenfassung auf.
4. **Ziel-in-Quelle-Prüfung lückenhaft:** greift nur, wenn das Ziel schon existiert und ein Laufwerkspfad ist (`Normalize-Path` liefert sonst `$null`). UNC-Ziele und noch nicht existierende Ziele werden nicht geprüft; umgekehrt (Quelle liegt im Ziel) auch nicht.
5. **Überschreiben ohne Rückfrage:** `Move-Item -Force` überschreibt gleichnamige Dateien im Ziel (z. B. bei einem zweiten Lauf).
6. **Lange Pfade (> 260 Zeichen)** können unter PowerShell 5.1 fehlschlagen.
7. **Zielbasis `C:\esc` ist fest verdrahtet.**
8. Mögliche Erweiterungen: weitere Migrations-Stolpersteine (z. B. `Thumbs.db`, `desktop.ini`, `.tmp`, ungültige Zeichen/Namen für SharePoint), Ausschlussliste, Rückspielfunktion anhand der Logdatei, CSV-Export.
