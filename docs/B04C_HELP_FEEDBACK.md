# B-04c / OPS-20: Hilfe und Feedback

Stand: 18.11.2026. OPS-20 ist ausschließlich für den Hilfe-/Feedbackweg
umgesetzt. Rechtstexte und vollständiges Betriebshandbuch bleiben separat.
Keine Versand-, Store-, Beta- oder Produktionsfreigabe.

## Bedienweg und Datenumfang

Profil → Einstellungen → Abschnitt Emie → Hilfe & Feedback.
Die Seite verwendet das bestehende Theme und die Deutsch-/Englisch-Auswahl.
Vorläufiger Beta-Kontakt: emiso.emie@gmail.com.

- „E-Mail vorbereiten“ ruft ausschließlich den normalen Mailclient über
  mailto auf. Die Person ergänzt und prüft den Entwurf und sendet selbst.
- Der Entwurf enthält nur einen festen Betreff und die leere Fehlervorlage.
  Version/Build stammen aus dem bereits verwendeten PackageInfo.fromPlatform.
  Bei fehlenden Angaben oder einem Lesefehler bleibt das Versionsfeld manuell.
- Keine Accountdaten, Nachrichten, Memories, Projekte, Diagnosedaten,
  Gerätekennungen oder Anhänge werden aus der App übernommen.
- Die Seite warnt vor Passwörtern, API-Schlüsseln, Bestätigungs-/Resetlinks
  und vertraulichen Inhalten. Adresse und Vorlage sind einzeln kopierbar
  und direkt markierbar, auch wenn kein Mailclient geöffnet werden kann.
- Statusmeldungen unterscheiden Mailclient-Aufruf, Kopieren und Fehler.
  Die App behauptet keinen Versand. Keine neue Backendroute oder Telemetrie.

## Gezielte Prüfung

Vorhandenes SDK: Flutter 3.38.6 / Dart 3.10.7. Kein Paketabruf oder Upgrade.

    flutter --no-version-check test --no-pub --dart-define=EMIE_LOCAL=true --dart-define=EMIE_OFFLINE=true test/settings/help_feedback_test.dart --reporter expanded

17 Widgettests bestanden, Exitcode 0: Einstieg und Rückkehr über echte
Settings-Navigation; vollständiger erlaubter Entwurfsinhalt in DE/EN bei
synthetischen privaten Kontodaten; kein automatischer Aufruf; fehlender oder
fehlernder Mailclient; Kopierfallback und Kopierfehler; leere/fehlgeschlagene
Versionsabfrage; kein doppelter Entwurf während eines laufenden Aufrufs;
320×480 logische Pixel mit Textskalierung 2,5 in beiden Sprachen und Themes.
Mailclient und Zwischenablage wurden gemockt; keine echte Mail gesendet.
Vorläufe scheiterten an Scroll-/Zurück-Tasten-Annahmen im Testhelfer;
diese wurden ohne Abschwächung der Assertions korrigiert.

    flutter --no-version-check analyze --no-pub

Vorher/nachher jeweils 0 Fehler, 0 Warnungen, 130 bestehende Info-Meldungen,
Exitcode 1. Meldungen nach Normalisierung verschobener Zeilennummern identisch.
Kein vollständig grüner Analyzerlauf; keine Regeln unterdrückt oder verändert.

## Nachweisgrenzen und unveränderte Bereiche

Keine reale Geräte-/Mailclient-Abnahme oder Zustellprüfung durchgeführt.
Die Layoutprüfung erfolgte im Widgetrenderer, nicht am Android-/iOS-Gerät.
Vorhandene Rechtslinks wurden weder geprüft noch rechtlich freigegeben.
SDKs, Abhängigkeiten, Lockfiles, Version/Buildnummer, Paketkennung und
Signierung bleiben unverändert. Keine Änderung an Backend, Datenbanken,
Cloudbetrieb, Mail-/KI-Konfiguration oder Budgets.

Flutter-Ausgangsbasis: 1db5b072e45a549b1561150c7d088aff1461ddcf auf main,
gezielt von origin geholt und verlustfrei per Fast-forward übernommen.
Backend unverändert: feat/emiso-ai-router-v1,
4c9f7a6744fad9eb0018c90345e4d1d6e04b9075.
Die neuen Flutteränderungen werden ausschließlich lokal committed;
kein Push, keine Übernahme auf einen anderen Rechner und kein Deployment.
