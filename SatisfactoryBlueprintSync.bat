<# : Batch-Teil - startet den PowerShell-Teil (Oberflaeche) dieser Datei
@echo off
setlocal
set "BPS_SELF=%~f0"
set "BPS_ARGS=%*"
powershell -NoProfile -STA -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:BPS_SELF))"
exit /b %errorlevel%
#>

# ===================================================================
#  Satisfactory Blueprint Sync (PowerShell/WinForms)
#  Steam-Startoption: "<Pfad>\SatisfactoryBlueprintSync.bat" %command%
# ===================================================================

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

# Konsolenfenster verstecken, nur die Oberflaeche anzeigen
Add-Type -Name Win -Namespace BPS -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
[BPS.Win]::ShowWindow([BPS.Win]::GetConsoleWindow(), 0) | Out-Null

$ConfigPath    = Join-Path $env:LOCALAPPDATA 'FactoryGame\BlueprintSync\BPSconfig.ini'
$BlueprintRoot = Join-Path $env:LOCALAPPDATA 'FactoryGame\Saved\SaveGames\Blueprints'
$Installer     = Join-Path (Split-Path $env:BPS_SELF) 'InstallAndRepair.bat'

$State = @{ Abort = $false; Skip = $false; Done = $false; HadError = $false }

function Read-Config {
    $cfg = @{}
    if (Test-Path -LiteralPath $ConfigPath) {
        foreach ($line in [IO.File]::ReadAllLines($ConfigPath)) {
            if ($line -match '^\s*([^=\[]+?)\s*=\s*(.*)$') { $cfg[$Matches[1]] = $Matches[2].Trim() }
        }
    }
    $cfg
}

# Startet das Spiel mit den Argumenten von Steam (%command%) oder ueber Steam selbst
function Start-Game {
    $a = "$env:BPS_ARGS".Trim()
    if (-not $a) { Start-Process 'steam://rungameid/526870'; return }
    if ($a -match '^"([^"]+)"\s*(.*)$' -or $a -match '^(.+?\.exe)\s*(.*)$' -or $a -match '^(\S+)\s*(.*)$') {
        $exe = $Matches[1]; $rest = $Matches[2]
    }
    if ($rest) { Start-Process -FilePath $exe -ArgumentList $rest } else { Start-Process -FilePath $exe }
}

# --------------------------------------------------------- Konfiguration
$cfg = Read-Config
if (-not $cfg.Datei_Sync) {
    $answer = [Windows.Forms.MessageBox]::Show(
        "Es wurde keine Konfiguration gefunden:`n$ConfigPath`n`nJetzt einrichten?",
        'Satisfactory Blueprint Sync', 'YesNo', 'Question')
    if ($answer -eq 'Yes' -and (Test-Path -LiteralPath $Installer)) {
        Start-Process -FilePath $Installer -Wait
        $cfg = Read-Config
    }
    if (-not $cfg.Datei_Sync) { Start-Game; exit }
}

$Worlds = @(for ($i = 1; $i -le [int]$cfg.AnzahlBlueprints; $i++) {
    $name = $cfg["Blueprint$i"]
    if (-not $name) { continue }
    $backup = $cfg["Ludusavi_Backup$i"]
    if (-not $backup) { $backup = "$name Blueprints" }
    [pscustomobject]@{ Name = $name; Backup = $backup }
})

# --------------------------------------------------------------- UI
function New-Ctl($Type, $Parent, $X, $Y, $W, $H, $Props = @{}) {
    $c = New-Object "System.Windows.Forms.$Type"
    $c.SetBounds($X, $Y, $W, $H)
    foreach ($k in $Props.Keys) { $c.$k = $Props[$k] }
    $Parent.Controls.Add($c)
    $c
}

$form = New-Object Windows.Forms.Form
$form.Text            = 'Satisfactory Blueprint Sync'
$form.ClientSize      = New-Object Drawing.Size(520, 472)
$form.StartPosition   = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox     = $false
$form.Font            = New-Object Drawing.Font('Segoe UI', 9)

New-Ctl Label $form 16 10 490 28 @{ Text = 'Satisfactory Blueprint Sync'; Font = New-Object Drawing.Font('Segoe UI', 13, [Drawing.FontStyle]::Bold) } | Out-Null
New-Ctl Label $form 16 40 490 18 @{ Text = 'Welten: ' + (($Worlds | ForEach-Object Name) -join ', '); ForeColor = [Drawing.Color]::DimGray; AutoEllipsis = $true } | Out-Null

$StepNames = @(
    'SaveSync starten'
    'Syncs überprüfen'
    'Blueprints wiederherstellen'
    'Satisfactory starten'
    'Satisfactory läuft'
    'Backup erstellen'
    'Fertig'
)
$StepLabels = for ($i = 0; $i -lt $StepNames.Count; $i++) {
    New-Ctl Label $form 16 (68 + $i * 26) 490 22 @{ Text = "○  $($i + 1). $($StepNames[$i])"; ForeColor = [Drawing.Color]::Gray }
}

$lblStatus = New-Ctl Label       $form 16 256 490 22
$progress  = New-Ctl ProgressBar $form 16 282 490 18
$txtLog    = New-Ctl TextBox     $form 16 308 490 116 @{ Multiline = $true; ReadOnly = $true; ScrollBars = 'Vertical'; Font = New-Object Drawing.Font('Consolas', 8.5) }
$btnNext   = New-Ctl Button      $form 300 434 100 28 @{ Text = 'Weiter'; Enabled = $false }
$btnCancel = New-Ctl Button      $form 410 434 100 28 @{ Text = 'Abbrechen' }

function Set-Step([int]$Nr, [string]$Status) {
    $lbl = $StepLabels[$Nr - 1]
    $sym, $color, $style = switch ($Status) {
        'active'  { '▶', [Drawing.Color]::RoyalBlue,   'Bold' }
        'done'    { '✔', [Drawing.Color]::ForestGreen, 'Regular' }
        'warning' { '⚠', [Drawing.Color]::DarkOrange,  'Regular' }
        'error'   { '✖', [Drawing.Color]::Firebrick,   'Regular' }
    }
    $lbl.Text = "$sym  $Nr. $($StepNames[$Nr - 1])"
    $lbl.ForeColor = $color
    $lbl.Font = New-Object Drawing.Font($form.Font, [Drawing.FontStyle]$style)
    [Windows.Forms.Application]::DoEvents()
}

function Write-Log([string]$Text) {
    $txtLog.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Text`r`n")
}

function Set-Status([string]$Text) {
    $lblStatus.Text = $Text
    [Windows.Forms.Application]::DoEvents()
}

# Wartet, ohne die Oberflaeche einzufrieren. Gibt $true zurueck, sobald $Until erfuellt ist.
function Wait-UI([double]$Seconds, [scriptblock]$Until) {
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        [Windows.Forms.Application]::DoEvents()
        if ($State.Abort) { throw 'BPS_ABORT' }
        if ($Until -and (& $Until)) { return $true }
        Start-Sleep -Milliseconds 50
    }
    $false
}

function Invoke-Ludusavi([string]$Mode, [string]$Backup) {
    if (-not (Test-Path -LiteralPath $cfg.Datei_Ludosavi)) {
        Write-Log "ludusavi nicht gefunden: $($cfg.Datei_Ludosavi)"
        return -1
    }
    $out = [IO.Path]::GetTempFileName()
    $err = [IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath $cfg.Datei_Ludosavi -ArgumentList @($Mode, '--force', "`"$Backup`"") `
            -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        $null = $p.Handle   # sonst liefert ExitCode unter PowerShell 5.1 nichts
        Wait-UI 3600 { $p.HasExited } | Out-Null
        $p.WaitForExit()
        foreach ($line in @(Get-Content $out, $err | Where-Object { $_.Trim() } | Select-Object -Last 15)) {
            Write-Log "   $line"
        }
        $p.ExitCode
    } finally {
        Remove-Item $out, $err -ErrorAction SilentlyContinue
    }
}

function Test-GameRunning { [bool](Get-Process -Name 'FactoryGame*' -ErrorAction SilentlyContinue) }

function Request-Abort {
    $msg = 'Wirklich abbrechen? Es wird dann kein Blueprint-Backup erstellt.'
    [Windows.Forms.MessageBox]::Show($form, $msg, 'Abbrechen', 'YesNo', 'Warning') -eq 'Yes'
}

$btnNext.add_Click({ $State.Skip = $true })
$btnCancel.add_Click({
    if ($State.Done) { $form.Close() }
    elseif (Request-Abort) { $State.Abort = $true }
})
$form.add_FormClosing({
    param($s, $e)
    if ($State.Done -or $State.Abort) { return }
    if (Request-Abort) { $State.Abort = $true } else { $e.Cancel = $true }
})

# ----------------------------------------------------------- Ablauf
$form.Show()
[Windows.Forms.Application]::DoEvents()

try {
    # 1. SaveSync starten bzw. in den Vordergrund holen
    Set-Step 1 'active'
    if (-not (Test-Path -LiteralPath $cfg.Datei_Sync)) {
        Write-Log "SaveSync nicht gefunden: $($cfg.Datei_Sync)"
        Set-Step 1 'error'
        $State.HadError = $true
    } else {
        $running = [bool](Get-Process -Name 'SaveSync' -ErrorAction SilentlyContinue)
        Set-Status $(if ($running) { 'Öffne SaveSync …' } else { 'Starte SaveSync …' })
        Start-Process -FilePath $cfg.Datei_Sync
        Wait-UI $(if ($running) { 4 } else { 6 }) | Out-Null
        Write-Log 'SaveSync gestartet.'
        Set-Step 1 'done'
    }

    # 2. Countdown zum Ueberpruefen der Syncs
    Set-Step 2 'active'
    $form.TopMost = $true; $form.Activate(); $form.TopMost = $false
    $btnNext.Enabled = $true
    $progress.Maximum = 60
    for ($s = 60; $s -ge 1; $s--) {
        $progress.Value = $s
        Set-Status "Überprüfe deine Syncs in SaveSync. Noch $s Sekunden … [Weiter zum Überspringen]"
        if (Wait-UI 1 { $State.Skip }) { break }
    }
    $progress.Value = 0
    $btnNext.Enabled = $false
    Set-Step 2 'done'

    # 3. Blueprints aus dem Ludusavi-Backup wiederherstellen
    Set-Step 3 'active'
    $step = 'done'
    foreach ($w in $Worlds) {
        Set-Status "Stelle Blueprints für „$($w.Name)“ wieder her …"
        $dir = Join-Path $BlueprintRoot $w.Name
        if (Test-Path -LiteralPath $dir) {
            Get-ChildItem -LiteralPath $dir -File | Remove-Item -Force
            Write-Log "Blueprint-Ordner geleert: $($w.Name)"
        }
        Wait-UI 1 | Out-Null
        $code = Invoke-Ludusavi 'restore' $w.Backup
        if ($code -ne 0) { Write-Log "Restore fehlgeschlagen (Code $code): $($w.Backup)"; $step = 'error'; $State.HadError = $true }
        else { Write-Log "Wiederhergestellt: $($w.Backup)" }
    }
    Set-Step 3 $step

    # 4. Spiel starten
    Set-Step 4 'active'
    Set-Status 'Starte Satisfactory … warte, bis das Spiel geladen ist.'
    Start-Game
    Wait-UI ([int]::MaxValue) { Test-GameRunning } | Out-Null
    Wait-UI 10 | Out-Null
    Write-Log 'Satisfactory gestartet.'
    Set-Step 4 'done'

    # 5. Warten, bis das Spiel beendet wird
    Set-Step 5 'active'
    Set-Status 'Viel Spaß beim Spielen und Bauen!'
    $form.WindowState = 'Minimized'
    while (Test-GameRunning) { Wait-UI 2 | Out-Null }
    $form.WindowState = 'Normal'
    $form.Activate()
    Write-Log 'Satisfactory beendet.'
    Set-Step 5 'done'

    # 6. Neues Backup erstellen
    Set-Step 6 'active'
    $step = 'done'
    foreach ($w in $Worlds) {
        Set-Status "Erstelle Backup für „$($w.Name)“ …"
        $code = Invoke-Ludusavi 'backup' $w.Backup
        if ($code -ne 0) { Write-Log "Backup fehlgeschlagen (Code $code): $($w.Backup)"; $step = 'error'; $State.HadError = $true }
        else { Write-Log "Gesichert: $($w.Backup)" }
    }
    Set-Step 6 $step

    # 7. Fertig
    Set-Step 7 $(if ($State.HadError) { 'warning' } else { 'done' })
    Set-Status $(if ($State.HadError) { 'Fertig – mit Fehlern, siehe Protokoll.' } else { 'Backup abgeschlossen.' })
} catch {
    if ("$_" -eq 'BPS_ABORT') { $State.Done = $true; $form.Close(); exit }
    Write-Log "FEHLER: $($_.Exception.Message)"
    Set-Status 'Abgebrochen wegen eines Fehlers, siehe Protokoll.'
    $State.HadError = $true
}

$State.Done = $true
$btnNext.Enabled = $false
$btnCancel.Text = 'Schließen'

# Ohne Fehler nach 3 Sekunden schliessen, sonst offen lassen
$closeAt = if ($State.HadError) { [datetime]::MaxValue } else { (Get-Date).AddSeconds(3) }
while ($form.Visible -and (Get-Date) -lt $closeAt) {
    [Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 50
}
if ($form.Visible) { $form.Close() }
