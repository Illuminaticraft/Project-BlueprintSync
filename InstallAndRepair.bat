@echo off
setlocal enabledelayedexpansion
title install and Repair SatisfactoryBlueprintSync

set "BPSCpath=%LOCALAPPDATA%\FactoryGame\BlueprintSync\BPSconfig.ini"
set "input="

::ask if install or repair

::Install

::search for SatisfactoryBlueprintSync.bat in the backup/current folder
    ::if not found, return error message and exit

::Move SatisfactoryBlueprintSync.bat to the installation folder

::initial creation of the .ini file for the BlueprintSync
if not exist "%LOCALAPPDATA%\FactoryGame\BlueprintSync" mkdir "%LOCALAPPDATA%\FactoryGame\BlueprintSync"
break>"%BPSCpath%"

::create .ini with all the paths to the files
>>"%BPSCpath%" echo [Version]
>>"%BPSCpath%" echo Version=1.0
>>"%BPSCpath%" echo [Paths]
choice /m "Do you want to input custom paths?"

if errorlevel 2 goto No
if errorlevel 1 goto Yes

:Yes
echo Gib den Pfad zu SaveSync.exe ein (z.B. D:\Programme\Steam\steamapps\common\SaveSync\SaveSync.exe):
set "input="
set /p input=
>>"%BPSCpath%" echo Datei_Sync=!input!
echo Gib den Pfad zu ludusavi.exe ein (z.B. D:\Programme\Steam\steamapps\common\SaveSync\ludusavi.exe): 
set "input="
set /p input=
>>"%BPSCpath%" echo Datei_Ludosavi=!input!
goto End

:No
>>"%BPSCpath%" echo Datei_Sync=D:\Programme\Steam\steamapps\common\SaveSync\SaveSync.exe
>>"%BPSCpath%" echo Datei_Ludosavi=D:\Programme\Steam\steamapps\common\SaveSync\ludusavi.exe
goto End

:End

>>"%BPSCpath%" echo [Blueprints]



echo Fuer wieviele Welten willst du Blueprints synchronisieren? (Gib eine Zahl ein)
:AskNumber
set "NumberOfBPs="
set /p NumberOfBPs=
set /a NumberOfBPs=NumberOfBPs 2>nul
if !NumberOfBPs! LSS 1 (
    echo Bitte eine Zahl groesser 0 eingeben:
    goto AskNumber
)
>>"%BPSCpath%" echo AnzahlBlueprints=%NumberOfBPs%




for /L %%i in (1,1,%NumberOfBPs%) do (
    echo Gib den Namen der Welt Nr.%%i ein ^(z.B. 1.0 mit Konstantin^):
    set "input="
    set /p input=
    >>"%BPSCpath%" echo Blueprint%%i=!input!
    >>"%BPSCpath%" echo Ludusavi_Backup%%i=!input! Blueprints
)
::add custom launch option for Satisfactory in Steam




::repair

::search for SatisfactoryBlueprintSync.bat in the backup/current folder
    ::if not found, return error message and exit

::search for SatisfactoryBlueprintSync.bat in the installation folder
    ::if found, delete the file and 

::copy the backup version to the installation folder

::search for the .ini with all the paths to the files
    ::if found, ask the user if he wants to repair the paths in the .ini file
        ::if yes, ask for the new paths and replace them in the .ini file
        ::if no, exit
    ::if not found, ask the user if he wants to create a new .ini file with the paths to the files
        ::if yes, ask for the paths and create the .ini file
        ::if no, exit

::rewrite the custom launch option for Satisfactory in Steam with the new paths