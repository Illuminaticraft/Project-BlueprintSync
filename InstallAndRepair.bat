<# : Batch-Teil - startet den PowerShell-Teil (Oberflaeche) dieser Datei
@echo off
setlocal
set "BPS_SELF=%~f0"
powershell -NoProfile -STA -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:BPS_SELF))"
exit /b %errorlevel%
#>

# ===================================================================
#  Install and Repair SatisfactoryBlueprintSync (PowerShell/WinForms)
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

$ConfigDir     = Join-Path $env:LOCALAPPDATA 'FactoryGame\BlueprintSync'
$ConfigPath    = Join-Path $ConfigDir 'BPSconfig.ini'
$BlueprintRoot = Join-Path $env:LOCALAPPDATA 'FactoryGame\Saved\SaveGames\Blueprints'
$SyncBat       = Join-Path (Split-Path $env:BPS_SELF) 'SatisfactoryBlueprintSync.bat'

$State = @{ SyncExe = $null; LuduExe = $null }

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

function New-Ctl($Type, $Parent, $X, $Y, $W, $H, $Props = @{}) {
    $c = New-Object "System.Windows.Forms.$Type"
    $c.SetBounds($X, $Y, $W, $H)
    foreach ($k in $Props.Keys) { $c.$k = $Props[$k] }
    $Parent.Controls.Add($c)
    $c
}

# ---------------------------------------------------------------- UI
$form = New-Object Windows.Forms.Form
$form.Text            = 'Satisfactory Blueprint Sync - Einrichtung'
$form.ClientSize      = New-Object Drawing.Size(560, 560)
$form.StartPosition   = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox     = $false
$form.Font            = New-Object Drawing.Font('Segoe UI', 9)

# 1. Programme
$grpProg = New-Ctl GroupBox $form 10 10 540 140 @{ Text = '1. Programme' }
New-Ctl Label $grpProg 10 22 520 34 @{ Text = 'Wähle den Ordner, in dem SaveSync.exe und ludusavi.exe liegen. Unterordner werden automatisch durchsucht.' } | Out-Null
$txtFolder = New-Ctl TextBox $grpProg 10 60 405 24 @{ ReadOnly = $true }
$btnBrowse = New-Ctl Button  $grpProg 420 58 110 27 @{ Text = 'Durchsuchen…' }
$lblSync   = New-Ctl Label   $grpProg 10 92 520 18 @{ Text = 'SaveSync.exe: –'; AutoEllipsis = $true }
$lblLudu   = New-Ctl Label   $grpProg 10 112 520 18 @{ Text = 'ludusavi.exe: –'; AutoEllipsis = $true }

# 2. Welten
$grpWorld = New-Ctl GroupBox $form 10 160 540 240 @{ Text = '2. Welten' }
New-Ctl Label $grpWorld 10 22 520 18 @{ Text = 'Für welche Welten sollen Blueprints synchronisiert werden?' } | Out-Null
$clbWorlds = New-Ctl CheckedListBox $grpWorld 10 44 520 130 @{ CheckOnClick = $true; IntegralHeight = $false }
$txtWorld  = New-Ctl TextBox $grpWorld 10 182 405 24
$btnAdd    = New-Ctl Button  $grpWorld 420 180 110 27 @{ Text = 'Hinzufügen' }
New-Ctl Label $grpWorld 10 212 520 18 @{ Text = 'Ludusavi-Backup je Welt: "<Weltname> Blueprints"'; ForeColor = [Drawing.Color]::DimGray } | Out-Null

# 3. Steam-Startoption
$grpSteam  = New-Ctl GroupBox $form 10 410 540 95 @{ Text = '3. Steam-Startoption (Eigenschaften → Allgemein → Startoptionen)' }
$txtLaunch = New-Ctl TextBox $grpSteam 10 26 405 24 @{ ReadOnly = $true }
$btnCopy   = New-Ctl Button  $grpSteam 420 24 110 27 @{ Text = 'Kopieren' }
$lblLaunch = New-Ctl Label   $grpSteam 10 56 520 34 @{ ForeColor = [Drawing.Color]::DimGray }

$btnSave   = New-Ctl Button $form 330 518 105 30 @{ Text = 'Speichern'; Enabled = $false }
$btnCancel = New-Ctl Button $form 445 518 105 30 @{ Text = 'Abbrechen'; DialogResult = 'Cancel' }
$form.CancelButton = $btnCancel

# ------------------------------------------------------------- Logik
function Set-ProgLabel($Label, $Name, $Path) {
    if ($Path) {
        $Label.Text = "✔ ${Name}: $Path"
        $Label.ForeColor = [Drawing.Color]::ForestGreen
    } else {
        $Label.Text = "✖ ${Name}: nicht gefunden"
        $Label.ForeColor = [Drawing.Color]::Firebrick
    }
}

function Update-SaveButton {
    $btnSave.Enabled = [bool]($State.SyncExe -and $State.LuduExe -and $clbWorlds.CheckedItems.Count -gt 0)
}

function Set-Folder($Folder) {
    $txtFolder.Text = $Folder
    $lblSync.Text = 'Suche SaveSync.exe und ludusavi.exe …'
    $lblSync.ForeColor = [Drawing.Color]::Black
    $lblLudu.Text = ''
    $form.Cursor = 'WaitCursor'
    [Windows.Forms.Application]::DoEvents()
    $State.SyncExe = Find-Program $Folder 'SaveSync.exe'
    $State.LuduExe = Find-Program $Folder 'ludusavi.exe'
    $form.Cursor = 'Default'
    Set-ProgLabel $lblSync 'SaveSync.exe' $State.SyncExe
    Set-ProgLabel $lblLudu 'ludusavi.exe' $State.LuduExe
    Update-SaveButton
}

function Add-World($Name, [bool]$Checked) {
    $Name = "$Name".Trim()
    if (-not $Name) { return }
    $idx = $clbWorlds.Items.IndexOf($Name)
    if ($idx -lt 0) { $idx = $clbWorlds.Items.Add($Name) }
    if ($Checked) { $clbWorlds.SetItemChecked($idx, $true) }
}

$btnBrowse.add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Ordner mit SaveSync.exe und ludusavi.exe auswählen'
    $dlg.ShowNewFolderButton = $false
    if ($txtFolder.Text -and (Test-Path -LiteralPath $txtFolder.Text)) { $dlg.SelectedPath = $txtFolder.Text }
    if ($dlg.ShowDialog($form) -eq 'OK') { Set-Folder $dlg.SelectedPath }
})

$btnAdd.add_Click({
    Add-World $txtWorld.Text $true
    $txtWorld.Clear()
    Update-SaveButton
})

# CheckedItems ist erst nach dem ItemCheck-Ereignis aktuell
$clbWorlds.add_ItemCheck({ $form.BeginInvoke([Action]{ Update-SaveButton }) | Out-Null })

$txtWorld.add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq 'Enter') { $btnAdd.PerformClick(); $e.SuppressKeyPress = $true }
})

$btnCopy.add_Click({ if ($txtLaunch.Text) { [Windows.Forms.Clipboard]::SetText($txtLaunch.Text) } })

$btnSave.add_Click({
    $worlds = @($clbWorlds.CheckedItems)
    $lines = @(
        '[Version]'
        'Version=1.0'
        '[Paths]'
        "Datei_Sync=$($State.SyncExe)"
        "Datei_Ludosavi=$($State.LuduExe)"
        '[Blueprints]'
        "AnzahlBlueprints=$($worlds.Count)"
    )
    for ($i = 0; $i -lt $worlds.Count; $i++) {
        $lines += "Blueprint$($i + 1)=$($worlds[$i])"
        $lines += "Ludusavi_Backup$($i + 1)=$($worlds[$i]) Blueprints"
    }
    try {
        New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
        [IO.File]::WriteAllLines($ConfigPath, [string[]]$lines)
    } catch {
        [Windows.Forms.MessageBox]::Show($form, "Die Konfiguration konnte nicht gespeichert werden:`n$($_.Exception.Message)",
            'Fehler', 'OK', 'Error') | Out-Null
        return
    }
    [Windows.Forms.MessageBox]::Show($form, "Konfiguration gespeichert:`n$ConfigPath",
        'Fertig', 'OK', 'Information') | Out-Null
    $form.DialogResult = 'OK'
    $form.Close()
})

# --------------------------------------------- Vorbelegen (Reparatur)
if (Test-Path -LiteralPath $SyncBat) {
    $txtLaunch.Text = "`"$SyncBat`" %command%"
    $lblLaunch.Text = 'Diesen Text in Steam bei Satisfactory unter Startoptionen eintragen.'
} else {
    $btnCopy.Enabled = $false
    $lblLaunch.Text = "SatisfactoryBlueprintSync.bat wurde nicht neben diesem Installer gefunden."
    $lblLaunch.ForeColor = [Drawing.Color]::Firebrick
}

$cfg = Read-Config
if ($cfg.Datei_Sync -and (Test-Path -LiteralPath $cfg.Datei_Sync) -and
    $cfg.Datei_Ludosavi -and (Test-Path -LiteralPath $cfg.Datei_Ludosavi)) {
    $State.SyncExe = $cfg.Datei_Sync
    $State.LuduExe = $cfg.Datei_Ludosavi
    $txtFolder.Text = Split-Path $cfg.Datei_Sync
    Set-ProgLabel $lblSync 'SaveSync.exe' $State.SyncExe
    Set-ProgLabel $lblLudu 'ludusavi.exe' $State.LuduExe
}

if (Test-Path -LiteralPath $BlueprintRoot) {
    Get-ChildItem -LiteralPath $BlueprintRoot -Directory | ForEach-Object { Add-World $_.Name $false }
}
for ($i = 1; $i -le [int]$cfg.AnzahlBlueprints; $i++) { Add-World $cfg["Blueprint$i"] $true }
Update-SaveButton

[void]$form.ShowDialog()
