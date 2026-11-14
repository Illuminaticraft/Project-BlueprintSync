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
[DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(int dwProcessId);
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
[DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] public static extern int SetWindowTheme(IntPtr hWnd, string app, string idList);
'@
# Konsolenfenster verstecken, nur die Oberflaeche anzeigen
[BPS.Win]::ShowWindow([BPS.Win]::GetConsoleWindow(), 0) | Out-Null

$ConfigPath    = Join-Path $env:LOCALAPPDATA 'FactoryGame\BlueprintSync\BPSconfig.ini'
$BlueprintRoot = Join-Path $env:LOCALAPPDATA 'FactoryGame\Saved\SaveGames\Blueprints'

# Deutsche Anfuehrungszeichen als [char]: PowerShell wuerde „ “ ” im Quelltext als String-Ende werten
$LQ = [char]0x201E; $RQ = [char]0x201C

$State = @{ Abort = $false; Skip = $false; NoSync = $false; Done = $false; HadError = $false; GameStarted = $false }

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

# Startet das Spiel mit den Argumenten von Steam (%command%) oder ueber Steam selbst.
# Beim Start ueber Steam ruft Steam die Startoption - also dieses Skript - ein zweites Mal auf;
# das LaunchEvent sagt dieser zweiten Instanz, dass sie nur das Spiel starten soll.
function Start-Game {
    $State.GameStarted = $true
    $a = "$env:BPS_ARGS".Trim()
    if (-not $a) {
        [void]$LaunchEvent.Set()
        Start-Process 'steam://rungameid/526870'
        return
    }
    if ($a -match '^"([^"]+)"\s*(.*)$' -or $a -match '^(.+?\.exe)\s*(.*)$' -or $a -match '^(\S+)\s*(.*)$') {
        $exe = $Matches[1]; $rest = $Matches[2]
    }
    if ($rest) { Start-Process -FilePath $exe -ArgumentList $rest } else { Start-Process -FilePath $exe }
}

function Test-GameRunning { [bool](Get-Process -Name 'FactoryGame*' -ErrorAction SilentlyContinue) }

# Ohne Oberflaeche: Spiel starten und warten, bis es laeuft (damit die von Steam
# gestartete zweite Instanz solange das LaunchEvent sieht)
function Start-GameAndWait {
    Start-Game
    $end = (Get-Date).AddSeconds(120)
    while (-not (Test-GameRunning) -and (Get-Date) -lt $end) { Start-Sleep -Milliseconds 500 }
}

# ------------------------------------------------------- Nur eine Instanz
$Mutex       = New-Object Threading.Mutex($false, 'Local\SatisfactoryBlueprintSync')
$LaunchEvent = New-Object Threading.EventWaitHandle($false, 'ManualReset', 'Local\SatisfactoryBlueprintSync_Launch')
$ShowEvent   = New-Object Threading.EventWaitHandle($false, 'AutoReset', 'Local\SatisfactoryBlueprintSync_Show')
try { $isFirst = $Mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $isFirst = $true }
if (-not $isFirst) {
    if ($LaunchEvent.WaitOne(0) -and "$env:BPS_ARGS".Trim()) {
        Start-Game   # von der laufenden Instanz ueber Steam angestossen: nur das Spiel starten
    } else {
        # Bereits laufendes Fenster in den Vordergrund holen
        [void][BPS.Win]::AllowSetForegroundWindow(-1)
        [void]$ShowEvent.Set()
    }
    exit
}

# --------------------------------------------------------- Konfiguration
$cfg = Read-Config
if (-not $cfg.Datei_Sync) {
    Show-Dialog $null 'Satisfactory Blueprint Sync' ("Es wurde keine Konfiguration gefunden:`n$ConfigPath`n`n" +
        "Bitte führe InstallAndRepair.bat aus dem Ludusavi-Backup-Ordner aus.`n" +
        "Satisfactory wird jetzt ohne Blueprint-Sync gestartet.") @('OK') 'warning' | Out-Null
    Start-GameAndWait
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
$btnNoSync = New-Button $form 'Ohne Sync spielen' 20 ($logCard.Bottom + 16) 150 34
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

function Show-Front {
    if ($form.WindowState -eq 'Minimized') { $form.WindowState = 'Normal' }
    $form.TopMost = $true; $form.Activate(); $form.TopMost = $false
}

# Wartet, ohne die Oberflaeche einzufrieren. Gibt $true zurueck, sobald $Until erfuellt ist.
function Wait-UI([double]$Seconds, [scriptblock]$Until) {
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        [Windows.Forms.Application]::DoEvents()
        if ($State.Abort) { throw 'BPS_ABORT' }
        if ($State.NoSync) { throw 'BPS_NOSYNC' }
        if ($ShowEvent.WaitOne(0)) { Show-Front }
        if ($Until -and (& $Until)) { return $true }
        Start-Sleep -Milliseconds 50
    }
    $false
}

function Test-Steam    { [bool](Get-Process -Name 'steam' -ErrorAction SilentlyContinue) }
function Test-SaveSync { [bool](Get-Process -Name 'SaveSync' -ErrorAction SilentlyContinue) }
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
$btnNoSync.add_Click({
    if ($State.Done) { return }
    if (Test-GameRunning) {
        $msg = 'Satisfactory läuft bereits. Blueprint Sync jetzt beenden? Es wird dann kein Blueprint-Backup erstellt.'
        if ('Beenden' -ne (Show-Dialog $form 'Ohne Sync spielen' $msg @('Beenden', 'Weiter warten') 'warning')) { return }
    }
    $State.NoSync = $true
})
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
        # -silent: Steam startet minimiert im Infobereich
        if ($steamExe -and (Test-Path -LiteralPath $steamExe)) { Start-Process -FilePath $steamExe -ArgumentList '-silent' }
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
    Show-Front
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
        Set-Status "Stelle Blueprints für $LQ$($w.Name)$RQ wieder her …"
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
    while (Test-GameRunning) { Wait-UI 2 | Out-Null }
    Show-Front
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
        Set-Status "Erstelle Backup für $LQ$($w.Name)$RQ …"
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
    if ("$_" -eq 'BPS_NOSYNC') {
        # Ohne Sync: Spiel starten (falls noch nicht geschehen) und schliessen, sobald es laeuft
        $State.NoSync = $false
        $btnNoSync.Enabled = $false; $btnNext.Enabled = $false
        Set-Status 'Starte Satisfactory ohne Blueprint-Sync …'
        Write-Log 'Ohne Sync spielen gewählt.'
        try {
            if (-not $State.GameStarted -and -not (Test-GameRunning)) { Start-Game }
            Wait-UI 120 { Test-GameRunning } | Out-Null
        } catch { }
        $State.Done = $true
        $form.Close()
        exit
    }
    Write-Log "FEHLER: $($_.Exception.Message)"
    Set-Status 'Abgebrochen wegen eines Fehlers, siehe Protokoll.'
    $State.HadError = $true
}

$State.Done = $true
$btnNext.Enabled = $false
$btnNoSync.Enabled = $false
$btnCancel.Text = 'Schließen'

# Ohne Fehler nach 3 Sekunden schliessen, sonst offen lassen
$closeAt = if ($State.HadError) { [datetime]::MaxValue } else { (Get-Date).AddSeconds(3) }
while ($form.Visible -and (Get-Date) -lt $closeAt) {
    [Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 50
}
if ($form.Visible) { $form.Close() }