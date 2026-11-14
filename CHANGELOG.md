# Changelog

Die Version steht in `InstallAndRepair.bat` in der Variable `$Version`. Ändert sich `SatisfactoryBlueprintSync.bat`, muss sie dort erhöht werden, damit der Updater die neue Datei verteilt (siehe README, Abschnitt „Updates“).

## 1.1

- Neues Programm-Symbol (Logo) für alle Fenster, als Base64 in beide Skripte eingebettet.
- Eigene App-ID: Die Taskleiste zeigt das Logo statt des PowerShell-Symbols.
- „Ohne Sync spielen“ beendet SaveSync vollständig, bevor Satisfactory startet.

## 1.0

- Erste Version: automatisches Wiederherstellen und Sichern der Blueprints über SaveSync und Ludusavi beim Spielstart über Steam.
