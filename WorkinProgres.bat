@echo off
setlocal enabledelayedexpansion
title Satisfactory Blueprint Sync

set "Datei_Sync=D:\Programme\Steam\steamapps\common\SaveSync\SaveSync.exe"
set "Datei_Ludosavi=D:\Programme\Steam\steamapps\common\SaveSync\ludusavi.exe"
set "Blueprint=%LOCALAPPDATA%\FactoryGame\Saved\SaveGames\Blueprints\1.0 with Konstantin"
::set "Blueprint=%LOCALAPPDATA%\FactoryGame\Saved\SaveGames\Blueprints\1.0 with Konstantin"

tasklist /FI "IMAGENAME eq SaveSync.exe" 2>NUL | find /I /N "SaveSync.exe"
if "%ERRORLEVEL%"=="1" (
	echo
	echo ===================================================
	echo   1. Initialisiere: Starte SaveSync
	echo ===================================================
	start "" "%Datei_Sync%" 
	timeout /t 6 /nobreak >nul
) else (
	echo ===================================================
	echo   1. Initialisiere: Oeffne SaveSync
	echo ===================================================
	timeout /t 1 /nobreak >nul
start "" "%Datei_Sync%" 
timeout /t 4 /nobreak >nul
)



powershell -command "(New-Object -ComObject WScript.Shell).AppActivate('Satisfactory Blueprint Sync')"


for /L %%i in (60,-1,1) do (
    cls
	echo .
	echo ===================================================
	echo   2. Ueberpruefe!: Sind deine Syncs aktuell?
	echo ===================================================
    echo Ueberpruefe deine Syncs. Noch %%i Sekunden. [W zum Ueberspringen]
    choice /t 1 /d n /c wn >nul
    if !errorlevel! equ 1 goto weiter
)

:weiter
cls
echo .
echo ===================================================
echo   3. Restore: Stelle die neuesten Blueprints her...
echo ===================================================
echo Leere spezifischen Blueprint-Ordner "1.0 with Konstantin"...


del /q /f "%Blueprint%\*"
::del /q /f "%Blueprint2%\*"

timeout /t 1 /nobreak >nul

"%Datei_Ludosavi%" restore --force "1.0 with Konstantin Blueprints"
::"%Datei_Ludosavi%" restore --force "1.0 with Konstantin Blueprints"

cls
echo .
echo ===================================================
echo   2. Starte Satisfactory...
echo ===================================================
start %1
