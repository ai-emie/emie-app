# Explizites gemeinsames Backendziel (P6B)

Öffentliche Builds brauchen `EMIE_API_ORIGIN` und `EMIE_RECOVERY_ORIGIN` mit
derselben kanonischen HTTPS-Origin auf Port 443. Keine Zugangsdaten, Pfade,
Queries, Fragmente, IPs oder lokalen/internen Hostnamen. Kein stiller Railway-
oder Emulator-Fallback im öffentlichen Modus. `EMIE_PUBLIC=true`, eine gesetzte
API-Origin oder Profile/Release wählen diesen Modus; ebenso `EMIE_ENV=prod`.
Fehlende oder widersprüchliche Werte werden vor Sitzungs-/Clientstart abgewiesen.

Beispiel ausschließlich für synthetische Prüfungen, keine genehmigte Domain:

```text
--dart-define=EMIE_PUBLIC=true
--dart-define=EMIE_API_ORIGIN=https://shared.example.test
--dart-define=EMIE_RECOVERY_ORIGIN=https://shared.example.test
```

Öffentliche Zielwahl darf nicht mit `EMIE_LOCAL`, Geräte-/Offline- oder P1/P3/P4-
Flags kombiniert werden. Die vorhandenen lokalen Debugziele bleiben erhalten.
Ein Recovery-only-Define in einem lokalen Debugtest aktiviert kein öffentliches
API-Ziel; der bestehende isolierte Recovery-Test mit Port 8443 bleibt möglich.

Das Backend muss Konto-Web- und reguläre Auth-/Chat-/Historienhandler unter
derselben Origin anbieten. Der anfängliche Backendbetrieb mit ausgeschalteter
Mail/KI erlaubt bestehende Konten und Historie, aber keine neue KI-Antwort.
Andere Appfunktionen sind damit nicht automatisch öffentlich freigegeben.

Noch keine öffentliche Domain festgelegt; weder Cloudtestbuild noch Signing,
Paketkennung oder Buildnummer geändert. HTTPS-Browserseiten funktionieren
unabhängig von späteren Android App Links. `assetlinks.json`, passende
Signierungsidentität und iOS/AASA sind separate, ungeprüfte Arbeitsschritte.
Keine lokalen Konten, Proofs oder Backendsecrets in einen Build übernehmen.
