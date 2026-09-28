# Apple-Kontolöschung — Rekonstruktion 26.09.2026 / R1-Nacharbeit 27.09.2026

Quellcode: **TEILWEISE** rekonstruiert. Automatischer Weg und Worker sind implementiert,
manueller Ausnahmeweg ist gesperrt. **Keine Commitfreigabe / keine Betriebsabnahme.**
Dies ist neuer Code, kein wiedergefundener Originalpatch.

## Quellen und Ausgangsstände (H/C/U)

Verbindlich ist Teil A der vollständig gelesenen Anlage `Eingefügter Text.txt`
(1790 Zeilen; SHA-256
`92d712e4926badc659adbe7b04fc89d27303d721019922312840466b60d5383c`).
B/C liefern Abgleich und heutige Abnahmematrix; D enthält Q1–Q4 als historische
Belege (H), keine zusätzlichen Ausführungsanweisungen. Q5 ist nur beschrieben.
Originalpatch, Originalmigration und verlinkte Rohlogs fehlen (U).

C: Backend `feat/emiso-ai-router-v1`,
`d04d4d586518f1eb711a9aa0efb876e700b7960c`,
Parent `93c25beee0dcba0734e9a525aa39f2d3f1718ecc`,
origin https://github.com/ai-emie/emie-backend.git,
Upstream `origin/feat/emiso-ai-router-v1`.
Flutter `main`, `4eecf569f1c1381cefcf2ce19ad5b1ac3fe02a7d`,
origin https://github.com/ai-emie/emie-app.git, Upstream `origin/main`.
Beide Arbeitsbäume/Indizes waren beim Start sauber. Kein Fetch/Live-GitHub-Abgleich.
Keine anwendbare AGENTS.md gefunden. Lokale History-/Ref-/Stash-Suche fand keinen
Originalintegrationspatch. Interne Backend-Refs zeigen den Baseline-Tree.
d04 gegen Parent enthält nur den bewahrten SystemRoot-Runnerfix.

C: Vorhanden und wiederverwendet sind lokale Löschung/Owner-Sperre,
AppleAccountLink, Confirmation, Code Binding, Verified Exchange, Client Secret,
RevocationClient, Job/Secret, Cipher/AAD/Fristen, Flutter-Sessiongeneration und
flüchtiger nativer Apple-Adapter. G-M/Memory/KL-Bausteine wurden nicht neu gebaut.

## Vor Implementierung festgelegter Delta-Plan

| Anforderung | H/C/N/U | Callsite / Lücke | minimale Änderung / Nachweis |
|---|---|---|---|
| Normaler Einstieg | H Q1 §3.2 / C teilweise | profile.delete_me erkennt Apple noch nicht | gespeicherten Link prüfen, bestehenden Löschkörper gemeinsam verwenden; Löschtests |
| Löschberechtigung | H/C/N | allgemeine Confirmation vorhanden, kein Löschgrant | eigener Zweck/Bearer/Linkversion, einmaliger Claim; Negativfälle und PG-Konkurrenz |
| Atomare Änderung | H/C | Cipher/Job vorhanden, finale UoW fehlt | verschlüsselten Auftrag vor Userlöschung in derselben UoW; PG-Commit/Rollback |
| Worker | H/C/N | Client/Storage ohne Lifecycle | persistente Lease-/Versuchsmetadaten am vorhandenen Job; Fristen/Fencing/Neustart |
| Konfiguration | H/C/N | Interfaces ohne Betriebsadapter | getrennte lazy Adapter, Flags AUS, Pflichtfristen |
| Manueller Weg | H/U | Autorisierungsregel nicht eindeutig | Klärung gemäß A §5E; bis dahin gesperrt |
| Flutter | H/C/N | Settings-Löschung und Confirmation getrennt | vorhandene Kette verbinden, A→B/Abbruch/Vertragstests |
| Migration | H/C/N | tatsächlicher Head a7d39c82e610 | neue additive Revision; keine Umdeutung historischer b8e42f91c603 |

Der ursprüngliche Zwischenstand dieses Plans liegt im Export unter
`evidence/preimplementation-plan.md`. Scope-Präzisierung: Konfiguration in einem
eigenen lazy Modul statt `core/config.py`; eigene Koordinationsmetadaten statt
Änderung vorhandener Job-/Cipher-Spalten. Settings ruft bereits den Controller
auf und benötigt für den automatischen Weg keine zusätzliche Implementierung.
Die drei bestehenden Schema-Guards akzeptieren den belegten additiven Nachfolger;
ihre physischen Prüfungen bleiben erhalten. Memory-/Upload-Guards akzeptieren
zusätzlich den schon vorhandenen a7-Head, der zuvor in ihrer Allowlist fehlte.

## Neue Entscheidungen und Verhalten (N)

Neue Revision **c92f6a10d847**, down_revision **a7d39c82e610**.
Historische **b8e42f91c603 wird nicht verwendet**. Alte Migrationen unverändert.
Neue Tabellen: `apple_deletion_operations` und `apple_revocation_processing`.
Die zweite enthält nur Fencing-/Versuchsmetadaten und FK zum bestehenden Job;
keine zweite Tokenablage, keine zweite Jobidentität. Nur neu koordinierte
Löschjobs werden automatisch verarbeitet; bestehende Altjobs bleiben unaktiviert.

Normaler `DELETE /v1/me`: bestehende Passwort-/401-Semantik bleibt. Ein gespeicherter
Apple-Link ergibt 409 `{"ok":false,"code":"apple_deletion_required"}`, ohne Löschung.
Ein Client-E-Mail-Feld entscheidet nichts. Bei mehreren/anderen Clientbindungen
wird keine beliebige Identität geraten: fehlende/eindeutige Bindung blockiert.

Eigene Route `POST /v1/me/apple-deletion`: frischer Vorgang, HTTP 201 mit id,
nonce, state, expires_at. `POST /{id}/complete`: bestehendes redigiertes DTO
id_token/state/authorization_code. `POST /{id}/cancel`: nur pending → cancelled.
Kein Statusabruf als nachträglicher Löschgrant, kein automatischer Code-Retry.

| Übergang | gebundener Kontext / Transaktion |
|---|---|
| begin → pending | Owner → Link → Slot; neues zufälliges ID ersetzt alten Slot; bestätigter Commit vor Antwort |
| pending → claimed | exakter User, Issuer/Client/Subject, Link-created_at, Löschzweck, Modus automatic, Bearer-SHA256/exp, Nonce-/State-Digests; echte Signatur/c_hash; einmaliges Update unter Sperre |
| claimed → gelöscht | Claim-Commit und Session geschlossen vor Exchange; danach Kontext/Frist erneut prüfen; vorhandenen Cipher/Job und lokale Löschung gemeinsam committen |
| claimed → uncertain | Austausch/Commit unklar; nie zurück nach pending, keine Wiederverwendung dieses Codes |
| pending → cancelled | gleicher Owner-/Bearer-/Linkkontext; keine Löschung |

Operation maximal 300 Sekunden gemäß vorhandenem Confirmationvertrag und
zusätzlich durch Bearer-exp begrenzt. Commitfehler sind **unklar**, kein Erfolg
und keine Behauptung garantiert fehlender Wirkung. Unklarer Claim-Commit startet
keinen Austausch. Neuer Vorgang invalidiert alte Snapshots; Neustart reaktiviert
claimed/uncertain nicht. Bei Apple-Fehlern kein Identity-only-/manueller Fallback.

Die finale UoW allein besitzt den Commit. Vorhandene SET-NULL-FKs sollen Job und
Cipher über die User-/Linklöschung erhalten; echter PostgreSQL-Nachweis ist offen.
Keine verteilte Atomarität mit Apple. Tokens liegen nur flüchtig bzw. in der
bestehenden verschlüsselten Secret-Tabelle, nie in Koordinationsmetadaten.

| Workerzustand | Regel |
|---|---|
| pending + due | Job → Processing sperren; SKIP LOCKED; Lease/Versuchszähler persistent committen, dann Token übergeben |
| aktive Lease | kein zweiter Claim |
| abgelaufene Lease nach Neustart | uncertain + blocked, kein erneuter Provider-Versand |
| aktuelles Ergebnis | exakter Jobkontext und Lease, unverbrauchte Frist; erneute Fristprüfung vor Commit |
| ACKNOWLEDGED | nur vorhandener Client-/Repositoryvertrag bestätigt; Cipher nach bestehendem Vertrag entfernen |
| möglicherweise versandt | unklar/rejected unterscheidbar, keine automatische Wiederholung |
| nachweislich nicht versandt | begrenzt erneut fällig bis persistierter max_attempts |
| expires_at / purge_after | bestehendes expire/purge, pro Lauf maximal 25 (zulässiger Aufruf 1–100) |

Fencing schützt lokale Abschlüsse. Eine spätere Apple-Autorisierung kann mit
einem alten Provider-Auftrag wechselwirken; **keine Exactly-once- oder
Provider-Fencing-Garantie**. Ein Serverstart startet den Worker ausschließlich
bei explizit gültig aktivierter Worker-Konfiguration. Imports und Login starten
keinen Worker. In diesem Auftrag wurde keine Liveinstanz gestartet.

## Konfiguration (N; keine produktiven Werte festgelegt)

| Variable | Zweck / Validierung |
|---|---|
| APPLE_ACCOUNT_DELETION_ENABLED | exakt true/false, Default false |
| APPLE_REVOCATION_WORKER_ENABLED | exakt true/false, Default false, separat drainbar |
| APPLE_CLIENT_ID | vorhandene genaue Clientbindung; sichtbares ASCII, 1–255 Zeichen |
| APPLE_SIGNING_TEAM_ID / APPLE_SIGNING_KEY_ID | jeweils zehn Großbuchstaben/Ziffern |
| APPLE_SIGNING_PRIVATE_KEY_PEM | nativer unverschlüsselter EC-P256-Signierschlüssel, eigenes Adapterinterface |
| APPLE_REVOCATION_ACTIVE_KEY_ID | gültige vorhandene Schlüssel-ID |
| APPLE_REVOCATION_KEYS_JSON | eindeutig benannte IDs → Base64 mit genau 32 Bytes; eigenes AES-Adapterinterface |
| APPLE_REVOCATION_TTL_SECONDS | Jobfrist |
| APPLE_REVOCATION_PURGE_DELAY_SECONDS | Abstand Expiry → Purge |
| APPLE_REVOCATION_LEASE_SECONDS | größer als Client-Timeout plus zwei Close-Timeouts, kleiner als TTL |
| APPLE_REVOCATION_RETRY_SECONDS / APPLE_REVOCATION_POLL_SECONDS | positive Wartefristen |
| APPLE_REVOCATION_MAX_ATTEMPTS | positive Ganzzahl, höchstens 100 |

Alle Dauer-/Zählwerte sind zwingend explizit, dezimale positive Integer bis
2147483647. **Keine Produktionsdefaults** aus Tests. Beispiel für sicheren
deaktivierten Betrieb: beide Flags `false`; weitere neue Werte nicht erforderlich.
Es gibt keine Dateisuche, .env-Ladung oder Schlüsselgenerierung im neuen Adapter.
Eingeschaltet unvollständig/ungültig: redigierter Fehler, kein Provideraufruf.
Alte Entschlüsselungskeys müssen für noch existierende Cipher verfügbar bleiben;
Rotation/Entfernung und reale Aufbewahrungsfristen sind nicht freigegeben.

## Flutter-Vertrag und offene Funktion

Bestehender Settings-Dialog → AuthController → AuthRepository → AuthApi ist
verbunden. Frische native Apple-Bestätigung nur nach Serveranforderung. Keine
Refresh-Wiederholung, keine Redirects; flüchtiges Tokenpaar wird freigegeben.
Generation, Account, Bearer und Vorgang werden über Wartezeiten gebunden.
401 benutzt die bestehende generationsgebundene Sitzungsbereinigung.

Realer neuer Backend-Erfolg: HTTP 200
`{"status":"deleted","apple_revocation":"pending"}`.
UI sagt lokale Löschung bestätigt, Apple-Widerruf beauftragt/noch unbestätigt.
Altes `{"status":"deleted"}` bleibt der normale Vertrag.
Parser/Ergebnisdarstellung reservieren zusätzlich acknowledged, not_confirmed,
manual_required; **diese Antworten erzeugt der neue Backendpfad noch nicht**.
Kein erfundener geteilter Vertragsnachweis für reservierte Werte.
Unklare/fehlerhafte Antworten bleiben unbestätigt; Abbruch ist kein Erfolg.
Native Debugprobe, Icons, Signing und Entitlements unverändert.

**Manueller Ausnahmeweg zurückgestellt.** Nutzerentscheidung vorläufig Option 2:
gesperrt lassen. Dies ist ein Review-Haltepunkt, keine endgültige Produktentscheidung.
Kein manueller API-/UI-Ausführungsweg implementiert; keine erneute Freigabefrage.

## R1-Nacharbeit vom 27.09.2026

Grundlage: unabhängige Review R1 und begrenzter Nacharbeitsauftrag, vollständig
gelesen (180 / 131 Zeilen). Ausgangsstand waren genau die 24 Manifestquellen;
Preflight bestätigte alle Bytes, Statusmengen, Branches/HEADs/Origins/Parent und
leere Indizes. Alter Export und alte Review-ZIP bleiben unverändert.
Die R1-Nacharbeit führt keine zusätzliche Migration ein und ändert keine Migration.

### R1-F1: Versand und Sitzung auseinanderhalten

Bestätigter statischer Fehlerpfad: lokale Frist überschritten → API stale →
notSent/differentSession, auch ohne Sessionwechsel. Korrigiert in
AuthRepository.completeAppleDeletion und dem Controller-Fehlerpfad.
Die Sitzung (Generation + Account) wird getrennt vom Proof-/Operationskontext
bewertet. Nach möglichem Versand bei gleicher Sitzung: unconfirmed, kein
behaupteter Nichtversand und kein unterdrückter Hinweis. Nach echtem A→B-Wechsel
bleibt die Antwort für B unsichtbar und löst keine Bereinigung aus.
Eine späte gültig aussehende Antwort wird konservativ verworfen/unbestätigt,
nicht nachträglich als Löschbestätigung übernommen.
AuthApi.current()/isUnexpired, Vor-Versandprüfung, Transportclaim und allgemeiner
nicht löschender Confirmationpfad bleiben unverändert; keine Codewiederholung.

Vier zusätzliche Flutterfälle sind vorbereitet: gleiche Sitzung mit Antwort nach
Frist, Verbindungsfehler und Abbruch nach Versand, Ablauf vor Versand. Uhr injiziert,
Versand/Antwort per Completer geordnet; vorhandene A→B-/Abbruchfälle bleiben dabei.
Flutter-Laufzeitreproduktion weiterhin BLOCKIERT. Nur drei R1-Dart-Dateien mit
format --output=none geparst; kein Typnachweis und keine Quellenformatierung.

### R1-F2: frischen Zustand unter Locks neu bewerten

Bestätigte fehlende Revalidierung. Job→Processing-Lockreihenfolge bleibt erhalten.
Nach Processing-Lock wird Job neu gelesen, DB-Zeit neu bestimmt und exakter
Kontext, Jobzustand, Client, Erstellung/Ablauf/Purge, Blockierung, Fälligkeit,
aktive/abgelaufene Lease und Versuchslimit erneut geprüft.
Aktive Lease wird auch beim letzten erlaubten Versuch unverändert gelassen.
Nur eine tatsächlich abgelaufene Lease führt zum bisherigen Unsicherheitsweg.

Offline-Gegenfälle führen die reale claim()-Methode mit expliziten SQL-/UoW-Doubles
aus; sie ersetzen keinen PG-Snapshotbeweis. Neuer PG-Gegenfall verwendet zwei
getrennte Verbindungen und eine MATERIALIZED-CTE mit Advisory-Lock-Barriere im
ersten SELECT von B. Erst nach nachgewiesenem serverseitigem Warten schreibt/committed
A seine Lease; B darf danach die neue aktive Lease nicht zerstören. Der gültige
Besitzer muss finalisieren können. Dieser Test ist NICHT ausgeführt.

### R1-F3: begrenzte Secret-Fehler vor Versand

Neuer interner SecretUnavailable-Untertyp nur in Repository.load(): ein erfolgreich
gelesenes fehlendes Secret oder ein Fehler des lokalen vorhandenen Codecs.
DB-/Schema-/Verbindungsfehler bleiben generischer StorageError. Keine pauschale
Umetikettierung, kein Secret-/Cipherinhalt in Fehlern.
Worker persistiert attempts+1, festen nicht sensiblen last_outcome
secret_unavailable und next_attempt_at bis zur bestehenden Retryfrist;
max_attempts bzw. Jobablauf sperrt weitere Versuche. Keine Lease, kein Provideraufruf,
kein ACK, keine Cipherreparatur. Vorhandene Expiry-/Purgefrist bleibt unverändert.
Diese Zustände passen in das vorhandene Schema; kein Schemaeingriff nötig.
Fehler beim Backoff-Commit bleiben Fehler und werden nicht als gesichert gemeldet.

Offline: echte Repository-/Codec-Klassifikation mit Session-Doubles, begrenzter
Backoff/Neustartzustand und generische DB-/Commitgegenfälle bestanden.
PG: erster Job ohne Secret, zweiter gültig, begrenzte Worker-Schritte,
genau ein synthetischer Provideraufruf für den gesunden Job und Neustart
bis persistiertem Limit vorbereitet; Ausführung BLOCKIERT.

### D1 und D2

D1: Claim enthält eine lokale monotone Deadline aus der DB-Lease-/Jobfrist.
Der monotone Anker liegt vor dem zugehörigen DB-Zeitread und Claim-Commit;
Commitlatenz und Prozesspause verbrauchen somit das Budget. Direkt vor dem
RevocationClient-Aufruf wird erneut geprüft. Bekannte lokale Fristüberschreitung
verhindert Dispatch und gibt das Token frei. Eine bereits gesetzte Lease bleibt
konservativ für den vorhandenen Ablauf-/Unsicherheitsweg bestehen.
Keine globale Provider-Fencing-Garantie: Pause nach letztem lokalen Check,
Providerverarbeitung oder spätere Reautorisierung sind damit nicht atomar.

D2: Beide Flags AUS sind für Apple-gebundene Konten bewusst fail-closed:
DELETE /v1/me → 409 apple_deletion_required, anschließender Auto-Begin → 503
apple_deletion_unavailable. Lokale Daten bleiben erhalten; keine neue
Schlüsselkonfiguration/DB-Verbindung/Provideranfrage im deaktivierten Begin.
Dieses Verhalten ist jetzt explizit per synthetischer HTTP-Kette geprüft.
Nicht-Apple-/Passwortlöschung bleibt separat in den vorhandenen Löschtests geprüft.
Kein unsicherer Altpfad geöffnet; Produktivübernahme dieses Verhaltens nicht freigegeben.

## Tatsächliche R1-Prüfung und Grenzen

Autorisierter Interpreter C:\Users\Patze\Emie\backend\.venv\Scripts\python.exe:
CPython 3.11.9, alle 35 requirements-Pins vor Import erneut geprüft.
Neuer enger Runner weiterhin -I -B mit synthetischer Umgebung, SystemRoot-Erhalt,
dotenv-/Secretdatei-/nativen PG-/file-SQLite-/HTTP-/Socket-/Unterprozesssperren.
Windows-asyncio nur mit eigenem Socketpaar. Kein universeller OS-Sandboxbeweis.

R1-Auswahl: **58 Methoden / 41 Subtests / 0 Fehler / 0 Failures / 0 Skips, Exit 0**.
Enthält 14 neue R1-Methoden und die 44 benannten bisherigen Regressionen.
Confirmation-Default-Runner unverändert: **52 Methoden / 30 Subtests,
0 Fehler / Failures / Skips, Exit 0**, in R1 tatsächlich erneut ausgeführt.
Vorherige 26.09.-Läufe werden nicht als neue Erfolge hinzuaddiert.

7 tatsächliche synthetische HTTP-Antworten im neuen Backend-Vertragsfixture
(einschließlich D2). Flutter-Vertragshälfte bleibt unausgeführt.
3 R1-Dart-Dateien syntaktisch parsebar, vor/nachher bytegleich.
Flutter 3.38.6 / Dart 3.10.7 weiterhin inkompatibel zum Lock-Pinning
test_api 0.7.6/meta 1.16.0 gegenüber SDK 0.7.7/1.17.0.
Neun Fluttertests vorbereitet, keiner ausgeführt; keine Typanalyse/pub get/Installation.

Zehn PG-Methoden vorhanden (acht vorherige + zwei R1), keine ausgeführt.
Keine DB provisioniert/kontaktiert; bestehende Harness-/Plattform-/PID-/Zielguards
nicht verändert oder umgangen. Alle früher offenen echten Lock-/FK-/Commit-/
Migrations-/Downgradebeweise bleiben offen. Native iOS/Apple/Produktion nicht geprüft.

## R1-Reviewexport / Stopp

Neuer vollständiger Export:
C:\Users\Patze\Emie-Recovery\apple-account-deletion-R1-20260927T130541Z-020c4afd
Er enthält 25 Quellen (19 Backend / 6 Flutter), Gesamtpatches gegen die unveränderten
Baselines, getrennte R1-Deltas gegenüber dem alten Manifest, Quellhashes und
tatsächliche redigierte Nachweise. Alter Export/ZIP bleiben bytegleich.
Befundmatrix trennt statische Bestätigung/Korrektur, Offline-Gegenfälle und
blockierte PG-/Flutter-Laufzeitreproduktion.

Manueller Ausnahmeweg: **vorläufig Option 2, gesperrt lassen**. Zurückgestellter
Umfang für die Review, keine endgültige Produktentscheidung; keine neue Nachfrage
und keine Implementierung.

R1-Code zur unabhängigen Review bereitgestellt; keine Commit-/Betriebsfreigabe.
Kritische PG-/Flutter-Nachweise bleiben blockiert. Beide Indizes leer.
Commit, Push, Mac-Transfer, Deploy, Produktionsmigration und Livewiderruf: NEIN.
Keine Flags aktiviert, keine echten Secrets/Live-Dienste, keine Installationen.
STOPP nach vollständigem Export und neuer Review-ZIP.
