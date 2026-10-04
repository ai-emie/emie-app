# Lokalen geprüften B3-Kandidaten starten

Nur diese vorhandene Windowsinstallation; kein Neuaufbau und keine DB-Migration. Originalrepos und alte Kandidaten bleiben erhalten. Die Dienste wurden zum Reviewabschluss gestoppt. Privater Basisbereich:
`C:\Users\Patze\Emie-LocalDev\b3-20261002T132620Z-4c04767e`.

In PowerShell für einen späteren lokalen Start:

```powershell
& 'C:\Users\Patze\Emie\backend\.venv\Scripts\python.exe' -I -S -B -X utf8 'C:\Users\Patze\Emie-LocalDev\b3-20261002T132620Z-4c04767e\abschluss-20261003T224107Z-daac3e91\candidate\app\tool\beta_b3\run_local.py' start
```

Der Dispatcher startet den eigenen PG17.11, die Mailaufnahme, den echten Backend-Lifespan und den eigenen Pixel-AVD und installiert das bereits gebaute APK mit `-r` ohne Appdatenlöschung. Backendstart und Androidstart wurden in diesem Lauf einzeln über genau diese Unterfunktionen ausgeführt; Stop über den Dispatcher. Kein accounts-Setup, keine Datenbankinitialisierung oder B4-Prüfsequenz erneut ausführen.

Beenden, Daten behalten:

```powershell
& 'C:\Users\Patze\Emie\backend\.venv\Scripts\python.exe' -I -S -B -X utf8 'C:\Users\Patze\Emie-LocalDev\b3-20261002T132620Z-4c04767e\abschluss-20261003T224107Z-daac3e91\candidate\app\tool\beta_b3\run_local.py' stop
```

Nur nach bewusst freigegebenen Quelländerungen ist `setup` statt `start` erforderlich: Offline-Lockfileprüfung und neuer Debugbuild. Für den beiliegenden Stand bereits erledigt. Flutter 3.38.6, Dart 3.10.7, unveränderte Pins meta 1.17.0/test_api 0.7.7. Kein automatischer Dependency-/SDKwechsel. Ein neuer Build benötigt erneut APK-/Quellabgleich und passende native Prüfungen.

- Eigener Backendport `127.0.0.1:8010`, Android/Recovery genau `http://10.0.2.2:8010`.
- PG `127.0.0.1:55439`, normale B3-Appdatenbank `emie_b3`, Rolle `b3_app`; Mailaufnahme `127.0.0.1:8025`.
- AVD `Emie_B3_Pixel_9_API_36_4c04767e`, `emulator-5556`. Gemeinsamen ADB-Server erhalten.
- **Port 8000 bleibt fremd.** Kein HTTP-Probeaufruf, Übernehmen oder Freiräumen. Bei fremdem 8010 nicht selbst PIDs beenden. Ein späterer Wechsel nur nach eigener Freigabe/exklusiver Bindprüfung auf 8011–8019 und konsistentem Neubuild aller lokalen Port-/Originwerte.
- Finale APK außerhalb der ZIP: `artifacts\emie-b3-local-debug.apk`, SHA-256 `e9d51cad4d3bb2d6611927604ee1dec200eabfdd9225ccf435d9faf4d8acab9d`, 73310831 Bytes, Debug x86_64. Metadaten/Quellzuordnung im Paket.
- Bestehendes Konto A bleibt erhalten. Neue lokale Konten C4A, C4B, C4R und ihre aktuellen Passwörter stehen ausschließlich in `private\accounts.json` bzw. der privaten Testzugangsnotiz. Keine Werte in Befehlszeilen kopieren/teilen. C4R wurde mehrmals kontrolliert zurückgesetzt; nur den aktuellen privaten Eintrag verwenden. Historisches B ist bereits früher gelöscht worden.
- Laufdiagnose: `abschluss-20261003T224107Z-daac3e91\logs`; allgemeine Launcherlogs `logs`, Prozessidentitäten `processes`. `target.json` verweist auf den neuen Backendkandidaten; vorherige Fassung in `abschluss-…\target-before.json` erhalten.
- Zwei neue B4-DBs und privater Dump bleiben erhalten; sie sind nicht das normale Appziel. Namen und Prüfergebnisse siehe Betriebsrunbook/Ressourceninventar.

Die Start-/Stophilfen prüfen Pfade, Startzeiten, exklusive Bindung, Schema, Quellen und APK. Bei Abweichung Log prüfen und genau den betroffenen Schritt stoppen; keine Daten löschen oder Guards übergehen. Build maximal 600 s, Pub 180 s, Lifespanprobe 90 s, einzelne Metadaten-/ADB-Aufrufe begrenzt. Ein äußerer Timeout beweist nicht das Ende aller Kindprozesse.

Lokale Debugdiagnose (`EMIE_LOCAL` plus Debug) protokolliert nur feste Phasen, numerische Probe, Status, Dauer und Gleichheitsbooleans. Einmalige Antwortverluststeuerung liegt ausschließlich im lokalen Harness; der Marker wurde verbraucht. Produktionsmain enthält diesen Hook nicht. Keine echte dotenv/Providerkonfiguration, Header-Auth aus, Appleworker aus. Google/Apple und Chatprovider sind lokal nicht als echte Dienste abgenommen.

Die ursprünglichen sporadischen Profil-/Warm-Befunde bleiben historisch ungeklärt. Aktuelle native Kernwege sind auf dieser APK bestanden; das ist keine vollständige Beta-, Release- oder Produktionsabnahme.
