@echo off
title install and Repair SatisfactoryBlueprintSync
set "BPSCpath=%LOCALAPPDATA%\FactoryGame\BlueprintSync\BPSconfig.ini"
::ask if install or repair

::Install

::search for SatisfactoryBlueprintSync.bat in the backup/current folder
    ::if not found, return error message and exit

::Move SatisfactoryBlueprintSync.bat to the installation folder

::create .ini with all the paths to the files

::initial creation of the .ini file for the BlueprintSync
mkdir "%LOCALAPPDATA%\FactoryGame\BlueprintSync"
break>"%BPSCpath%"
echo [Version]>>"%BPSCpath%"
echo Version=1.0>>"%BPSCpath%"
echo [Paths]>>"%BPSCpath%"
echo Datei_Sync=D:\Programme\Steam\steamapps\common\SaveSync\SaveSync.exe>>"%BPSCpath%"

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