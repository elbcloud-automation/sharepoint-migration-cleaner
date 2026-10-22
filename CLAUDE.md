# CLAUDE.md

Kontext für Claude Code in diesem Repository.

## Worum es geht

`SharePointMigrationCleaner.ps1` ist ein Windows-Forms-Tool (PowerShell), das vor einer Migration nach SharePoint/OneDrive Office-Sperrdateien (`~$*`) und 0-Byte-Dateien aus einem Quellordner in einen Sicherungsordner verschiebt (Struktur wird gespiegelt, Schema `C:\esc\<laufwerk>\...` bzw. `C:\esc\unc\<server>\<share>\...`). Eingesetzt wird es von elbcloud Tech Solutions GmbH bei Kundenmigrationen.

## Regeln für Änderungen

- **Kompatibel mit Windows PowerShell 5.1 bleiben** (kein `??`, kein `?.`, keine ternären Operatoren, keine PS7-only-Cmdlets). PowerShell 7 soll ebenfalls laufen.
- **Nichts löschen.** Das Tool verschiebt nur. Daran nichts ändern, ohne ausdrücklich gefragt worden zu sein.
- **Dry Run bleibt Standard** (`$cbDryRun.Checked = $true`).
- Oberfläche, Log und Meldungen sind **deutsch**; geschlechtsneutral formulieren.
- Datei als **UTF-8 mit BOM und CRLF** speichern. Ohne BOM liest PowerShell 5.1 die Datei als ANSI: Umlaute werden verstümmelt, und `–`/`Ä` in Strings werden zu typografischen Anführungszeichen → Parserfehler, das Skript startet außerhalb der ISE gar nicht. Prüfen: die ersten drei Bytes müssen `EF BB BF` sein.
- Bei neuen Versionen die Versionsnummer im README anpassen; keine Versionsnummer im Dateinamen (Git übernimmt die Historie).

## Testen

Die GUI läuft nur unter Windows. In einer Linux-Umgebung höchstens:
- Syntaxprüfung mit `pwsh` (falls installiert): `pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('SharePointMigrationCleaner.ps1',[ref]$null,[ref]$null)"`
- Statische Analyse mit PSScriptAnalyzer.

Wenn Logik testbar gemacht werden soll: Such- und Verschiebelogik in Funktionen ohne GUI-Abhängigkeit auslagern und mit Pester testen.

## Bekannte Baustellen / Ideen

1. **GUI friert ein:** Scan und Verschieben laufen im UI-Thread. Bei großen Freigaben zeigt Windows „Keine Rückmeldung". Lösung: Arbeit in Runspace/Background-Job, Fortschritt per Timer/Dispatcher.
2. **Zugriffsfehler beim Scan werden verschluckt:** `Get-ChildItem` ohne `-ErrorAction`/`-ErrorVariable` → nicht lesbare Ordner tauchen weder im Log noch in der Zusammenfassung auf.
3. **Ziel-in-Quelle-Prüfung lückenhaft:** greift nur, wenn das Ziel schon existiert und ein Laufwerkspfad ist (`Normalize-Path` liefert sonst `$null`). UNC-Ziele und noch nicht existierende Ziele werden nicht geprüft; umgekehrt (Quelle liegt im Ziel) auch nicht.
4. **Überschreiben ohne Rückfrage:** `Move-Item -Force` überschreibt gleichnamige Dateien im Ziel (z. B. bei einem zweiten Lauf).
5. **Lange Pfade (> 260 Zeichen)** können unter PowerShell 5.1 fehlschlagen.
6. **Zielbasis `C:\esc` ist fest verdrahtet.**
7. Mögliche Erweiterungen: weitere Migrations-Stolpersteine (z. B. `Thumbs.db`, `desktop.ini`, `.tmp`, ungültige Zeichen/Namen für SharePoint), Ausschlussliste, Rückspielfunktion anhand der Logdatei, CSV-Export.
