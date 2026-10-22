#Requires -Version 5.1
<#
    GUI-Tool: Finde und verschiebe Dateien (~$* oder 0 Byte)
    - Zielbasis standardmäßig automatisch aus Quelle abgeleitet:
        C:\esc\<drive lower>\rest\des\pfades
      (UNC -> C:\esc\unc\<server>\<share>\...)
    - Logdatei wird IMMER im Zielbasisordner abgelegt (auch im Dry-Run)
#>

if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $psExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    & $psExe -STA -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function New-FolderPicker {
    param([string]$Description="Ordner auswählen",[string]$SelectedPath="")
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = $Description
    $dlg.ShowNewFolderButton = $true
    if ($SelectedPath -and (Test-Path -LiteralPath $SelectedPath)) { $dlg.SelectedPath = $SelectedPath }
    return $dlg
}

function Get-DefaultDestFromSource {
    param([string]$SourcePath)
    # Normalisieren (ProviderPath: bei UNC liefert .Path "Microsoft.PowerShell.Core\FileSystem::\\...")
    try { $src = (Resolve-Path -LiteralPath $SourcePath).ProviderPath } catch { return $null }
    $src = $src.TrimEnd('\')

    if ($src.StartsWith('\\')) {
        # UNC: \\server\share\rest -> C:\esc\unc\server\share\rest
        $trim = $src.TrimStart('\')
        $parts = $trim -split '\\'
        if ($parts.Count -lt 2) { return 'C:\esc\unc' }  # Fallback
        $server = $parts[0]; $share = $parts[1]
        $rest = if ($parts.Count -gt 2) { ($parts[2..($parts.Count-1)] -join '\') } else { '' }
        $dest = Join-Path 'C:\esc' 'unc'
        $dest = Join-Path $dest $server
        $dest = Join-Path $dest $share
        if ($rest) { $dest = Join-Path $dest $rest }
        return $dest
    } else {
        # Lokales Laufwerk: H:\rest -> C:\esc\h\rest
        $root = [IO.Path]::GetPathRoot($src) # z.B. H:\
        if (-not $root) { return 'C:\esc' }
        $drive = $root.Substring(0,1).ToLower()
        $rest  = $src.Substring($root.Length) # ohne "H:\"
        $dest  = Join-Path 'C:\esc' $drive
        if ($rest) { $dest = Join-Path $dest $rest }
        return $dest
    }
}

# --- UI ---
$form               = New-Object System.Windows.Forms.Form
$form.Text          = "Dateiaufräumer (~$ & 0-Byte) – mit Dry-Run"
$form.StartPosition = "CenterScreen"
$form.Size          = New-Object System.Drawing.Size(820, 560)
$form.Font          = New-Object System.Drawing.Font("Segoe UI", 9)

$lblSource = New-Object System.Windows.Forms.Label
$lblSource.Text = "Quellordner:"
$lblSource.Location = New-Object System.Drawing.Point(20,20)
$lblSource.AutoSize = $true
$form.Controls.Add($lblSource)

$tbSource = New-Object System.Windows.Forms.TextBox
$tbSource.Location = New-Object System.Drawing.Point(20, 40)
$tbSource.Size = New-Object System.Drawing.Size(650, 25)
$tbSource.ReadOnly = $true
$form.Controls.Add($tbSource)

$btnSource = New-Object System.Windows.Forms.Button
$btnSource.Text = "Durchsuchen…"
$btnSource.Location = New-Object System.Drawing.Point(685, 40)
$btnSource.Size = New-Object System.Drawing.Size(100, 25)
$form.Controls.Add($btnSource)

$lblDest = New-Object System.Windows.Forms.Label
$lblDest.Text = "Ziel-Basisordner (vorgeschlagen nach Schema C:\esc\...):"
$lblDest.Location = New-Object System.Drawing.Point(20,80)
$lblDest.AutoSize = $true
$form.Controls.Add($lblDest)

$tbDest = New-Object System.Windows.Forms.TextBox
$tbDest.Location = New-Object System.Drawing.Point(20, 100)
$tbDest.Size = New-Object System.Drawing.Size(650, 25)
# bewusst editierbar (manuelle Abweichung erlaubt)
$form.Controls.Add($tbDest)

$btnDest = New-Object System.Windows.Forms.Button
$btnDest.Text = "Ändern…"
$btnDest.Location = New-Object System.Drawing.Point(685, 100)
$btnDest.Size = New-Object System.Drawing.Size(100, 25)
$form.Controls.Add($btnDest)

$cbDryRun = New-Object System.Windows.Forms.CheckBox
$cbDryRun.Text = "Simulieren (Dry Run) – Dateien NICHT verschieben (Log wird dennoch geschrieben)"
$cbDryRun.Location = New-Object System.Drawing.Point(20, 140)
$cbDryRun.AutoSize = $true
$cbDryRun.Checked = $true
$form.Controls.Add($cbDryRun)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start"
$btnStart.Location = New-Object System.Drawing.Point(20, 175)
$btnStart.Size = New-Object System.Drawing.Size(120, 32)
$form.Controls.Add($btnStart)

$btnOpenDest = New-Object System.Windows.Forms.Button
$btnOpenDest.Text = "Zielordner öffnen"
$btnOpenDest.Location = New-Object System.Drawing.Point(150, 175)
$btnOpenDest.Size = New-Object System.Drawing.Size(140, 32)
$btnOpenDest.Enabled = $false
$form.Controls.Add($btnOpenDest)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(20, 220)
$progress.Size = New-Object System.Drawing.Size(765, 22)
$progress.Style = "Continuous"
$form.Controls.Add($progress)

$tbLog = New-Object System.Windows.Forms.TextBox
$tbLog.Location = New-Object System.Drawing.Point(20, 255)
$tbLog.Multiline = $true
$tbLog.ScrollBars = "Vertical"
$tbLog.ReadOnly = $true
$tbLog.Size = New-Object System.Drawing.Size(765, 240)
$form.Controls.Add($tbLog)

# --- Log-Handling ---
$logBuffer = New-Object System.Collections.Generic.List[string]
$global:logWriter = $null
$global:logPath = $null
function Add-Log {
    param([string]$Text)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$timestamp] $Text"
    $logBuffer.Add($line) | Out-Null
    $tbLog.AppendText($line + [Environment]::NewLine)
    if ($global:logWriter) {
        $global:logWriter.WriteLine($line)
        $global:logWriter.Flush()
    }
}

function Show-Error([string]$msg) {
    [System.Windows.Forms.MessageBox]::Show($msg, "Fehler", "OK", "Error") | Out-Null
}

function Normalize-Path([string]$p) {
    try { (Resolve-Path -LiteralPath $p).ProviderPath.TrimEnd('\') } catch { $null }
}

# --- Events ---
$btnSource.Add_Click({
    $dlg = New-FolderPicker -Description "Quellordner wählen (rekursiv durchsuchen)"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $tbSource.Text = $dlg.SelectedPath
        # Ziel automatisch vorschlagen
        $auto = Get-DefaultDestFromSource -SourcePath $dlg.SelectedPath
        if ($auto) { $tbDest.Text = $auto } else { $tbDest.Text = "C:\esc" }
    }
})

$btnDest.Add_Click({
    $dlg = New-FolderPicker -Description "Ziel-Basisordner wählen (Struktur wird gespiegelt)" -SelectedPath $tbDest.Text
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $tbDest.Text = $dlg.SelectedPath
    }
})

$btnOpenDest.Add_Click({
    if ($global:logPath) {
        Start-Process explorer.exe (Split-Path -Path $global:logPath -Parent)
    } elseif ($tbDest.Text) {
        Start-Process explorer.exe $tbDest.Text
    }
})

$btnStart.Add_Click({
    $tbLog.Clear(); $logBuffer.Clear(); $progress.Value = 0
    if ($global:logWriter) { $global:logWriter.Dispose(); $global:logWriter = $null }
    $global:logPath = $null
    $btnOpenDest.Enabled = $false

    $srcRaw = $tbSource.Text.Trim()
    $dstRaw = $tbDest.Text.Trim()
    $dryRun = $cbDryRun.Checked

    if ([string]::IsNullOrWhiteSpace($srcRaw) -or -not (Test-Path -LiteralPath $srcRaw)) {
        Show-Error "Bitte einen gültigen Quellordner wählen."
        return
    }
    if ([string]::IsNullOrWhiteSpace($dstRaw)) {
        Show-Error "Ziel-Basisordner fehlt."
        return
    }

    $src = Normalize-Path $srcRaw
    $dst = $dstRaw.TrimEnd('\') # wir erlauben hier einen „neuen“ Pfad

    # Ziel darf nicht im Quellpfad liegen
    if ($src -and $dst -and ($dst -match '^[A-Za-z]:') -and (Normalize-Path $dst) -and ((Normalize-Path $dst).StartsWith($src,[System.StringComparison]::OrdinalIgnoreCase))) {
        Show-Error "Der Ziel-Basisordner liegt innerhalb des Quellordners. Bitte anderen Zielpfad wählen."
        return
    }

    # Zielbasis (für Log) muss existieren – erstellen, falls nötig (auch im Dry-Run!)
    try {
        if (-not (Test-Path -LiteralPath $dst)) {
            New-Item -ItemType Directory -Path $dst -Force | Out-Null
        }
    } catch {
        Show-Error "Ziel-Basisordner konnte nicht erstellt werden: $($_.Exception.Message)"
        return
    }

    # Log-Datei im Zielbasisordner öffnen
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $global:logPath = Join-Path $dst ("CleanupLog_{0}.txt" -f $timestamp)
    try {
        $global:logWriter = New-Object System.IO.StreamWriter($global:logPath, $false, [System.Text.Encoding]::UTF8)
    } catch {
        Show-Error "Logdatei konnte nicht erstellt werden: $($_.Exception.Message)"
        return
    }

    Add-Log ("Quelle: {0}" -f $src)
    Add-Log ("Ziel  : {0}" -f $dst)
    Add-Log ("Modus : {0}" -f ($(if($dryRun){"Dry-Run (Simulation)"}else{"Ausführen"})))
    Add-Log ("Log   : {0}" -f $global:logPath)
    Add-Log ("Suche Dateien (~$* ODER Länge 0 Byte) …")

    # Dateien ermitteln
    try {
        $files = Get-ChildItem -LiteralPath $src -Recurse -File -Force |
            Where-Object { $_.Name -like '~$*' -or $_.Length -eq 0 }
    } catch {
        Add-Log ("FEHLER beim Scannen: {0}" -f $_.Exception.Message)
        $global:logWriter.Dispose(); $global:logWriter = $null
        Show-Error "Fehler beim Scannen: $($_.Exception.Message)"
        return
    }

    if (-not $files -or $files.Count -eq 0) {
        Add-Log "Keine passenden Dateien gefunden."
        $global:logWriter.Dispose(); $global:logWriter = $null
        [System.Windows.Forms.MessageBox]::Show("Keine passenden Dateien gefunden.`nLog: $global:logPath","Info","OK","Information") | Out-Null
        $btnOpenDest.Enabled = $true
        return
    }

    $total = $files.Count
    Add-Log ("Gefunden: {0} Datei(en)" -f $total)

    $ok = 0; $fail = 0; $skip = 0; $i = 0

    foreach ($f in $files) {
        $i++
        $progress.Value = [Math]::Min(100, [int](($i / $total) * 100))
        $form.Refresh()
        Write-Progress -Activity "Verarbeite Dateien" -Status ("{0} / {1}: {2}" -f $i, $total, $f.FullName) -PercentComplete $progress.Value

        try {
            $rel = $f.FullName.Substring($src.Length).TrimStart('\')
            $targetFull = Join-Path -Path $dst -ChildPath $rel
            $targetDir  = Split-Path -Path $targetFull -Parent

            if ($f.FullName -ieq $targetFull) {
                Add-Log ("Übersprungen (Quelle==Ziel): {0}" -f $f.FullName)
                $skip++
                continue
            }

            if ($dryRun) {
                Add-Log ("[SIM] Verschieben -> {0}" -f $targetFull)
                $ok++
            } else {
                if (-not (Test-Path -LiteralPath $targetDir)) {
                    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                }
                Move-Item -LiteralPath $f.FullName -Destination $targetFull -Force -ErrorAction Stop
                Add-Log ("Verschoben: {0}  ->  {1}" -f $f.FullName, $targetFull)
                $ok++
            }
        } catch {
            Add-Log ("FEHLER: {0}  ->  {1}" -f $f.FullName, $_.Exception.Message)
            $fail++
        }
    }

    Write-Progress -Activity "Verarbeite Dateien" -Completed
    $progress.Value = 100

    $summary = @"
Ergebnis
--------
Gefunden     : $total
Verschoben   : $ok
Übersprungen : $skip
Fehlgeschl.  : $fail
Modus        : $(if($dryRun){"Dry-Run (Simulation)"}else{"Ausführen"})

Logdatei     : $global:logPath
"@

    Add-Log $summary.TrimEnd()
    if ($global:logWriter) { $global:logWriter.Dispose(); $global:logWriter = $null }
    $btnOpenDest.Enabled = $true
    [System.Windows.Forms.MessageBox]::Show($summary, "Fertig", "OK", "Information") | Out-Null
})

[void]$form.ShowDialog()
