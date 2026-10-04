# Satisfactory Blueprint Sync

Automatisiert das Synchronisieren von **Satisfactory-Blueprints** zwischen mehreren Spielern mit **SaveSync** und **Ludusavi**.

Bei jedem Spielstart über Steam passiert automatisch:

1. Steam wird geprüft und bei Bedarf minimiert gestartet.
2. SaveSync wird gestartet, damit die neuesten Backups der anderen ankommen.
3. Du hast 60 Sekunden, um in SaveSync zu prüfen, ob alles aktuell ist.
4. Die Blueprints jeder eingerichteten Welt werden aus dem Ludusavi-Backup **wiederhergestellt**.
5. Satisfactory startet.
6. Nach dem Beenden des Spiels wird für jede Welt ein neues Ludusavi-**Backup** erstellt, das SaveSync dann an die anderen verteilt.

Beide Skripte haben eine grafische Oberfläche im Dark Mode. Es muss nichts zusätzlich installiert werden, denn die Oberfläche nutzt das in Windows enthaltene PowerShell.

---

## Inhalt

| Datei | Zweck |
|---|---|
| `InstallAndRepair.bat` | Einrichtung und Reparatur: Programme finden, Welten wählen, Konfiguration schreiben, Sync-Skript installieren |
| `SatisfactoryBlueprintSync.bat` | Der eigentliche Sync, wird von Steam beim Spielstart ausgeführt |
| `beispiel.txt` | Beispiel für die erzeugte Konfigurationsdatei `BPSconfig.ini` |

---

## Voraussetzungen

- Windows 10 oder 11
- Satisfactory über **Steam**
- **SaveSync** und [**Ludusavi**](https://github.com/mtkennerly/ludusavi). Beide `.exe`-Dateien sollten im selben Ordner oder in dessen Unterordnern liegen, z.B. `D:\SteamLibrary\steamapps\common\SaveSync\`.
- **Ludusavi** ist so eingerichtet, dass es für jede Welt ein eigenes Blueprint-Backup gibt, z.B. `Weltname Blueprints`, und dass Ludusavi dieses Backup unter genau diesem Namen wiederherstellen und sichern kann.
- **SaveSync** synchronisiert den Ludusavi-Backup-Ordner zwischen euch.

---

## Aufbau des Ludusavi-Backup-Ordners

Die beiden `.bat`-Dateien werden **zusammen mit den Blueprints im Ludusavi-Backup** weitergegeben. Der Installer erkennt anhand seines eigenen Speicherorts, wo der Backup-Ordner liegt und welche Blueprint-Backups es gibt.

```
C:\Users\<Name>\ludusavi-backup\                        <- Backup-Ordner
├── Weltname Blueprints\                      <- Backup-Name
│   └── drive-C\Users\Admin\AppData\Local\FactoryGame\Saved\SaveGames\blueprints\
│       └── Weltname\                         <- Weltname
│           ├── InstallAndRepair.bat
│           ├── SatisfactoryBlueprintSync.bat
│           └── *.sbp, *.sbpcfg                          (Blueprints)
└── Weltname\
    └── drive-C\...\SaveGames\blueprints\
        └── Weltname\
```

Alle Backups, die einen Ordner `...\SaveGames\blueprints\<Welt>` enthalten, werden als Welt angeboten. Andere Spiele im Backup-Ordner werden ignoriert. Der Backup-Name muss nicht auf „Blueprints“ enden.

---

## Einrichtung

### 1. Installer starten

Öffne den Blueprint-Ordner im Ludusavi-Backup, z.B.
`C:\Users\<Name>\ludusavi-backup\Weltname Blueprints\drive-C\...\blueprints\Weltname`,
und führe **`InstallAndRepair.bat`** per Doppelklick aus.

### 2. Programme

Wähle den Ordner, in dem `SaveSync.exe` und `ludusavi.exe` liegen. Dafür gibt es drei Wege:

- **Durchsuchen…** öffnet die Ordnerauswahl.
- **Strg+V** fügt einen kopierten Pfad ein, auch mit Anführungszeichen. Ein im Explorer kopierter Ordner funktioniert ebenfalls.
- Den Pfad direkt ins Feld tippen.

Unterordner werden automatisch durchsucht. Ein grünes ✔ zeigt, dass das Programm gefunden wurde. Ein rotes ✖ bedeutet, dass es in diesem Ordner nicht liegt.

### 3. Welten

Hier stehen alle Blueprint-Backups, die im Ludusavi-Backup-Ordner gefunden wurden. Rechts daneben steht jeweils der Name des Ludusavi-Backups. Setze ein Häkchen bei allen Welten, die synchronisiert werden sollen.

Wurde der Backup-Ordner nicht automatisch erkannt, etwa weil der Installer woanders liegt, kannst du ihn über **Ordner ändern…** selbst auswählen.

### 4. Speichern

Beim Klick auf **Speichern** passiert Folgendes:

- Der Ordner `%LOCALAPPDATA%\FactoryGame\BlueprintSync` wird angelegt.
- `SatisfactoryBlueprintSync.bat` wird dorthin kopiert. So liegt sie bei allen am selben Ort.
- Die Konfiguration `BPSconfig.ini` wird dort gespeichert.
- Die Steam-Startoption wird in die Zwischenablage kopiert.

### 5. Steam-Startoption eintragen

In Steam: **Satisfactory → Eigenschaften → Allgemein → Startoptionen**. Dort einfügen (Strg+V):

```
"C:\Users\<Name>\AppData\Local\FactoryGame\BlueprintSync\SatisfactoryBlueprintSync.bat" %command%
```

Die genaue Zeile zeigt der Installer im Bereich **3 Steam-Startoption** an. Über **Kopieren** landet sie erneut in der Zwischenablage.

---

## Benutzung

### Normal spielen

Starte Satisfactory wie gewohnt über Steam. Das Blueprint-Sync-Fenster öffnet sich und arbeitet die Schritte ab:

| Schritt | Was passiert |
|---|---|
| Steam starten | Läuft Steam nicht, wird es **minimiert** gestartet (`-silent`) |
| SaveSync starten | SaveSync wird gestartet bzw. in den Vordergrund geholt |
| Syncs überprüfen | 60 Sekunden Zeit, um in SaveSync zu prüfen, ob alles aktuell ist. Mit **Weiter** geht es sofort weiter |
| Blueprints wiederherstellen | Für jede Welt wird der lokale Blueprint-Ordner geleert und das Ludusavi-Backup wiederhergestellt |
| Satisfactory starten | Das Spiel startet, das Fenster wartet, bis es geladen ist |
| Satisfactory läuft | Viel Spaß! Das Fenster bleibt über die Taskleiste erreichbar |
| Backup erstellen | Nach dem Beenden wird für jede Welt ein Backup erstellt. Wurde SaveSync während des Spielens geschlossen, wird es vorher **automatisch neu gestartet** |
| Fertig | Ohne Fehler schließt sich das Fenster nach 3 Sekunden, bei Fehlern bleibt es offen |

Im Protokoll unten im Fenster siehst du, was passiert ist, inklusive der Ausgabe von Ludusavi.

### Ohne Sync spielen (z.B. Singleplayer)

Der Knopf **Ohne Sync spielen** ist jederzeit anklickbar. Er startet Satisfactory sofort, **ohne** Blueprints wiederherzustellen oder zu sichern. Das Programm schließt sich, sobald das Spiel läuft. Läuft das Spiel bereits, wirst du vorher gefragt, weil dann kein Backup mehr erstellt wird.

### Direkt starten (ohne Steam)

Du kannst `SatisfactoryBlueprintSync.bat` auch direkt per Doppelklick starten. Der Ablauf ist derselbe, das Spiel wird dann über Steam gestartet. Steam führt dabei die Startoption, also das Skript, ein zweites Mal aus. Diese zweite Instanz merkt das, startet nur das Spiel und beendet sich sofort. Es öffnet sich also **kein zweites Fenster**.

### Fenster wieder in den Vordergrund holen

Startest du `SatisfactoryBlueprintSync.bat` erneut, während sie schon läuft, wird das vorhandene Fenster in den Vordergrund geholt. Ein zweiter Durchlauf startet nicht.

### Abbrechen

**Abbrechen** oder das Schließen des Fensters beendet den Sync nach einer Rückfrage. Es wird dann **kein Backup** erstellt.

---

## Welten ändern und reparieren

Führe `InstallAndRepair.bat` einfach erneut aus:

- Die bisherigen Programmpfade und die gewählten Welten sind bereits vorausgefüllt.
- Setze oder entferne Häkchen, um Welten hinzuzufügen oder zu entfernen.
- Mit **Speichern** werden die Konfiguration und das Sync-Skript in `%LOCALAPPDATA%\FactoryGame\BlueprintSync` neu geschrieben.

So kommt auch eine **neue Version** von `SatisfactoryBlueprintSync.bat` zu allen: neue Dateien ins Backup legen, und jeder führt einmal den Installer aus.

---

## Konfiguration

Gespeichert unter `%LOCALAPPDATA%\FactoryGame\BlueprintSync\BPSconfig.ini`:

```ini
[Version]
Version=1.0
[Paths]
Datei_Sync=D:\SteamLibrary\steamapps\common\SaveSync\SaveSync.exe
Datei_Ludosavi=D:\SteamLibrary\steamapps\common\SaveSync\ludusavi.exe
Backup_Ordner=C:\Users\<Name>\ludusavi-backup
[Blueprints]
AnzahlBlueprints=2
Blueprint1=Weltname
Ludusavi_Backup1=Weltname Blueprints
Blueprint2=Weltname2
Ludusavi_Backup2=Weltname2 Blueprints
```

| Schlüssel | Bedeutung |
|---|---|
| `Datei_Sync` | Pfad zu `SaveSync.exe` |
| `Datei_Ludosavi` | Pfad zu `ludusavi.exe` |
| `Backup_Ordner` | Ludusavi-Backup-Ordner, wird genutzt, wenn der Installer nicht im Backup liegt |
| `AnzahlBlueprints` | Anzahl der synchronisierten Welten |
| `Blueprint<N>` | Name des Welt-Ordners unter `%LOCALAPPDATA%\FactoryGame\Saved\SaveGames\Blueprints\` |
| `Ludusavi_Backup<N>` | Name des Ludusavi-Backups, das für diese Welt wiederhergestellt bzw. gesichert wird |

Die Datei wird vom Installer geschrieben und muss normalerweise nicht von Hand bearbeitet werden.

---

## Fehlerbehebung

| Problem | Lösung |
|---|---|
| „Es wurde keine Konfiguration gefunden“ | `InstallAndRepair.bat` aus dem Ludusavi-Backup-Ordner ausführen. Satisfactory startet in dem Fall trotzdem, aber ohne Sync |
| Unter „Welten“ steht nichts | Prüfen, ob der Installer wirklich im Ludusavi-Backup liegt, oder den Backup-Ordner über **Ordner ändern…** wählen |
| ✖ bei SaveSync.exe oder ludusavi.exe | Einen Ordner wählen, der die `.exe` enthält, gern auch einen übergeordneten Ordner |
| „Restore/Backup fehlgeschlagen (Code …)“ | Im Protokoll steht die Ausgabe von Ludusavi. Meist ist der Backup-Name in Ludusavi nicht bekannt, oder Ludusavi nutzt einen anderen Backup-Ordner |
| Das Sync-Fenster erscheint beim Spielstart nicht | Die Steam-Startoption prüfen: Pfad in Anführungszeichen und am Ende `%command%` |
| Neue Version wird nicht benutzt | `InstallAndRepair.bat` aus dem Backup erneut ausführen und **Speichern**, erst dann wird das Skript nach `%LOCALAPPDATA%` kopiert |

---

## Technisches

- Beide `.bat`-Dateien sind **Batch/PowerShell-Hybride**. Der kurze Batch-Teil am Anfang startet PowerShell, das den Rest derselben Datei als Skript ausführt. Dadurch bleibt es bei einer einzigen Datei pro Skript. Die Oberfläche ist mit Windows Forms gebaut.
- Das Konsolenfenster wird nach dem Start ausgeblendet, sichtbar ist nur die Oberfläche.
- Laufende Spiele werden an Prozessen erkannt, deren Name mit `FactoryGame` beginnt.
- Es läuft immer nur eine Instanz des Sync-Skripts. Dafür sorgt ein benannter Mutex, und benannte Events dienen zur Abstimmung mit der von Steam gestarteten zweiten Instanz.
