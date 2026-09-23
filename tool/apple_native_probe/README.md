# Separate lokale Apple-Diagnose

Eigenes Target: `tool/apple_native_probe/main.dart`. Kein Import aus `lib/`,
keine normale App-Initialisierung, Emie-Sitzung, Server-Challenge, HTTP-,
Speicher- oder Telemetrieanbindung. Der geschützte Produktionsadapter
`AppleCodeBindingNative` bleibt unverändert und wird hier nicht aufgerufen.

## Native Anschlussstelle und Parameter

Lokal gebunden: `sign_in_with_apple` 6.1.4 mit Plattforminterface 1.1.0.
`SignInWithApple.getAppleIDCredential` liefert
`Future<AuthorizationCredentialAppleID>`; die bestehende MethodChannel-Grenze
heißt `com.aboutyou.dart_packages.sign_in_with_apple` / `performAuthorizationRequest`.
Die Tests ersetzen ausschließlich deren Antwort, nie den fertigen Befund.

Wie beim Produktionsadapter: `scopes: []`, State und Nonce unverändert als
Strings an das Plugin, keine zusätzliche Hashoperation, keine Weboptionen.
Anders als der authentifizierte Produktionskontext erzeugt diese Diagnose
beide Werte lokal: je 32 separate Zufallsbytes aus `Random.secure`, Base64url
ohne Padding. Es handelt sich nicht um eine Backend-Challenge. Ausfall der
sicheren Zufallsquelle führt ausschließlich zu einem festen Fehlerzustand.

## Schutz und Lebensdauer

Nur Debug + explizites `EMIE_APPLE_NATIVE_PROBE=true` + natives iOS erlauben
bewussten Start. Standardflag false. Reale Guards gelten im Startpfad und
unmittelbar vor dem Pluginaufruf; kein überschreibbarer Enable-Schalter.
`withRandomSource` ist allein eine Testgrenze für Zufallsfehler und umgeht
keinen Guard. Öffnen der Oberfläche startet nichts.

Eine statische Sperre gilt für den Dart-Prozess/Diagnose-Isolate und überlebt
Controller-/Widget-Neuaufbau. Es gibt höchstens einen ausstehenden Pluginaufruf,
keinen Retry. Nach zwei Minuten wird nur die lokale Auswertung ungültig.
Timeout oder Dispose beenden NICHT nachweislich den Apple-Dialog. Es gibt keine
native Cancel-Methode in dieser Diagnose. Die Sperre wird erst beim tatsächlichen
Abschluss des ursprünglichen Plugin-Futures freigegeben. Späte Antworten werden
verworfen, späte Fehler abgefangen. Kein neuer Versuch während des Wartens.

Nur der Transport sieht Credentials derselben Antwort. Generation und State
werden vor Auswertung geprüft. Eigene State-/Nonce-Referenzen werden bei Timeout,
Dispose oder Abschluss freigegeben, eigene Credential-Referenzen unmittelbar
nach Verarbeitung. Fremde Plugin-/Plattformspeicher und physische Löschung von
Dart-Strings sind nicht kontrollierbar und werden nicht zugesichert.

## Aussage der Ergebnisse

Nur feste Enums/Booleans: Empfang/Abbruch/Fehler, Token-/Code-Präsenz,
State passend/fehlend/abweichend, Tokenstruktur und c_hash-Kategorie.
Fehlender oder abweichender State ergibt Fehler und keine Payloadbewertung.
JWT ist auf 16384 Zeichen, drei kanonische Base64url-Segmente und 8192
Payloadbytes begrenzt; striktes UTF-8, JSON-Objekt erforderlich.
Das ist UNVERIFIZIERTES PARSEN, keine Signaturprüfung oder c_hash-Berechnung.

„Token nicht kryptografisch verifiziert; keine Codebindung und keine
Emie-Anmeldung bestätigt.“

Keine Credentials, Claims, State/Nonce, Hashwerte oder unbearbeiteten Fehler
in UI, Logs, Dateien, Zwischenablage oder Chat übernehmen. Messwerte bestätigen
keine Identität und erzeugen keine Sitzung oder Berechtigung.

## Späterer echter Lauf – hier nicht ausgeführt

```sh
/Users/emiso/flutter-3.35.4/bin/flutter --suppress-analytics --no-version-check run --debug --no-pub --target tool/apple_native_probe/main.dart --dart-define=EMIE_APPLE_NATIVE_PROBE=true --device-id '<gezielt gewählte iPhone-ID>'
```

Capability, Signing/Provisioning und konkretes iPhone müssen vorher gesondert
geklärt werden. Die bisher nicht nachgewiesene Debug-Zuordnung für
CODE_SIGN_ENTITLEMENTS bleibt offen. Ein unsignierter Build belegt weder diese
Voraussetzungen noch Gerätefunktion. Patrik muss den späteren Apple-Dialog
bewusst bedienen; dieser kann eine echte Apple-Autorisierung auslösen.

Ein Diagnosebuild kann `ios/Flutter/Generated.xcconfig` lokal auf dieses Target
setzen. Für spätere reguläre Builds ausdrücklich `--target lib/main.dart`
angeben; keine manuelle Rückänderung generierter Dateien.

## Berichteter manueller Geräteversuch

Quelle: Laut Patriks Bericht hat er den Apple-Dialog selbst bedient und einen
Screenshot der Diagnoseoberfläche im Chat geteilt. Die daraus berichteten
visuell abgelesenen Zustände sind: Ablauf `completed`, Antwort `received`,
Token vorhanden `true`, Code vorhanden `true`, State `matching`, Tokenstruktur
`readable`, c_hash `stringPresent`. Codex hat diesen Lauf nicht kryptografisch
verifiziert; eine verifizierte Messzeit wird nicht behauptet.

Kontext laut vorherigen Geräte-/Buildberichten: iPhone 14 Pro, iOS 26.6.1,
sign_in_with_apple 6.1.4, separater signierter Debug-Diagnoseeinstieg mit
Bundle-ID ai.emiso.emie. Keine authentifizierte Emie-Sitzung oder Server-Challenge;
direkter nativer Pluginaufruf mit leeren Scopes und der oben dokumentierten
lokalen State-/Nonce-Konvention.

In genau diesem Versuch wurde einmal ein c_hash-String in der unverifiziert
gelesenen Tokenstruktur beobachtet. Nicht nachgewiesen sind kryptografische
Tokengültigkeit, Bindung von c_hash an den konkreten Code, vollständige
serverseitige Identitäts-/Nonce-/Codeprüfung, ein erfolgreicher Confirmation-API-
Ablauf mit diesem echten Nachweis, Codeaustausch, Tokenaufbewahrung oder Widerruf.
Der Befund belegt weder dasselbe Verhalten auf macOS, anderen Geräten oder in
anderen Abläufen noch eine vollständige Apple-Login- oder Beta-Abnahme.

Die lokale Entitlements-Zuordnung gilt für alle Runner-Debug-/iphoneos-Builds,
nicht ausschließlich für das Dart-Probe-Target. Release, Profile und Simulator
wurden dadurch nicht geändert.
