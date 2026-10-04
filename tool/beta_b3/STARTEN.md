# Windows: aktive Repositories lokal starten

Vorhandene Installation weiterverwenden; keine Einrichtung, Kontenerzeugung oder Migration. Backend: `C:\Users\Patze\Emie\backend`; Flutter: `C:\Users\Patze\Emie\app`. Alte Kandidaten sind nur Referenzen.

Die drei üblichen PowerShell-Kommandos:

```powershell
# 1. Nach App-/Buildquelländerungen: aktuelles lokales Debug-APK bauen.
& 'C:\Users\Patze\Emie\backend\.venv\Scripts\python.exe' -I -S -B -X utf8 'C:\Users\Patze\Emie\app\tool\beta_b3\run_local.py' build
# 2. Vorhandene DB, Mailaufnahme, aktives Backend und eigenes Pixel starten.
& 'C:\Users\Patze\Emie\backend\.venv\Scripts\python.exe' -I -S -B -X utf8 'C:\Users\Patze\Emie\app\tool\beta_b3\run_local.py' start
# 3. Eigene Dienste und eigenen Emulator geordnet stoppen; Daten behalten.
& 'C:\Users\Patze\Emie\backend\.venv\Scripts\python.exe' -I -S -B -X utf8 'C:\Users\Patze\Emie\app\tool\beta_b3\run_local.py' stop
```

Für Entwicklung mit normalem `flutter run` stattdessen zwei Terminals verwenden (nach dem ersten passenden Build):

```powershell
# Terminal 1: Umgebung / aktives Backend
& 'C:\Users\Patze\Emie\backend\.venv\Scripts\python.exe' -I -S -B -X utf8 'C:\Users\Patze\Emie\app\tool\beta_b3\run_local.py' backend
# Terminal 2: Flutter aus dem aktiven App-Verzeichnis; r = Hot Reload, q = Ende
& 'C:\Users\Patze\Emie\backend\.venv\Scripts\python.exe' -I -S -B -X utf8 'C:\Users\Patze\Emie\app\tool\beta_b3\run_local.py' flutter
```

Zum vollständigen Beenden anschließend das obige `stop` verwenden. Nach Backendquelländerungen genügt ein vollständiger Stopp/Start; der Launcher hat keinen automatischen Reload.

- Basisbereich: `C:\Users\Patze\Emie-LocalDev\b3-20261002T132620Z-4c04767e`.
- Backend `127.0.0.1:8010`; Android/Recovery exakt `http://10.0.2.2:8010`. Port 8000 wird nicht verwendet. Fremde Listener führen zum Stopp des Startversuchs; keine fremden Prozesse beenden.
- Vorhandenes PostgreSQL 17.11: `127.0.0.1:55439`, Datenbank `emie_b3`, Rolle `b3_app`, Head `d8e4b2a90173`; Mailaufnahme `127.0.0.1:8025`. B4-Prüfdatenbanken sind kein Appziel.
- Eigenes AVD `Emie_B3_Pixel_9_API_36_4c04767e`, `emulator-5556`; Identität wird vor Nutzung geprüft. Update nur mit `adb install -r`, ohne Datenlöschung.
- Der erhaltene API36-Emulator startet hier langsam. Die Bootprüfung ist auf 300 Sekunden mit kurzen Einzelabfragen begrenzt; bei Timeout bleibt er erhalten. Vor erneutem Start seinen Zustand prüfen. Der beobachtete Android-Systemfehler „Bluetooth keeps stopping“ bleibt offen; eine erfolgreiche App-Probe ist keine stabile Geräteabnahme.
- Synthetische Zugänge ausschließlich privat: `<Basisbereich>\private\TESTZUGAENGE.txt` und `accounts.json`. Keine Werte in Chat, Befehlszeilen oder Reviewdateien kopieren.
- Aktuelle APK-Zuordnung: `<Basisbereich>\artifacts\apk.json`; ältere APKs bleiben erhalten. Bei Quellen-/Portabweichung verlangt der Start einen neuen Build.
- Logs: `<Basisbereich>\logs`; eigene Prozessnachweise: `processes`. Die vorherige Laufkonfiguration liegt privat in `windows-abschluss-20261004T143110Z-fde9d15b\private\target-before.json`.

Flutter 3.38.6 / Dart 3.10.7 und vorhandene Dependencies bleiben fest. Lokaler Debugmodus verwendet keine echten Provider; Chat kann ohne Provider nicht erfolgreich beantwortet werden. Release-/Google-/öffentliche Linkvoraussetzungen: [ANDROID_RELEASE.md](ANDROID_RELEASE.md). Lokale Einzelprüfungen sind keine vollständige Beta-/Produktionsabnahme.
