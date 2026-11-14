<# : Batch-Teil - startet den PowerShell-Teil (Oberflaeche) dieser Datei
@echo off
setlocal
set "BPS_SELF=%~f0"
powershell -WindowStyle Hidden -NoProfile -STA -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:BPS_SELF))"
exit /b %errorlevel%
#>

# ===================================================================
#  Install and Repair SatisfactoryBlueprintSync (PowerShell/WinForms)
#
#  Liegt zusammen mit SatisfactoryBlueprintSync.bat im Ludusavi-Backup, z.B.
#  ...\ludusavi-backup\<Backup>\drive-C\...\SaveGames\blueprints\<Welt>
# ===================================================================

# -------------------------------------------------------------------
#  VERSION dieses Installers
#  Bei jeder Aenderung an SatisfactoryBlueprintSync.bat hier von Hand
#  hochzaehlen. Weicht sie von der Version in der BPSconfig.ini ab, wird
#  das Sync-Skript beim Start automatisch aktualisiert (siehe Updater).
# -------------------------------------------------------------------
$Version = '1.1'

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

# -------------------------------------------------------------------
#  Programm-Symbol (Blueprint Sync, 16/32/48 px als Base64 eingebettet)
#  Wird in New-DarkForm fuer alle Fenster gesetzt. Ein Fehler hier darf
#  den Ablauf nie blockieren, dann bleibt einfach das Standard-Symbol.
# -------------------------------------------------------------------
$BpsIconB64 = (@(
'AAABAAMAEBAAAAEAIABoBAAANgAAACAgAAABACAAqBAAAJ4EAAAwMAAAAQAgAKglAABGFQAAKAAAABAAAAAgAAAAAQAgAAAAAABA',
'BAAAAAAAAAAAAAAAAAAAAAAAAAAAAABJk/hMSJX6z0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9IlfnL',
'SpT3SAAAAABKlPdISZX5+0mV+v9Jlfr/SZX6/0mV+v9IkvP/PGSa/zVYif9Hjez/SZX6/0mV+v9Jlfr/SZX6/0mV+ftKlPdISJX7',
'y0mV+v9Jlfr/SZX6/0mT9/89Zp3/Ojo9/1ZebP9WZnz/OzxA/zhgl/9IkfP/SZX6/0mV+v9Jlfr/SJX7y0mV+v9Jlfr/SZP3/z5r',
'qP9CRk//Zl9Z/1BMR/8iIyX/JCgt/0hEP/9qZF//OzxA/zpmov9Ik/f/SZX6/0mV+v9Jlfr/SZX6/zxJXf9TZH7/VlJN/x0ZFP8e',
'HRv/LURh/y5EYv8eHRv/HRkU/1ZSTf9OYHr/N0RZ/0mV+v9Jlfr/SZX6/0mV+v9Ij+3/RWqb/25tb/9FS1T/NleE/zBAVf8wQFX/',
'NleE/0hOV/93dHL/RGeX/0iP7f9Jlfr/SZX6/0mV+v9Jlfr/SZX6/zROcf9Ij+3/Qmym/z1sq/86Y5r/OmGX/zRQdP9Fbqb/SIzn',
'/zROcf9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v80TnH/SZX6/zhcjP8xRWD/KSgo/ycjHv9OSkb/OFyM/0mV+v80TnH/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/NE5x/0mV+v8/c7n/dnJu/397eP+MiIX/wb26/z9zuf9Jlfr/NE5x/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/zROcf9Jlfr/SZX6/zdZhf9mY2H/ZmNh/zdZhf9Jlfr/SZX6/zROcf9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v80TnH/',
'SZX6/0F5w/80UHT/Qn7O/0J8yv80UHT/QHfA/0mV+v80TnH/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/Mkdj/zNKav86Y5r/SJLz',
'/0WH3/9DgNH/SZP3/ztlnf8zSmr/Mkdj/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/z1sq/89ba3/RIPY/0mV+v9Fh9//Q4DR/0mV',
'+v9EhNr/PW2t/z1sq/9Jlfr/SZX6/0mV+v9JlPrTSZX6/0mV+v9Jlfr/SZT4/0OA0f8+b7D/QHa9/z9ytv8+cLL/Qn/P/0mU+P9J',
'lfr/SZX6/0mV+v9JlfrPSZX4UEmV+v9Jlfr/SZX6/0mV+v9Jlfr/SZT4/zxppf87Z6D/SZP3/0mV+v9Jlfr/SZX6/0mV+v9Jlfn7',
'SZP4TAAAAABJlfhQSZT600mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9IlfnLSpT3SAAAAAAAAAAAAAAA',
'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAKAAAACAAAABAAAAAAQAgAAAA',
'AACAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE+P/xBIlPh4SJX6z0mU+fdJlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9JlPn3SZT5x0iU+HhPj/8QAAAAAAAAAAAAAAAA',
'AAAAAAAAAABKlPdISJT660mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+uNHk/tAAAAAAAAAAAAAAAAAR5b7REmV+ftJlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Gi+X/Q4Ta/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+ftHk/tAAAAAAE+P/xBIlPrrSZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Gi+X/OFZ+/ywpJf8hHRr/L0ls/0OE2v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+uNPj/8QSJT4eEmV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Gi+X/OFZ+/ywpJf8xKiL/Oz5F/zpA',
'S/8rJB7/IR0a/y9JbP9DhNr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0iU+HhIlfvLSZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Gi+X/OFZ+/ywpJf8yKiP/S0M7/5KLhv9jkc7/WpLd/5ONiP9TS0T/KyQe/yEdGv8vSWz/',
'RYrl/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZT7x0mU+fdJlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Gi+X/OFZ+',
'/ywpJf8yKiP/VUxF/52Xk/96dnL/JCAb/zBKbP8zVH//IBwY/2xoZP+TjYj/U0tE/yskHv8iIB7/MlF6/0WK5f9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9JlPn3SZX6/0mV+v9Jlfr/SZX6/0mV+v9Gi+X/OFZ+/ywpJf8yKiP/VUxF/52Xk/96dnL/JCAb/x0ZFP8d',
'GRT/Ih4Z/yMfGv8dGRT/HRkU/yAcGP9zb2v/pqCc/15VT/8tJh//IiAe/zJRev9FiuX/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/O2GT/y0pJf8zKyT/XlZP/6Calv96dnL/JCAb/x0ZFP8dGRT/HRkU/x0ZFP8iHhn/Ix8a/x0ZFP8dGRT/HRkU',
'/x0ZFP8kIBv/fXl1/6mjn/9eVU//LSYf/yIgHv82XI//SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v87UG3/QTgw/2KA',
'q/9pkcf/JCAb/x0ZFP8dGRT/HRkU/x0ZFP8hIyb/ME11/zpnov86Z6L/ME11/yEjJv8dGRT/HRkU/x0ZFP8dGRT/JCAb/2iJtP9V',
'eq7/QDcv/zZMav9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Fd7n/RnzG/2Ka5f+Sjov/Mi4p/x0ZFP8dGRT/',
'Lkpu/0F6xv8zTG3/LDVA/yw1QP8zTG3/QXrG/y5Kbv8dGRT/HRkU/zIuKf+Sjov/cJ3a/0eG2v9Fd7n/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v86Y5r/NUZe/1FYZf+fmZT/ko6L/z1Zf/87ZZ3/KCUi/ysxOv82VX7/NlV+/ysx',
'Ov8oJSL/O2Wd/z1Zf/+Sjov/n5mU/1FYZf80RFv/OmOa/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/zhcjP80TnH/SZX6/0V3uf9TZH//R33G/y46S/82VX//SJLz/z9zuf8/c7n/SJLz/zZVf/8oJSL/R33G/1VieP9Fd7n/',
'SZX6/zROcf84XIz/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/OFyM/zROcf9Jlfr/SZX6',
'/0mV+v8xQ1z/PGqo/0mV+v8xQ1z/JyMe/ycjHv8vPlL/QnzK/ycjHv8xQ1z/SZX6/0mV+v9Jlfr/NE5x/zhcjP9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v84XIz/NE5x/0mV+v9Jlfr/SZX6/ykoKf85YZf/O2Wd/y03RP8n',
'Ix7/JyMe/ycjHv8nIx7/JyMe/ykoKf9Jlfr/SZX6/0mV+v80TnH/OFyM/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/zhcjP80TnH/SZX6/0mV+v9Jlfr/KCUi/ycjHv8nIx7/JyMe/ycjHv8nIx7/Liol/2xoZP95dXH/KCUi',
'/0mV+v9Jlfr/SZX6/zROcf84XIz/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/OFyM/zRO',
'cf9Jlfr/SZX6/0mV+v8uOkv/JyMe/62ppv87NzL/JyMe/ycjHv9iXlr/+PTy/6qmo/8uOkv/SZX6/0mV+v9Jlfr/NE5x/zhcjP9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v84XIz/NE5x/0mV+v9Jlfr/SZX6/zxqqP8nIx7/',
'sKyp/+Hd2/+QjIj/kIyI/+Hd2/+0sK3/X1tX/zxqqP9Jlfr/SZX6/0mV+v80TnH/OFyM/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/zhcjP80TnH/SZX6/0mV+v9Jlfr/SZX6/zNKav8nIx7/cm5q/6qmo/+qpqP/cm5q/ycj',
'Hv8zSmr/SZX6/0mV+v9Jlfr/SZX6/zROcf84XIz/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/OFyM/zROcf9Jlfr/SZX6/0mV+v9Jlfr/SZX6/ztlnf8rMDb/JyMe/ycjHv8rMDb/O2Wd/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'NE5x/zhcjP9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v84XIz/NE5x/0mV+v9Jlfr/SZX6',
'/0mV+v9DgNH/NVN7/z5xtf9Ehdv/RYbd/z9zuf80UHT/QXnD/0mV+v9Jlfr/SZX6/0mV+v80TnH/OFyM/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/zhcjP80TnH/SZX6/0mV+v9DgNH/Mkdj/yglIv80TnH/RIXb/0F5w/8+',
'cbX/Rorl/zZVfv8oJyX/MEFZ/0OA0f9Jlfr/SZX6/zROcf84XIz/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/OFyM/zROcf9DgNH/Mkdj/yglIv80TnH/RIXb/0mV+v9Jlfr/QXnD/z5xtf9Jlfr/SZX6/0aK5f80UHT/KCUi',
'/zJHY/9DgNH/NE5x/zhcjP9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v84XIz/KSos/ygl',
'Iv80TnH/RIXb/0mV+v9Jlfr/SZX6/0mV+v9BecP/PnG1/0mV+v9Jlfr/SZX6/0mV+v9Ehdv/NE5x/yglIv8pKiz/OFyM/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/zpil/8uOUn/OV+R/0WH3/9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0F5w/8+cbX/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Fh9//OV+R/y45Sf86Ypf/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZT5',
'90mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0iQ8P9Adbz/OV6Q/zxqqP9Fh9//SZX6/0mV+v9Jlfr/QXnD/z5xtf9Jlfr/SZX6/0mV',
'+v9FiOD/PGqo/zlekP9Adbz/SJDw/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mU+fdJlfvPSZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9IkPD/QHW8/zlekP88aqj/RYff/0mV+v9BecP/PnG1/0mV+v9Giub/PW6v/zlekP9Adbz/SJDw/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX7z0qU+HxJlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SJDw',
'/0B1vP85XpD/PGqo/z1sq/87Z6L/PW6v/zhdjv8+cbX/R43r/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9IlPh4T4//EEiU+utJlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0iQ8P89bKv/LTVB/ysxOf88',
'aab/R43r/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SJT660+P/xAAAAAASpT3SEmV+ftJlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9FieL/RYbd/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+ftKlPdIAAAAAAAAAAAAAAAASpT3SEiU+utJlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9I',
'lPrrR5b7RAAAAAAAAAAAAAAAAAAAAAAAAAAAT4//EEeU+HxIlfrPSZT590mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mU+fdIlfnLSJT4eE+P/xAAAAAAAAAAAAAAAAAAAAAAAAAA',
'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACgAAAAwAAAAYAAAAAEAIAAAAAAAgCUAAAAAAAAA',
'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABHl/cgSZT5hEmV+8NJlfnvSZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0iU+utJlfvDR5T4fEeX9yAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATJn/FEmV',
'+p9Jlfn7SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+ftJlfqf',
'TJn/FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABIlPo8SJX650mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX640iW+jgAAAAAAAAAAAAAAAAAAAAAAAAAAEiW+jhJ',
'lfnzSZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+fNIlvo4AAAAAAAAAAAAAAAATJn/FEiV+udJlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/RIDR/zVIY/8qOk//P3fB/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9JlfrjTJn/FAAAAAAAAAAA',
'SZX6n0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0SA0f81SGP/KyUe/ywmHv8iHRf/IBsW/yo6T/8/d8H/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6nwAAAABHl/cgSZX5+0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9EgNH/NUhj/yslHv8sJh7/Mysk/zsxKv86MSn/Lych/yIdF/8gGxb/',
'KjpP/z93wf9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX5',
'+0eX9yBKlPh8SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/RIDR/zVI',
'Y/8rJR7/LCYe/zMrJP87Mir/eG9p/1OL1f9Fg9X/g3t2/z41Lf8vJyH/Ih0X/yAbFv8qOk//P3fB/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0qU+HxJlfvDSZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0J5w/81SGP/KyUe/ywmHv8zKyT/OzIq/3hvaf/Oycb/mJSR/0uN5P9Jlfr/i4eD',
'/9DLyP+De3b/PjUt/y8nIf8iHRf/IBsW/yo6T/8/d8H/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+8NIlPrrSZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9CecP/M0FV/yslHv8s',
'Jh7/Mysk/zsyKv94b2n/zsnG/5iUkf8yLin/HRkU/0B4wv9Ehdv/HRkU/ysnIv+Lh4P/0MvI/4N7dv8+NS3/Lych/yIdF/8gGxb/',
'KjpP/z93wf9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0iU+utJlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/QnnD/zNBVf8rJR7/LCYf/zQsJf8+NS3/e3Js/87Jxv+YlJH/Mi4p/x0ZFP8dGRT/HRkU/yYi',
'Hf8mIh3/HRkU/x0ZFP8dGRT/Kyci/4uHg//Qy8j/g3t2/z41Lf8vJyH/Ih0X/yAbFv8qOk//P3fB/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0J5w/8zQVX/KyUe/ywmH/80LCX/',
'PzUt/4N7dv/X0s//mJSR/zIuKf8dGRT/HRkU/x0ZFP8dGRT/HRkU/yYiHf8mIh3/HRkU/x0ZFP8dGRT/HRkU/x0ZFP8uKiX/mJSR',
'/9fSz/+De3b/PjUt/y8nIf8iHRf/IBsW/yo6T/8/d8H/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Cfcr/M0FV/yslHv8sJh//NCwl/z81Lf+De3b/19LP/5iUkf8yLin/HRkU/x0ZFP8dGRT/HRkU/x0ZFP8d',
'GRT/HRkU/yYiHf8mIh3/HRkU/x0ZFP8dGRT/HRkU/x0ZFP8dGRT/HRkU/zIuKf+YlJH/19LP/4N7dv8+NS3/Lych/yIdF/8gGxb/',
'KjpP/0B6yP9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v82T3H/LCYf/zQsJf88NTH/SUtS',
'/87MzP+YlJH/Mi4p/x0ZFP8dGRT/HRkU/x0ZFP8dGRT/HRkU/x0ZFP8dGRT/HRkU/yYiHf8mIh3/HRkU/x0ZFP8dGRT/HRkU/x0Z',
'FP8dGRT/HRkU/x0ZFP8dGRT/Mi4p/5iUkf/OzMz/SUtS/zw1MP8vJyH/Ih0X/y9JbP9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v8/ZZn/PDQt/0xCO/+Qqc3/SZX6/zZZh/8dGRT/HRkU/x0ZFP8dGRT/HRkU/x0ZFP8dGRT/',
'HRkU/yMpMf8zV4f/PXK5/0WH3v9Fh97/PXK5/zNXh/8jKTH/HRkU/x0ZFP8dGRT/HRkU/x0ZFP8dGRT/HRkU/x0ZFP8yTG//SZX6',
'/32fzf9MQjv/OzMt/zxjl/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SIfd/0JY',
'ef9CWnz/SZX6/4yw4f99eXX/JCAb/x0ZFP8dGRT/HRkU/x0ZFP8fHx//OGWg/0aM6f86Y5r/MUVf/ysxOv8rMTr/MUVf/zpjmv9G',
'jOn/OGWg/x8fH/8dGRT/HRkU/x0ZFP8dGRT/JCAb/315df+Iosb/SZX6/0Nmlv9CWHn/SIfd/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9DgNH/PGqo/0lac/+blI//2NTR/315df8kIBv/HRkU',
'/yElKv9Cgtb/PW6v/ykqLP8nIx7/JyMe/ycjHv8nIx7/JyMe/ycjHv8pKiz/PW6v/0KC1v8hJSr/HRkU/yQgG/99eXX/2NTR/5uU',
'j/9FUGH/PGqo/0aJ4v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v88aqj/JyMe/ztci/9CWHn/SUE7/5uUj//Y1NH/d3Z2/0F+z/86Y5r/JyMe/ycjHv8qLjP/NleC/zxqqP88aqj/',
'NleC/youM/8nIx7/JyMe/zpjmv9Bfs//d3Z2/9jU0f+blI//ST84/0FSbP82TWz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/SIfd/0JY',
'ef9JQTv/b5HB/0F6x/8oJyX/JyMe/zNMbf9IkPD/SZX6/0iS8/9IkvP/SZX6/0iQ8P8zTG3/JyMe/yglIv9Besf/cpTE/0k/OP9B',
'Umz/R4PT/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/SZX6/0mV+v9Hg9P/SI/t/y46S/80TG7/PnCy/0mV+v9Ehdv/MEFZ',
'/ycjHv8nIx7/MEFZ/0SF2/9Jlfr/MUNc/ycjHv8uOkv/SI/t/0eD0/9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9J',
'lfr/SZX6/0mV+v9Jlfr/RILU/ycjHv80TnH/SZX6/0mV+v8xQ1z/JyMe/ycjHv8nIx7/JyMe/youM/9CfMr/MUNc/ycjHv8nIx7/',
'RILU/0mV+v9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/SZX6/0mV+v9Jlfr/O2eh/ycjHv80TnH/SZP3/z9z',
'uf8zSmr/JyMe/ycjHv8nIx7/JyMe/ycjHv8nIx7/JyMe/ycjHv8nIx7/O2eh/0mV+v9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5w/9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/',
'JyMe/zxqqP9Jlfr/SZX6/0mV+v9Jlfr/OFyM/ycjHv8rMDb/Kiwv/ycjHv8nIx7/JyMe/ycjHv8nIx7/JyMe/ycjHv8nIx7/JyMe',
'/yomIf8nIx7/OFyM/0mV+v9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/SZX6/0mV+v9Jlfr/OmGX/ycjHv8n',
'Ix7/JyMe/ycjHv8nIx7/JyMe/ycjHv8nIx7/JyMe/z46Nf+Ggn7/0c3K/3Vxbv8nIx7/OmGX/0mV+v9Jlfr/SZX6/0mV+v84XIz/',
'JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v88aqj/JyMe/zxqqP9Jlfr/SZX6/0mV+v9Jlfr/QHW8/ycjHv8nIx7/Ozcy/397eP8nIx7/JyMe/ycjHv8nIx7/JyMe/4N/',
'e//49PL/+PTy/3Vxbv8nIx7/QHW8/0mV+v9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/SZX6/0mV+v9Jlfr/',
'SJLz/yosL/8nIx7/g397//j08v+jn5z/Liol/ycjHv8nIx7/Liol/6OfnP/49PL/7uro/3Vxbv8qLC//SJLz/0mV+v9Jlfr/SZX6',
'/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/SZX6/0mV+v9Jlfr/SZX6/zlgk/8nIx7/KiYh/7Swrf/49PL/5eHe/7Csqf+w',
'rKn/5eHe//j08v+0sK3/NDAr/0RAPP85YJP/SZX6/0mV+v9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mT9/8wQFX/JyMe/ycjHv91cW7/ysbE//Xx7//18e//ysbE/3Vxbv8nIx7/JyMe/zBAVf9Jk/f/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9IkPD/MUNc/ycjHv8nIx7/',
'JyMe/ycjHv8nIx7/JyMe/ycjHv8nIx7/MUNc/0iQ8P9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxq',
'qP9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/zxqqP8tOEf/JyMe/ycjHv8nIx7/JyMe/y04R/88aqj/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/RIXb',
'/zpjmv9Fh9//Rozp/0F5w/9BecP/Rozp/0WH3/85YJP/Q4DR/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5',
'w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88',
'aqj/JyMe/zxqqP9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0SF2/80TnH/KCUi/ycjHv8yR2P/RYff/z5wsv8+cLL/Rorm/zROcf8oJSL/',
'JyMe/zJHY/9DgNH/SZX6/0mV+v9Jlfr/SZX6/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/SZX6/0mV+v9Ehdv/NE5x/ygl',
'Iv8nIx7/Mkdj/0OA0f9Jlfr/SZX6/zpjmv86Y5r/SZX6/0mV+v9Ehdv/NE5x/yglIv8nIx7/NE5x/0SF2/9Jlfr/SZX6/0mV+v84',
'XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v88aqj/JyMe/zxqqP9Jlfr/RIXb/zROcf8oJSL/JyMe/zJHY/9DgNH/SZX6/0mV+v9Jlfr/SZX6/zpjmv86Y5r/SZX6',
'/0mV+v9Jlfr/SZX6/0SF2/8zSmr/JyMe/yglIv80TnH/RIXb/0mV+v84XIz/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/zdaif80TnH/KCUi/ycjHv8y',
'R2P/Q4DR/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/zpjmv86Y5r/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/Q4DR/zJHY/8nIx7/',
'KCUi/zROcf80TnH/JyMe/0F5w/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v88aqj/JyMe/ycjHv8nIx7/Mkdj/0OA0f9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/zpj',
'mv86Y5r/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9DgNH/Mkdj/ycjHv8nIx7/JyMe/0F5w/9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v8+cbb/JyMe/ywyO/84XIz/',
'Rorm/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/zpjmv86Y5r/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/Rorm/zhcjP8sMjv/JyMe/z5xtv9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/QnzK/z5xtP84XY7/OFyM/z1ur/9Giub/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/zpjmv86Y5r/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0aK5v89bq//OFyM/zhdjv8+cbT/QnzK/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9JlfrvSZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Hjev/PnG1/zhdjv84XIz/PW6v/0aK5v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/zpjmv86Y5r/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Gi+f/PW6v/zhcjP84XY7/PnG1/0eN6/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+u9J',
'lfvDSZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0eN6/8+cbX/OF2O/zhcjP89bq//',
'Rorm/0mV+v9Jlfr/SZX6/zpjmv86Y5r/SZX6/0mV+v9Jlfr/R43r/z5xtf84XY7/OF2O/z5xtf9Hjev/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+8NJlPmESZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/R43r/z5xtf84XY7/OFyM/z1ur/9Giub/SZX6/zpjmv86Y5r/SZX6/0eN6/8+',
'cbX/OF2O/zhcjP89bq//R43r/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mU+YRGlPckSZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Hjev/PnG1/zhdjv84XIz/PW6v/zhdjf85XpD/PnG1/zhdjv84XIz/PW6v/0aK5v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX5+0eX9yAAAAAASZb6o0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0eN6/89ba3/NE1v/ysvNP8qLTL/',
'M0tr/zxqpv9Giub/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6nwAAAAAAAAAATJn/FEiV+udJlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jk/f/Qn7N/zJHY/8vPlL/Qn7N/0mT9/9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9IlfrnTJn/FAAAAAAAAAAAAAAAAEiU+jxJlfnz',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+fNIlPo8AAAAAAAAAAAAAAAAAAAAAAAAAABIlPo8SJX650mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SJX650iW+jgAAAAAAAAAAAAAAAAAAAAAAAAA',
'AAAAAAAAAAAATJn/FEmU+qNJlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV',
'+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9J',
'lfr/SZX6/0mV+ftJlfqfTJn/FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABGlPckSZT5hEmV+8NJlfnv',
'SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6',
'/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0mV+v9Jlfr/SZX6/0iU+utJlfvDR5T4fEeX9yAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
'AAAAAAAAAAAAAAA='
) -join '')
$BpsIcon = $null
try {
    $BpsIconStream = New-Object System.IO.MemoryStream(, [Convert]::FromBase64String($BpsIconB64))
    $BpsIcon = New-Object System.Drawing.Icon($BpsIconStream)
} catch { }

function New-DarkForm([string]$Title, [int]$W, [int]$H) {
    $f = New-Object Windows.Forms.Form
    $f.Text = $Title
    if ($BpsIcon) { $f.Icon = $BpsIcon }
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
        # Nur so breit wie der Text, damit die Ueberschrift keine Buttons in der Kartenecke verdeckt
        $heading = New-Ctl Label $card 18 14 0 24 @{ Text = $Title; Font = (New-Font 11 'Bold'); AutoSize = $true }
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

# ============================================================ Updater
# Setzt die Version in der BPSconfig.ini, ohne den Rest der Datei zu veraendern
function Set-ConfigVersion([string]$NewVersion) {
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.AddRange([string[]]@([IO.File]::ReadAllLines($ConfigPath)))
    $keyIdx = -1; $hdrIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($keyIdx -lt 0 -and $lines[$i] -match '^\s*Version\s*=') { $keyIdx = $i }
        if ($hdrIdx -lt 0 -and $lines[$i] -match '^\s*\[Version\]\s*$') { $hdrIdx = $i }
    }
    if     ($keyIdx -ge 0) { $lines[$keyIdx] = "Version=$NewVersion" }
    elseif ($hdrIdx -ge 0) { $lines.Insert($hdrIdx + 1, "Version=$NewVersion") }
    else {
        # Aeltere Konfiguration ohne Versionseintrag: Abschnitt am Anfang ergaenzen
        $lines.Insert(0, "Version=$NewVersion")
        $lines.Insert(0, '[Version]')
    }
    [IO.File]::WriteAllLines($ConfigPath, $lines.ToArray())
}

# Gibt es schon eine Konfiguration und weicht ihre Version von $Version ab, wird das
# Sync-Skript in %LOCALAPPDATA% geloescht und die neue Datei aus dem Backup kopiert.
# Danach wird die Version in der Konfiguration angepasst.
# Rueckgabe: $null (nichts zu tun) oder ein Ergebnis fuer den Hinweis-Dialog.
function Update-SyncScript([string]$OldVersion) {
    if (-not (Test-Path -LiteralPath $ConfigPath)) { return $null }   # Erstinstallation
    if ($OldVersion -eq $Version) { return $null }                    # bereits aktuell
    if ($SyncSource -eq $SyncTarget) { return $null }                 # Installer liegt selbst im Zielordner
    $shownOld = if ($OldVersion) { $OldVersion } else { 'unbekannt' }
    try {
        # Erst pruefen, ob die neue Datei da ist - sonst wuerde die alte umsonst geloescht
        if (-not (Test-Path -LiteralPath $SyncSource -PathType Leaf)) {
            throw "SatisfactoryBlueprintSync.bat wurde nicht im Ordner des Installers gefunden:`n$ScriptDir"
        }
        if (Test-Path -LiteralPath $SyncTarget) { Remove-Item -LiteralPath $SyncTarget -Force }
        Copy-Item -LiteralPath $SyncSource -Destination $SyncTarget -Force
        Set-ConfigVersion $Version
        @{ Kind = 'success'; Title = 'Update'
           Message = "Das Sync-Skript wurde aktualisiert (Version $shownOld → $Version).`n`nDie neue SatisfactoryBlueprintSync.bat wurde aus dem Backup nach`n$ConfigDir`nkopiert." }
    } catch {
        @{ Kind = 'error'; Title = 'Update fehlgeschlagen'
           Message = "Das Sync-Skript (Version $shownOld → $Version) konnte nicht aktualisiert werden:`n`n$($_.Exception.Message)`n`nBitte InstallAndRepair.bat erneut ausführen." }
    }
}

$UpdateResult = Update-SyncScript ([string]$cfg.Version)

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
        "Version=$Version"
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
    if ($UpdateResult) {
        Show-Dialog $form $UpdateResult.Title $UpdateResult.Message @('OK') $UpdateResult.Kind | Out-Null
    }
})

[void]$form.ShowDialog()