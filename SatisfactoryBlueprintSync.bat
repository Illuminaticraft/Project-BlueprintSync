@echo off
setlocal enabledelayedexpansion
title Satisfactory Blueprint Sync

set "Datei_Sync=D:\Programme\Steam\steamapps\common\SaveSync\SaveSync.exe"
set "Datei_Ludosavi=D:\Programme\Steam\steamapps\common\SaveSync\ludusavi.exe"
set "Blueprint=1.0 with Konstantin"
set "Ludusavi_Backup=1.0 with Konstantin Blueprints"
::set "Blueprint=%LOCALAPPDATA%\FactoryGame\Saved\SaveGames\Blueprints\1.0 with Konstantin"

tasklist /FI "IMAGENAME eq SaveSync.exe" 2>nul | find /I /N "SaveSync.exe"
if "%ERRORLEVEL%"=="1" (
	echo.
	echo  ===================================================
	echo    1. Initialisiere: Starte SaveSync
	echo  ===================================================
	start "" "%Datei_Sync%" 
	timeout /t 6 /nobreak >nul
) else (
	echo.
	echo  ===================================================
	echo    1. Initialisiere: Oeffne SaveSync
	echo  ===================================================
	timeout /t 1 /nobreak >nul
start "" "%Datei_Sync%" 
timeout /t 4 /nobreak >nul
)



powershell -command "(New-Object -ComObject WScript.Shell).AppActivate('Satisfactory Blueprint Sync')"


for /L %%i in (60,-1,1) do (
    cls
	echo.
	echo.
	echo  ===================================================
	echo    2. Ueberpruefe: Sind deine Syncs aktuell?
	echo  ===================================================
    echo    Ueberpruefe deine Syncs. Noch %%i Sekunden. [W zum Ueberspringen]
    choice /t 1 /d n /c wn >nul
    if !errorlevel! equ 1 goto weiter
)

:weiter
cls
echo.
echo.
echo  ===================================================
echo    3. Restore: Stelle die neuesten Blueprints her...
echo  ===================================================
echo    Leere Blueprint-Ordner "%Blueprint%"...


del /q /f "%LOCALAPPDATA%\FactoryGame\Saved\SaveGames\Blueprints\%Blueprint%\*"
::del /q /f "%Blueprint2%\*"

timeout /t 1 /nobreak >nul

"%Datei_Ludosavi%" restore --force "%Ludusavi_Backup%"
::"%Datei_Ludosavi%" restore --force "1.0 with Konstantin Blueprints"

cls
echo.
echo.
echo  ===================================================
echo    4. Starte Satisfactory...
echo  ===================================================
start %1
echo    Warte, bis Satisfactory vollstaendig geladen ist...

:wait_for_game
timeout /t 2 /nobreak >nul
tasklist /FI "IMAGENAME eq FactoryGameSteam.exe" 2>nul | find /I /N "FactoryGameSteam.exe" >nul
if "%ERRORLEVEL%"=="1" goto wait_for_game
timeout /t 10 /nobreak >nul

cls
echo.
echo.
echo  ===================================================
echo    5.  Satisfactory laeuft...
echo  ===================================================
echo    Viel Spass beim Spielen und Bauen!

:wait_for_exit
timeout /t 5 /nobreak >nul
tasklist /FI "IMAGENAME eq FactoryGameSteam.exe" 2>nul | find /I /N "FactoryGameSteam.exe" >nul
if "%ERRORLEVEL%"=="0" goto wait_for_exit

cls
echo.
echo.
echo  ===================================================
echo    6. Spiel beendet. Erstelle neues Backup...
echo  ===================================================
"%Datei_Ludosavi%" backup --force "%Ludusavi_Backup%"

cls
echo.
echo.
echo  ===================================================
echo    7. Backup abgeschlossen.
echo  ===================================================
timeout /t 3 /nobreak >nul
