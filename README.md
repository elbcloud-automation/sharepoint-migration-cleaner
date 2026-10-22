# SharePoint Migration Cleaner

Kleines PowerShell-Tool mit grafischer Oberfläche, das einen Ordner (lokal oder Netzlaufwerk/UNC) vor einer Migration nach SharePoint bzw. OneDrive aufräumt.

Es sucht rekursiv nach Dateien, die bei Migrationen typischerweise Fehler oder unnötige Warnungen verursachen, und **verschiebt** sie in einen separaten Sicherungsordner – gelöscht wird nichts:

- **Office-Sperrdateien** (`~$*`, z. B. `~$Angebot.docx`)
- **leere Dateien** (0 Byte)

Die Ordnerstruktur bleibt im Sicherungsordner erhalten, sodass sich jede Datei bei Bedarf wieder an ihren ursprünglichen Platz zurücklegen lässt.

## Funktionen

- Ordnerauswahl per Dialog, Zielordner wird automatisch vorgeschlagen
- **Simulationsmodus (Dry Run)** – standardmäßig aktiv, zeigt nur an, was verschoben würde
- Fortschrittsanzeige und Live-Protokoll im Fenster
- Logdatei `CleanupLog_<Datum>_<Uhrzeit>.txt` im Zielordner (auch im Dry Run)
- Schutz davor, dass der Zielordner innerhalb des Quellordners liegt

## Zielordner-Schema

Der Sicherungsordner wird aus dem Quellpfad abgeleitet:

| Quelle | Vorgeschlagenes Ziel |
|---|---|
| `H:\Abteilung\Projekte` | `C:\esc\h\Abteilung\Projekte` |
| `\\server\freigabe\Ordner` | `C:\esc\unc\server\freigabe\Ordner` |

Das Ziel kann im Feld jederzeit manuell geändert werden.

## Voraussetzungen

- Windows mit Windows PowerShell 5.1 oder PowerShell 7
- Lesezugriff auf den Quellordner, Schreibzugriff auf den Zielordner

## Verwendung

1. Skript herunterladen (`SharePointMigrationCleaner.ps1`).
2. Rechtsklick → **Mit PowerShell ausführen** oder in einer PowerShell-Konsole:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\SharePointMigrationCleaner.ps1
   ```
3. Quellordner wählen, Zielordner prüfen.
4. Zuerst mit aktivem **Dry Run** starten und das Protokoll prüfen.
5. Dry Run abwählen und erneut starten, um die Dateien tatsächlich zu verschieben.

> Hinweis: Das Skript startet sich bei Bedarf selbst im STA-Modus neu, da Windows Forms das voraussetzt.

## Wichtig

- Leere Dateien sind nicht immer überflüssig (z. B. Platzhalter- oder Markierungsdateien mancher Anwendungen). Bitte das Dry-Run-Protokoll vor dem echten Lauf prüfen.
- Existiert im Ziel bereits eine Datei mit gleichem Namen, wird sie überschrieben.

## Version

1.1
