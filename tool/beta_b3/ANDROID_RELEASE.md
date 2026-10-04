# Android: Vorbereitung und offene echte Angaben

Package bleibt `ai.emie.app`. Der lokale Debugmodus wird ausdrücklich mit `EMIE_LOCAL=true` und `EMIE_LOCAL_PORT=8010` gebaut. Die lokale Cleartext-/Recovery-Manifestüberlagerung gehört ausschließlich zu dieser Debugvariante. Release und Profile müssen HTTPS verwenden; Local-Probes sind durch Dart-Debugmodus und Localflag begrenzt. Android-Testinstrumentation bleibt im getrennten `androidTest`-Quellbereich.

Die Gradle-Prüfung hängt am tatsächlichen zusammengeführten Manifest jeder paketierten Variante und prüft den Taskgraph, auch bei `assemble` oder direktem `packageRelease`. Ein fehlender Release-Schlüssel blockiert keinen lokalen Debugbuild. Release/Profile nutzen ausschließlich die Release-Signingkonfiguration; kein Debugfallback. Variantenprüfungen dürfen nicht mit `-x` oder selbst veränderter Buildlogik umgangen werden.

Folgende reale Angaben fehlen auf diesem Windowsstand:

| Datei / Angabe | Zweck und sicherer Bereitstellungsort |
|---|---|
| `android/key.properties` und der dort ausdrücklich referenzierte vorhandene Keystore | Reale Upload-/Release-Signierung. Die leere `android/key.properties.example` lokal ausfüllen, private Dateien bleiben Git-ignoriert. Keine neue Signingidentität erzeugen; keine Passwörter in Chat/CLI. |
| `android/app/google-services.json` für `ai.emie.app` | Echte Android-/Firebase-/Google-Projektzuordnung, aus dem berechtigten Projekt lokal ablegen. Keine Dummydatei. |
| Zugehörige bestätigte OAuth-Konfiguration, ggf. `GOOGLE_CLIENT_ID` | Android-Signatur-/Paketzuordnung und der vorhandene Google-Loginvertrag müssen im zuständigen Projekt bestätigt werden. Lokale Builddefines/privates Releaseprofil verwenden; keine ID erfinden. |
| Bestätigte HTTPS-Recovery-Origin | Als `EMIE_RECOVERY_ORIGIN=https://<bestätigter-host>[:port]` für den konkreten Build bereitstellen. Host darf weder Credentials, Wildcard, Query noch Fragment enthalten; Pfad ist ausschließlich `/reset-password`. Ohne Wert entsteht kein öffentlicher Intentfilter. |
| Gerätesignatur-Fingerprints und Domainverantwortung | `assetlinks.json.example` ist nur eine Vorlage. Für Play-installierte Apps das **Play-App-Signing-Zertifikat**, für direkt verteilte echte Releases deren tatsächliches Signierzertifikat verwenden. Uploadzertifikat und Debugzertifikat getrennt dokumentieren und nicht austauschen. |

Bestätigte öffentliche Origin und gleiche Dart-Konfiguration werden beim Build an den Manifesttransform übergeben. Android filtert Scheme/Host/Pfad und einen ausdrücklich nichtstandardmäßigen Port; Dart prüft zusätzlich immer den exakten effektiven Port, auch für HTTPS/443. Linkparameter ändern keine Backendadresse. Proofs bleiben in RAM, nicht in Routennamen, Preferences oder Diagnoseausgaben. Bestehende Session-/Recoveryprüfungen bleiben erhalten. Verifikation erfolgt bewusst per POST; ein GET konsumiert keinen Proof.

Eine synthetische `links.example`-Probe ist kein Nachweis einer öffentlichen Domainverbindung. Explizite ADB-Intents, Browser-/Mail-Klicks und vom Betriebssystem verifizierte App Links sind unterschiedliche Abnahmen. Domainhosting, `/.well-known/assetlinks.json`, Console-/Storekonfiguration und reale Geräte müssen später separat freigegeben und geprüft werden. Dieser Auftrag veröffentlicht nichts und startet keinen Release gegen Produktion.

Technische Grundlagen: [AGP 8.9 MERGED_MANIFEST](https://developer.android.com/reference/tools/gradle-api/8.9/com/android/build/api/artifact/SingleArtifact.MERGED_MANIFEST), [Gradle Taskgraph](https://docs.gradle.org/8.12/userguide/build_lifecycle.html). Die aktuellen konkreten Prüfresultate stehen im Abschlussbericht; ein Debug-APK ist kein signierter Produktrelease.
