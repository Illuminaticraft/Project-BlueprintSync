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
#  Wird von InstallAndRepair.bat nach %LOCALAPPDATA%\FactoryGame\BlueprintSync kopiert.
#  Steam-Startoption: "<Pfad>\SatisfactoryBlueprintSync.bat" %command%
# ===================================================================

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

Add-Type -Name Win -Namespace BPS -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
[DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] public static extern int SetWindowTheme(IntPtr hWnd, string app, string idList);
'@
# Konsolenfenster verstecken, nur die Oberflaeche anzeigen
[BPS.Win]::ShowWindow([BPS.Win]::GetConsoleWindow(), 0) | Out-Null

$ConfigPath    = Join-Path $env:LOCALAPPDATA 'FactoryGame\BlueprintSync\BPSconfig.ini'
$BlueprintRoot = Join-Path $env:LOCALAPPDATA 'FactoryGame\Saved\SaveGames\Blueprints'

$State = @{ Abort = $false; Skip = $false; Done = $false; HadError = $false }

# ============================================================ Design
$T = @{
    Bg          = [Drawing.Color]::FromArgb(24, 25, 28)
    Card        = [Drawing.Color]::FromArgb(34, 36, 40)
    Input       = [Drawing.Color]::FromArgb(44, 46, 52)
    Border      = [Drawing.Color]::FromArgb(62, 65, 73)
    Text        = [Drawing.Color]::FromArgb(236, 237, 240)
    Muted       = [Drawing.Color]::FromArgb(150, 154, 164)
    Accent      = [Drawing.Color]::FromArgb(250, 149, 73)
    AccentHover = [Drawing.Color]::FromArgb(255, 172, 110)
    AccentText  = [Drawing.Color]::FromArgb(24, 25, 28)
    Ok          = [Drawing.Color]::FromArgb(87, 196, 124)
    Err         = [Drawing.Color]::FromArgb(240, 92, 92)
    Warn        = [Drawing.Color]::FromArgb(245, 180, 60)
}

function New-Font([single]$Size, [string]$Style = 'Regular', [string]$Family = 'Segoe UI') {
    New-Object Drawing.Font($Family, $Size, [Drawing.FontStyle]$Style)
}

function New-Ctl($Type, $Parent, $X, $Y, $W, $H, $Props = @{}) {
    $c = New-Object "System.Windows.Forms.$Type"
    $c.SetBounds($X, $Y, $W, $H)
    foreach ($k in $Props.Keys) { $c.$k = $Props[$k] }
    $Parent.Controls.Add($c)
    $c
}

function New-DarkForm([string]$Title, [int]$W, [int]$H) {
    $f = New-Object Windows.Forms.Form
    $f.Text = $Title
    $f.ClientSize = New-Object Drawing.Size($W, $H)
    $f.StartPosition = 'CenterScreen'
    $f.FormBorderStyle = 'FixedSingle'
    $f.MaximizeBox = $false
    $f.BackColor = $T.Bg
    $f.ForeColor = $T.Text
    $f.Font = New-Font 9.5
    $f.add_HandleCreated({
        param($s)
        # Dunkle Titelleiste (Windows 10/11) und passende Titelleisten-Farbe (Windows 11)
        $on = 1
        [void][BPS.Win]::DwmSetWindowAttribute($s.Handle, 20, [ref]$on, 4)
        [void][BPS.Win]::DwmSetWindowAttribute($s.Handle, 19, [ref]$on, 4)
        $caption = $T.Bg.R -bor ($T.Bg.G -shl 8) -bor ($T.Bg.B -shl 16)
        [void][BPS.Win]::DwmSetWindowAttribute($s.Handle, 35, [ref]$caption, 4)
    })
    $f
}

function New-Button($Parent, [string]$Text, $X, $Y, $W, $H, [switch]$Primary) {
    $b = New-Ctl Button $Parent $X $Y $W $H @{ Text = $Text; FlatStyle = 'Flat'; Cursor = 'Hand'; UseVisualStyleBackColor = $false }
    $b.Tag = [bool]$Primary
    if ($Primary) {
        $b.Font = New-Font 9.5 'Bold'
        $b.FlatAppearance.BorderSize = 0
        $b.FlatAppearance.MouseOverBackColor = $T.AccentHover
        $b.FlatAppearance.MouseDownBackColor = $T.Accent
    } else {
        $b.FlatAppearance.BorderSize = 1
        $b.FlatAppearance.BorderColor = $T.Border
        $b.FlatAppearance.MouseOverBackColor = $T.Border
        $b.FlatAppearance.MouseDownBackColor = $T.Input
    }
    $paint = {
        param($s)
        if ($s.Tag -and $s.Enabled) { $s.BackColor = $T.Accent; $s.ForeColor = $T.AccentText }
        elseif ($s.Tag)             { $s.BackColor = $T.Input;  $s.ForeColor = $T.Muted }
        else                        { $s.BackColor = $T.Input;  $s.ForeColor = $T.Text }
    }
    & $paint $b
    $b.add_EnabledChanged($paint)
    $b
}

function Show-Dialog($Owner, [string]$Title, [string]$Message, [string[]]$Buttons = @('OK'), [string]$Kind = 'info') {
    $d = New-DarkForm $Title 460 100
    $d.ShowInTaskbar = $false
    $d.MinimizeBox = $false
    $bar = switch ($Kind) { 'error' { $T.Err } 'warning' { $T.Warn } 'success' { $T.Ok } default { $T.Accent } }
    New-Ctl Panel $d 0 0 5 1000 @{ BackColor = $bar } | Out-Null
    $lbl = New-Ctl Label $d 28 24 404 20 @{ Text = $Message; AutoSize = $true; MaximumSize = (New-Object Drawing.Size(404, 0)) }
    $y = $lbl.Bottom + 24
    $x = 432
    for ($i = $Buttons.Count - 1; $i -ge 0; $i--) {
        $w = [Math]::Max(96, [Windows.Forms.TextRenderer]::MeasureText($Buttons[$i], $d.Font).Width + 28)
        $x -= $w
        $b = New-Button $d $Buttons[$i] $x $y $w 34 -Primary:($i -eq 0)
        $b.add_Click({ param($s) $f = $s.FindForm(); $f.Tag = $s.Text; $f.Close() })
        if ($i -eq 0) { $d.AcceptButton = $b }
        $x -= 10
    }
    $d.ClientSize = New-Object Drawing.Size(460, ($y + 54))
    $d.Tag = $Buttons[-1]
    if ($Owner) { $d.StartPosition = 'CenterParent'; [void]$d.ShowDialog($Owner) }
    else        { $d.TopMost = $true; [void]$d.ShowDialog() }
    $d.Tag
}

# ============================================================ Logik
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
    Show-Dialog $null 'Satisfactory Blueprint Sync' ("Es wurde keine Konfiguration gefunden:`n$ConfigPath`n`n" +
        "Bitte führe InstallAndRepair.bat aus dem Ludusavi-Backup-Ordner aus.`n" +
        "Satisfactory wird jetzt ohne Blueprint-Sync gestartet.") @('OK') 'warning' | Out-Null
    Start-Game
    exit
}

$Worlds = @(for ($i = 1; $i -le [int]$cfg.AnzahlBlueprints; $i++) {
    $name = $cfg["Blueprint$i"]
    if (-not $name) { continue }
    $backup = $cfg["Ludusavi_Backup$i"]
    if (-not $backup) { $backup = "$name Blueprints" }
    [pscustomobject]@{ Name = $name; Backup = $backup }
})

# ================================================================ UI
$form = New-DarkForm 'Satisfactory Blueprint Sync' 540 640

New-Ctl Label $form 22 16 496 34 @{ Text = 'Blueprint Sync'; Font = (New-Font 17 'Bold') } | Out-Null
New-Ctl Label $form 24 52 492 20 @{ Text = 'Welten: ' + (($Worlds | ForEach-Object Name) -join '  ·  '); ForeColor = $T.Muted; AutoEllipsis = $true } | Out-Null

$StepNames = @(
    'Steam starten'
    'SaveSync starten'
    'Syncs überprüfen'
    'Blueprints wiederherstellen'
    'Satisfactory starten'
    'Satisfactory läuft'
    'Backup erstellen'
    'Fertig'
)
$stepCard = New-Ctl Panel $form 20 84 500 (16 + $StepNames.Count * 30) @{ BackColor = $T.Card }
$Steps = for ($i = 0; $i -lt $StepNames.Count; $i++) {
    $y = 10 + $i * 30
    [pscustomobject]@{
        Icon = New-Ctl Label $stepCard 16 $y 26 26 @{ Text = '○'; ForeColor = $T.Muted; Font = (New-Font 11 'Regular' 'Segoe UI Symbol'); TextAlign = 'MiddleCenter' }
        Text = New-Ctl Label $stepCard 46 $y 430 26 @{ Text = $StepNames[$i]; ForeColor = $T.Muted; TextAlign = 'MiddleLeft' }
    }
}

$y0 = $stepCard.Bottom + 16
$lblStatus = New-Ctl Label $form 22 $y0 496 24 @{ Font = (New-Font 10); AutoEllipsis = $true }
$track     = New-Ctl Panel $form 22 ($y0 + 30) 496 6 @{ BackColor = $T.Input }
$fill      = New-Ctl Panel $track 0 0 0 6 @{ BackColor = $T.Accent }
$logCard   = New-Ctl Panel $form 20 ($y0 + 50) 500 118 @{ BackColor = $T.Input }
$txtLog    = New-Ctl TextBox $logCard 12 8 480 102 @{
    Multiline = $true; ReadOnly = $true; ScrollBars = 'Vertical'; BorderStyle = 'None'
    BackColor = $T.Input; ForeColor = $T.Muted; Font = (New-Font 8.5 'Regular' 'Consolas')
}
$btnNext   = New-Button $form 'Weiter' 300 ($logCard.Bottom + 16) 104 34 -Primary
$btnCancel = New-Button $form 'Abbrechen' 414 ($logCard.Bottom + 16) 106 34
$btnNext.Enabled = $false
$form.ClientSize = New-Object Drawing.Size(540, ($btnCancel.Bottom + 20))

function Set-Step([int]$Nr, [string]$Status) {
    $s = $Steps[$Nr - 1]
    $sym, $color, $textColor, $style = switch ($Status) {
        'active'  { '●', $T.Accent, $T.Text,  'Bold' }
        'done'    { '✔', $T.Ok,     $T.Text,  'Regular' }
        'warning' { '⚠', $T.Warn,   $T.Text,  'Regular' }
        'error'   { '✖', $T.Err,    $T.Err,   'Regular' }
    }
    $s.Icon.Text = $sym
    $s.Icon.ForeColor = $color
    $s.Text.ForeColor = $textColor
    $s.Text.Font = New-Font 9.5 $style
    [Windows.Forms.Application]::DoEvents()
}

function Write-Log([string]$Text) {
    $txtLog.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Text`r`n")
}

function Set-Status([string]$Text) {
    $lblStatus.Text = $Text
    [Windows.Forms.Application]::DoEvents()
}

function Set-Progress([double]$Fraction) {
    $fill.Width = [int]($track.Width * [Math]::Max(0, [Math]::Min(1, $Fraction)))
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

function Test-Steam    { [bool](Get-Process -Name 'steam' -ErrorAction SilentlyContinue) }
function Test-SaveSync { [bool](Get-Process -Name 'SaveSync' -ErrorAction SilentlyContinue) }
function Test-GameRunning { [bool](Get-Process -Name 'FactoryGame*' -ErrorAction SilentlyContinue) }

# Startet SaveSync (bzw. holt es in den Vordergrund). Gibt $false zurueck, wenn es fehlt.
function Start-SaveSync {
    if (-not (Test-Path -LiteralPath $cfg.Datei_Sync)) {
        Write-Log "SaveSync nicht gefunden: $($cfg.Datei_Sync)"
        return $false
    }
    $running = Test-SaveSync
    Set-Status $(if ($running) { 'Öffne SaveSync …' } else { 'Starte SaveSync …' })
    Start-Process -FilePath $cfg.Datei_Sync
    Wait-UI $(if ($running) { 4 } else { 6 }) | Out-Null
    Write-Log $(if ($running) { 'SaveSync geöffnet.' } else { 'SaveSync gestartet.' })
    $true
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

function Request-Abort {
    'Abbrechen' -eq (Show-Dialog $form 'Abbrechen?' 'Wirklich abbrechen? Es wird dann kein Blueprint-Backup erstellt.' @('Weiter warten', 'Abbrechen') 'warning')
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

# ============================================================ Ablauf
$form.Show()
[void][BPS.Win]::SetWindowTheme($txtLog.Handle, 'DarkMode_Explorer', $null)
[Windows.Forms.Application]::DoEvents()

try {
    # 1. Steam muss laufen, bevor SaveSync gestartet wird
    Set-Step 1 'active'
    if (Test-Steam) {
        Write-Log 'Steam läuft bereits.'
        Set-Step 1 'done'
    } else {
        Set-Status 'Starte Steam …'
        $steamExe = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamExe
        if ($steamExe -and (Test-Path -LiteralPath $steamExe)) { Start-Process -FilePath $steamExe }
        else { Start-Process 'steam://open/main' }
        if (Wait-UI 120 { Test-Steam }) {
            Set-Status 'Warte, bis Steam bereit ist …'
            Wait-UI 10 | Out-Null
            Write-Log 'Steam gestartet.'
            Set-Step 1 'done'
        } else {
            Write-Log 'Steam konnte nicht gestartet werden.'
            Set-Step 1 'error'
            $State.HadError = $true
        }
    }

    # 2. SaveSync starten bzw. in den Vordergrund holen
    Set-Step 2 'active'
    if (Start-SaveSync) { Set-Step 2 'done' } else { Set-Step 2 'error'; $State.HadError = $true }

    # 3. Countdown zum Ueberpruefen der Syncs
    Set-Step 3 'active'
    $form.TopMost = $true; $form.Activate(); $form.TopMost = $false
    $btnNext.Enabled = $true
    for ($s = 60; $s -ge 1; $s--) {
        Set-Progress ($s / 60)
        Set-Status "Überprüfe deine Syncs in SaveSync – noch $s Sekunden"
        if (Wait-UI 1 { $State.Skip }) { break }
    }
    Set-Progress 0
    $btnNext.Enabled = $false
    Set-Step 3 'done'

    # 4. Blueprints aus dem Ludusavi-Backup wiederherstellen
    Set-Step 4 'active'
    $step = 'done'
    $n = 0
    foreach ($w in $Worlds) {
        Set-Status "Stelle Blueprints für „$($w.Name)“ wieder her …"
        Set-Progress ($n++ / [Math]::Max(1, $Worlds.Count))
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
    Set-Progress 0
    Set-Step 4 $step

    # 5. Spiel starten
    Set-Step 5 'active'
    Set-Status 'Starte Satisfactory … warte, bis das Spiel geladen ist.'
    Start-Game
    Wait-UI ([int]::MaxValue) { Test-GameRunning } | Out-Null
    Wait-UI 10 | Out-Null
    Write-Log 'Satisfactory gestartet.'
    Set-Step 5 'done'

    # 6. Warten, bis das Spiel beendet wird
    Set-Step 6 'active'
    Set-Status 'Viel Spaß beim Spielen und Bauen!'
    $form.WindowState = 'Minimized'
    while (Test-GameRunning) { Wait-UI 2 | Out-Null }
    $form.WindowState = 'Normal'
    $form.Activate()
    Write-Log 'Satisfactory beendet.'
    Set-Step 6 'done'

    # 7. Neues Backup erstellen - SaveSync muss dafuer laufen (falls es beim Spielen geschlossen wurde)
    Set-Step 7 'active'
    $step = 'done'
    if (-not (Test-SaveSync)) {
        Write-Log 'SaveSync läuft nicht mehr – wird neu gestartet.'
        if (-not (Start-SaveSync)) { $step = 'error'; $State.HadError = $true }
    }
    $n = 0
    foreach ($w in $Worlds) {
        Set-Status "Erstelle Backup für „$($w.Name)“ …"
        Set-Progress ($n++ / [Math]::Max(1, $Worlds.Count))
        $code = Invoke-Ludusavi 'backup' $w.Backup
        if ($code -ne 0) { Write-Log "Backup fehlgeschlagen (Code $code): $($w.Backup)"; $step = 'error'; $State.HadError = $true }
        else { Write-Log "Gesichert: $($w.Backup)" }
    }
    Set-Progress 0
    Set-Step 7 $step

    # 8. Fertig
    Set-Step 8 $(if ($State.HadError) { 'warning' } else { 'done' })
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
