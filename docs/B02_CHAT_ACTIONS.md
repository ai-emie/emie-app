# B-02 Flutter-Chatvertrag

06.11.2026. Backendvertrag: `docs/B02_DURABLE_CHAT.md` im Backend-Repository.

Der reguläre Chat sendet eine UUID `action_id` pro bewusst neuer Aktion und
behält offene IDs im vorhandenen Secure Storage, nach API-Ziel und Account getrennt.
Bei unklarem Ausgang wird kein neuer kostenpflichtiger POST gesendet.
„Antwortstatus prüfen“ liest den authentifizierten Aktionsstatus und die Historie.
Ein abgeschlossener Vorgang wird daraus wieder angezeigt; bestätigte Fehler bleiben
separate Fehlermeldungen. Fehler erzeugen keine lokale Assistentenersatzantwort.
Eindeutig bestätigte Fehler erlauben danach eine bewusst neue Aktion, niemals einen
automatischen Retry. Unklare/unterbrochene Vorgänge brauchen eine belegte Klärung.

POST-Auth-Replay ist ausgeschaltet. Account-/Sessionwechsel, Doppelklickschutz und
späte Antworten bleiben geschützt. P1/P3 behalten ihre bisherigen lokalen Grenzen;
dort wird keine neue öffentliche Idempotenzgarantie behauptet.

Gezielte Tests: `test/api/durable_chat_test.dart`, `test/product_b2/chat_feedback_test.dart`,
`test/security/chat_account_isolation_test.dart`; P1 und P3 jeweils mit ihren bisherigen
expliziten lokalen Defines. Keine Paket-/SDK-Upgrades, keine Live-Chatnachricht.

AI-07/CHAT-03/CHAT-04/AI-09: Clientanbindung implementiert und lokal mit synthetischen
Antworten geprüft. Öffentliche Betriebsabnahme bleibt offen. Kein Deployment und
keine automatische Erweiterung der pausierten B-03b-Freigabe.

## Geprüfter Dateiumfang

Repository: `/Users/emiso/Documents/ChatGPT/Emie Flutter`. Geänderte beziehungsweise neue Dateien:

- `docs/B02_CHAT_ACTIONS.md`
- `lib/api/api_error.dart`
- `lib/data/chat/chat_api.dart`
- `lib/data/chat/chat_repository.dart`
- `lib/data/chat/pending_action.dart`
- `lib/features/chat/controller/chat_controller.dart`
- `lib/features/chat/presentation/screens/chat_screen.dart`
- `test/api/durable_chat_test.dart`
- `test/api/p1_chat_test.dart`
- `test/product_b2/chat_feedback_test.dart`
- `test/security/chat_account_isolation_test.dart`
