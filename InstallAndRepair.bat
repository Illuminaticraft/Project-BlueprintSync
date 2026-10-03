<# : Batch-Teil - startet den PowerShell-Teil (Oberflaeche) dieser Datei
@echo off
setlocal
set "BPS_SELF=%~f0"
powershell -NoProfile -STA -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:BPS_SELF))"
exit /b %errorlevel%
#>

# ===================================================================
#  Install and Repair SatisfactoryBlueprintSync (PowerShell/WinForms)
#
#  Liegt zusammen mit SatisfactoryBlueprintSync.bat im Ludusavi-Backup, z.B.
#  ...\ludusavi-backup\<Backup>\drive-C\...\SaveGames\blueprints\<Welt>
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

$ConfigDir    = Join-Path $env:LOCALAPPDATA 'FactoryGame\BlueprintSync'
$ConfigPath   = Join-Path $ConfigDir 'BPSconfig.ini'
$ScriptDir    = Split-Path $env:BPS_SELF
$SyncSource   = Join-Path $ScriptDir 'SatisfactoryBlueprintSync.bat'
$SyncTarget   = Join-Path $ConfigDir 'SatisfactoryBlueprintSync.bat'
$LaunchOption = "`"$SyncTarget`" %command%"

$State = @{ SyncExe = $null; LuduExe = $null; LastFolder = $null; BackupRoot = $null; Rows = @() }

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

function New-Card($Parent, $X, $Y, $W, $H, [string]$Title) {
    $card = New-Ctl Panel $Parent $X $Y $W $H @{ BackColor = $T.Card }
    if ($Title) {
        # Ganz nach hinten, damit die Ueberschrift keine Buttons in der Kartenecke verdeckt
        $heading = New-Ctl Label $card 18 14 ($W - 36) 24 @{ Text = $Title; Font = (New-Font 11 'Bold') }
        $heading.SendToBack()
    }
    $card
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

# Textfeld ohne System-Rahmen in einem dunklen Panel
function New-Input($Parent, $X, $Y, $W, [switch]$ReadOnly) {
    $box = New-Ctl Panel $Parent $X $Y $W 34 @{ BackColor = $T.Input }
    New-Ctl TextBox $box 10 8 ($W - 20) 20 @{
        BorderStyle = 'None'; BackColor = $T.Input; ForeColor = $T.Text; ReadOnly = [bool]$ReadOnly; Font = (New-Font 9.5)
    }
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

# Sucht ein Programm im Ordner und allen Unterordnern
function Find-Program($Folder, $Name) {
    $direct = Join-Path $Folder $Name
    if (Test-Path -LiteralPath $direct -PathType Leaf) { return $direct }
    $hit = Get-ChildItem -LiteralPath $Folder -Filter $Name -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($hit) { $hit.FullName }
}

# Ludusavi-Backup-Ordner: zwei Ebenen ueber dem ersten "drive-*"-Ordner im Pfad
function Find-BackupRoot([string]$Start) {
    $dir = $Start
    while ($dir) {
        if ((Split-Path $dir -Leaf) -like 'drive-*') { return Split-Path (Split-Path $dir) }
        $dir = Split-Path $dir
    }
}

# Alle Blueprint-Backups: <Root>\<Backup>\drive-*\...\SaveGames\blueprints\<Welt>
function Get-BlueprintBackups([string]$Root) {
    foreach ($backup in Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue) {
        foreach ($drive in Get-ChildItem -LiteralPath $backup.FullName -Directory -Filter 'drive-*' -ErrorAction SilentlyContinue) {
            Get-ChildItem -LiteralPath $drive.FullName -Directory -Recurse -Depth 12 -Filter 'blueprints' -ErrorAction SilentlyContinue |
                Where-Object { $_.Parent.Name -eq 'SaveGames' } |
                ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Directory -ErrorAction SilentlyContinue } |
                ForEach-Object { [pscustomobject]@{ World = $_.Name; Backup = $backup.Name } }
        }
    }
}

$cfg = Read-Config
$Configured = @(for ($i = 1; $i -le [int]$cfg.AnzahlBlueprints; $i++) {
    "$($cfg["Blueprint$i"])|$($cfg["Ludusavi_Backup$i"])"
})

# ================================================================ UI
$form = New-DarkForm 'Satisfactory Blueprint Sync – Einrichtung' 620 700
$form.KeyPreview = $true

New-Ctl Label $form 22 16 576 34 @{ Text = 'Blueprint Sync einrichten'; Font = (New-Font 17 'Bold') } | Out-Null
New-Ctl Label $form 24 52 576 22 @{ Text = 'Synchronisiert eure Satisfactory-Blueprints über SaveSync und Ludusavi.'; ForeColor = $T.Muted } | Out-Null

# 1. Programme
$card1 = New-Card $form 20 88 580 172 '1   Programme'
New-Ctl Label $card1 18 40 544 36 @{ ForeColor = $T.Muted; Text = 'Ordner mit SaveSync.exe und ludusavi.exe auswählen oder den Pfad mit Strg+V einfügen. Unterordner werden automatisch durchsucht.' } | Out-Null
$txtFolder = New-Input $card1 18 80 420
$btnBrowse = New-Button $card1 'Durchsuchen…' 448 80 114 34
$prog = @{}
foreach ($p in @(@{ Key = 'Sync'; Y = 124 }, @{ Key = 'Ludu'; Y = 146 })) {
    $prog[$p.Key] = @{
        Icon = New-Ctl Label $card1 18 $p.Y 22 20 @{ Font = (New-Font 10 'Regular' 'Segoe UI Symbol'); ForeColor = $T.Muted; Text = '○' }
        Text = New-Ctl Label $card1 42 $p.Y 520 20 @{ AutoEllipsis = $true; ForeColor = $T.Muted }
    }
}

# 2. Welten
$card2 = New-Card $form 20 272 580 236 '2   Welten'
New-Ctl Label $card2 18 40 420 20 @{ ForeColor = $T.Muted; Text = 'Gefundene Blueprint-Backups – wähle die Welten zum Synchronisieren:' } | Out-Null
$btnRoot   = New-Button $card2 'Ordner ändern…' 448 12 114 30
$lblRoot   = New-Ctl Label $card2 18 62 544 18 @{ ForeColor = $T.Muted; AutoEllipsis = $true; Font = (New-Font 8.5) }
$lstWorlds = New-Ctl Panel $card2 18 86 544 132 @{ BackColor = $T.Input; AutoScroll = $true }

# 3. Steam-Startoption
$card3 = New-Card $form 20 520 580 112 '3   Steam-Startoption'
$txtLaunch = New-Input $card3 18 44 420 -ReadOnly
$txtLaunch.Text = $LaunchOption
$btnCopy = New-Button $card3 'Kopieren' 448 44 114 34
New-Ctl Label $card3 18 84 544 18 @{ ForeColor = $T.Muted; Font = (New-Font 8.5); Text = 'Steam → Satisfactory → Eigenschaften → Allgemein → Startoptionen' } | Out-Null

$btnCancel = New-Button $form 'Abbrechen' 380 648 100 36
$btnSave   = New-Button $form 'Speichern' 490 648 110 36 -Primary
$btnSave.Enabled = $false
$btnCancel.add_Click({ $form.Close() })

# ------------------------------------------------------------ Ablauf
function Update-SaveButton {
    $checked = @($State.Rows | Where-Object { $_.Check.Checked }).Count
    $btnSave.Enabled = [bool]($State.SyncExe -and $State.LuduExe -and $checked -gt 0)
}

function Set-ProgStatus($Key, [string]$Name, [string]$Path, [string]$Hint, [switch]$IsError) {
    $p = $prog[$Key]
    if ($Path) {
        $p.Icon.Text = '✔'; $p.Icon.ForeColor = $T.Ok
        $p.Text.Text = "${Name}  –  $Path"; $p.Text.ForeColor = $T.Text
    } elseif ($Hint -and -not $IsError) {
        $p.Icon.Text = '○'; $p.Icon.ForeColor = $T.Muted
        $p.Text.Text = $Hint; $p.Text.ForeColor = $T.Muted
    } else {
        if (-not $Hint) { $Hint = "$Name nicht gefunden" }
        $p.Icon.Text = '✖'; $p.Icon.ForeColor = $T.Err
        $p.Text.Text = $Hint; $p.Text.ForeColor = $T.Err
    }
}

function Set-Folder([string]$Folder) {
    if ($Folder -eq $State.LastFolder) { return }
    $State.LastFolder = $Folder
    Set-ProgStatus 'Sync' 'SaveSync.exe' $null 'Suche SaveSync.exe …'
    Set-ProgStatus 'Ludu' 'ludusavi.exe' $null 'Suche ludusavi.exe …'
    $form.Cursor = 'WaitCursor'
    [Windows.Forms.Application]::DoEvents()
    $State.SyncExe = Find-Program $Folder 'SaveSync.exe'
    $State.LuduExe = Find-Program $Folder 'ludusavi.exe'
    $form.Cursor = 'Default'
    Set-ProgStatus 'Sync' 'SaveSync.exe' $State.SyncExe
    Set-ProgStatus 'Ludu' 'ludusavi.exe' $State.LuduExe
    Update-SaveButton
}

# Eingetippten/eingefuegten Pfad pruefen (kurz verzoegert, damit nicht bei jedem Zeichen gesucht wird)
function Resolve-FolderInput {
    $path = $txtFolder.Text.Trim().Trim('"')
    if (-not $path) { return }
    try {
        if (Test-Path -LiteralPath $path -PathType Leaf) { $path = Split-Path $path }
        $exists = Test-Path -LiteralPath $path -PathType Container
    } catch { $exists = $false }
    if ($exists) {
        Set-Folder $path
        if ($txtFolder.Text -ne $path) { $txtFolder.Text = $path; $txtFolder.SelectionStart = $path.Length }
        return
    }
    $State.LastFolder = $null; $State.SyncExe = $null; $State.LuduExe = $null
    Set-ProgStatus 'Sync' 'SaveSync.exe' $null 'Ordner nicht gefunden' -IsError
    Set-ProgStatus 'Ludu' 'ludusavi.exe' $null ' '
    Update-SaveButton
}

$folderTimer = New-Object Windows.Forms.Timer
$folderTimer.Interval = 500
$folderTimer.add_Tick({ $folderTimer.Stop(); Resolve-FolderInput })
$txtFolder.add_TextChanged({ $folderTimer.Stop(); $folderTimer.Start() })

# Strg+V: Text oder einen im Explorer kopierten Ordner als Programm-Ordner uebernehmen
$form.add_KeyDown({
    param($s, $e)
    if (-not ($e.Control -and $e.KeyCode -eq 'V')) { return }
    $value = $null
    if ([Windows.Forms.Clipboard]::ContainsFileDropList()) {
        $value = [Windows.Forms.Clipboard]::GetFileDropList()[0]
    } elseif ($form.ActiveControl -ne $txtFolder -and [Windows.Forms.Clipboard]::ContainsText()) {
        $value = [Windows.Forms.Clipboard]::GetText().Trim().Trim('"')
    }
    if ($value) {
        $txtFolder.Text = $value
        $txtFolder.SelectionStart = $txtFolder.Text.Length
        $e.Handled = $true; $e.SuppressKeyPress = $true
    }
})

$btnBrowse.add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Ordner mit SaveSync.exe und ludusavi.exe auswählen'
    $dlg.ShowNewFolderButton = $false
    if ($State.LastFolder) { $dlg.SelectedPath = $State.LastFolder }
    if ($dlg.ShowDialog($form) -eq 'OK') {
        $txtFolder.Text = $dlg.SelectedPath
        $folderTimer.Stop()
        Set-Folder $dlg.SelectedPath
    }
})

function Load-Backups([string]$Root) {
    # Bisherige Auswahl (Konfiguration + aktuell angehakt) beibehalten
    $keep = @($Configured) + @($State.Rows | Where-Object { $_.Check.Checked } | ForEach-Object { "$($_.World)|$($_.Backup)" })
    $lstWorlds.Controls.Clear()
    $State.Rows = @()
    $State.BackupRoot = $Root

    if (-not $Root) {
        $lblRoot.Text = ''
        New-Ctl Label $lstWorlds 12 12 510 60 @{ ForeColor = $T.Muted; Text = 'Kein Ludusavi-Backup-Ordner erkannt. Bitte über „Ordner ändern…“ den Backup-Ordner auswählen (z.B. C:\Users\Name\ludusavi-backup).' } | Out-Null
        Update-SaveButton
        return
    }
    $lblRoot.Text = $Root
    $form.Cursor = 'WaitCursor'
    $items = @(Get-BlueprintBackups $Root | Sort-Object World, Backup -Unique)
    $form.Cursor = 'Default'
    if (-not $items) {
        New-Ctl Label $lstWorlds 12 12 510 40 @{ ForeColor = $T.Muted; Text = 'In diesem Ordner wurden keine Blueprint-Backups gefunden.' } | Out-Null
    }
    $y = 6
    foreach ($it in $items) {
        $key = "$($it.World)|$($it.Backup)"
        # Ohne bisherige Konfiguration sind alle gefundenen Welten vorausgewaehlt
        $cb = New-Ctl CheckBox $lstWorlds 12 $y 270 26 @{
            Text = $it.World; FlatStyle = 'Flat'; ForeColor = $T.Text; Cursor = 'Hand'; AutoEllipsis = $true
            Checked = ($keep -contains $key) -or ($keep.Count -eq 0)
        }
        $cb.FlatAppearance.BorderColor = $T.Muted
        $cb.FlatAppearance.CheckedBackColor = $T.Accent
        $cb.add_CheckedChanged({ Update-SaveButton })
        New-Ctl Label $lstWorlds 290 ($y + 4) 230 20 @{ Text = "Backup: $($it.Backup)"; ForeColor = $T.Muted; AutoEllipsis = $true; Font = (New-Font 8.5) } | Out-Null
        $State.Rows += [pscustomobject]@{ Check = $cb; World = $it.World; Backup = $it.Backup }
        $y += 30
    }
    Update-SaveButton
}

$btnRoot.add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Ludusavi-Backup-Ordner auswählen (z.B. C:\Users\Name\ludusavi-backup)'
    $dlg.ShowNewFolderButton = $false
    if ($State.BackupRoot) { $dlg.SelectedPath = $State.BackupRoot }
    if ($dlg.ShowDialog($form) -eq 'OK') {
        $path = $dlg.SelectedPath
        $root = Find-BackupRoot $path
        if (-not $root -and @(Get-ChildItem -LiteralPath $path -Directory -Filter 'drive-*' -ErrorAction SilentlyContinue).Count) {
            $root = Split-Path $path   # ein einzelnes Backup gewaehlt
        }
        if (-not $root) { $root = $path }
        Load-Backups $root
    }
})

$btnCopy.add_Click({ [Windows.Forms.Clipboard]::SetText($LaunchOption) })

$btnSave.add_Click({
    $sel = @($State.Rows | Where-Object { $_.Check.Checked })
    $lines = @(
        '[Version]'
        'Version=1.0'
        '[Paths]'
        "Datei_Sync=$($State.SyncExe)"
        "Datei_Ludosavi=$($State.LuduExe)"
        "Backup_Ordner=$($State.BackupRoot)"
        '[Blueprints]'
        "AnzahlBlueprints=$($sel.Count)"
    )
    for ($i = 0; $i -lt $sel.Count; $i++) {
        $lines += "Blueprint$($i + 1)=$($sel[$i].World)"
        $lines += "Ludusavi_Backup$($i + 1)=$($sel[$i].Backup)"
    }
    try {
        New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
        # Sync-Skript an den festen Ort kopieren, auf den die Steam-Startoption zeigt
        if (Test-Path -LiteralPath $SyncSource) {
            if ($SyncSource -ne $SyncTarget) { Copy-Item -LiteralPath $SyncSource -Destination $SyncTarget -Force }
        } elseif (-not (Test-Path -LiteralPath $SyncTarget)) {
            throw "SatisfactoryBlueprintSync.bat wurde nicht im Ordner des Installers gefunden:`n$ScriptDir"
        }
        [IO.File]::WriteAllLines($ConfigPath, [string[]]$lines)
    } catch {
        Show-Dialog $form 'Fehler' "Die Einrichtung konnte nicht abgeschlossen werden:`n`n$($_.Exception.Message)" @('OK') 'error' | Out-Null
        return
    }
    [Windows.Forms.Clipboard]::SetText($LaunchOption)
    Show-Dialog $form 'Fertig' ("Einrichtung abgeschlossen – $($sel.Count) Welt(en) werden synchronisiert.`n`n" +
        "Trage jetzt in Steam bei Satisfactory unter Startoptionen ein (bereits in der Zwischenablage):`n`n$LaunchOption") @('OK') 'success' | Out-Null
    $form.Close()
})

# --------------------------------------------- Vorbelegen (Reparatur)
if ($cfg.Datei_Sync -and (Test-Path -LiteralPath $cfg.Datei_Sync) -and
    $cfg.Datei_Ludosavi -and (Test-Path -LiteralPath $cfg.Datei_Ludosavi)) {
    $State.SyncExe = $cfg.Datei_Sync
    $State.LuduExe = $cfg.Datei_Ludosavi
    $State.LastFolder = Split-Path $cfg.Datei_Sync
    $txtFolder.Text = $State.LastFolder
    $folderTimer.Stop()
    Set-ProgStatus 'Sync' 'SaveSync.exe' $State.SyncExe
    Set-ProgStatus 'Ludu' 'ludusavi.exe' $State.LuduExe
} else {
    Set-ProgStatus 'Sync' 'SaveSync.exe' $null 'SaveSync.exe – noch kein Ordner gewählt'
    Set-ProgStatus 'Ludu' 'ludusavi.exe' $null 'ludusavi.exe – noch kein Ordner gewählt'
}

$root = Find-BackupRoot $ScriptDir
if (-not $root -and $cfg.Backup_Ordner -and (Test-Path -LiteralPath $cfg.Backup_Ordner)) { $root = $cfg.Backup_Ordner }
$form.add_Shown({
    Load-Backups $root
    [void][BPS.Win]::SetWindowTheme($lstWorlds.Handle, 'DarkMode_Explorer', $null)
    $btnBrowse.Focus()
})

[void]$form.ShowDialog()
