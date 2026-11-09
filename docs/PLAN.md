# Yolk: Plan

Stand: Mo 09.11.2026, 20:30. **Status: wartet auf Garys Go.** Vorher wird nichts gebaut.

## Ziel

Eine iPhone-App, mit der Gary seine Mediathek im Tinder-Stil aufräumt, damit iCloud nicht mehr voll ist.
Rechts wischen heißt behalten, links wischen heißt löschen. Schwerpunkt sind alte Screenshots, sehr
ähnliche Fotos und große Videos.

## Entscheidungen

| Nr. | Frage | Entscheidung |
|---|---|---|
| Q1 | Geräte | Nur iPhone |
| Q2 | Wer nutzt die App | Erst nur Gary, App Store vielleicht später. Deshalb so sauber bauen, dass ein späterer Start ohne Umbau geht |
| Q3 | Apple-Konto | Kein Bezahlkonto. Kostenlose Apple-ID, gebaut wird mit Xcode auf dem Mac mini |
| Q4 | Wann wird gelöscht | Sammeln: Links-Wischer landen im App-Papierkorb, am Ende einmal prüfen und einmal bestätigen |
| Q5 | Modi | Screenshots, ähnliche Fotos und Serien, Videos (größte zuerst), alle Fotos chronologisch, nach Monat oder Jahr |
| Q6 | Extras | Rückgängig, nach oben = Favorit, nach unten = später, Zähler für freigeräumten Speicher |
| Q7 | Grundton | Hell |
| Q8 | Platz für Xcode | Gary bekommt eine Liste der größten Brocken und gibt frei, was weg darf. Dann Xcode mit Simulator |
| Q9 | Erneuerung alle 7 Tage | Über WLAN, Erinnerung nach 6 Tagen |
| Q10 | Design | Entwurf A im Stil von phia.com, nachgeschärft am 09.11.: Royalblau statt Marineblau, kaum Gelb, insgesamt ruhiger |
| Q11 | Name | Yolk |
| Q12 | Sprache | Deutsch und Englisch, je nach iPhone-Sprache |
| Q13 | „Später“ | Das Foto kommt ans Ende des aktuellen Stapels |
| Q14 | Ähnliche Fotos | Die App markiert das beste Foto vor, Gary bestätigt oder ändert |
| Q15 | iOS-Version | iOS 26 |

## So funktioniert die App

1. **Erster Start:** kurze Erklärung, dann die Frage nach Zugriff auf die Fotos. Yolk braucht vollen Zugriff, denn mit
   „Ausgewählte Fotos“ sieht die App nur einen Teil der Mediathek.
2. **Start:** große Überschrift, darunter der Zähler „schon freigeräumt“ und die Modi als Bildkacheln: Screenshots,
   Ähnliche, Videos, Alle Fotos, Nach Monat.
3. **Wischen:** ein Foto pro Karte, darunter Datum und Größe.
   - Rechts: behalten. Das Foto kommt in diesem Modus nicht mehr.
   - Links: in den Papierkorb der App. Noch ist nichts gelöscht.
   - Oben: als Favorit markieren (in der Fotos-App) und behalten.
   - Unten: später. Das Foto kommt ans Ende des aktuellen Stapels.
   - Rückgängig nimmt den letzten Wisch zurück, auch mehrfach hintereinander.
   - Knöpfe als zweiter Weg für alle vier Aktionen. Bei jedem Wisch gibt es eine kurze Vibration.
   - Videos laufen ohne Ton automatisch, mit einem Tipp geht der Ton an.
4. **Ähnliche Fotos:** Statt einzelner Karten erscheint eine Gruppe. Das beste Foto ist vormarkiert. Gary tippt an,
   was bleiben soll, der Rest kommt in den Papierkorb.
5. **Papierkorb:** Raster aller gesammelten Fotos mit Anzahl und Größe. Einzelne Fotos lassen sich zurückholen.
   „Löschen“ verschiebt alle auf einmal nach „Zuletzt gelöscht“. iOS fragt dabei genau einmal nach.
6. **Danach:** Yolk erklärt, dass der Speicher erst frei wird, wenn „Zuletzt gelöscht“ geleert ist (sonst nach 30 Tagen
   von selbst). Ein Knopf öffnet die Fotos-App. Den Ordner selbst kann keine fremde App leeren.
7. **Fortschritt:** Was schon entschieden ist, merkt sich die App dauerhaft, auch über die 7-Tage-Erneuerung hinweg.
   In den Einstellungen lässt sich das zurücksetzen.

## Design

Vorbild ist phia.com als **Stil**: elegante Serifen-Überschriften, in denen ein Wort kursiv steht, viel Weißraum,
ruhige Bildkacheln und schlichte, runde Knöpfe. Logo, Texte und Bilder von Phia werden nicht übernommen.

- **Farben:** fast neutral. Hintergrund warmes Off-White `#FAF9F6`, Schrift fast Schwarz `#151A2B`, Nebentext
  `#71768A`, Linien `#E8E6E1`. **Royalblau `#2445C6` ist die einzige Farbe**: das kursive Wort in Überschriften,
  „Behalten“, Fortschritt und Hauptknöpfe. Hinweise auf hellem Blau `#EEF1FB`. Eigelb `#F5BF2A` gibt es nur noch als
  kleinen Punkt im Logo.
- **Schrift:** Überschriften in *Instrument Serif* (freie Lizenz, wird in die App eingebaut), alles andere in der
  iPhone-Systemschrift. Phias eigene Schriften (GT Super, PP Neue Montreal) kosten Lizenzgebühren und werden
  deshalb nicht genutzt.
- **Formen:** Karten mit 22 pt Rundung, Kacheln 14 pt, Hauptknöpfe als Pille.
- **Bewegung:** Karten folgen dem Finger und federn zurück. Beim Wischen kippen sie leicht, und je nach Richtung
  erscheint „Behalten“ oder „Weg“.
- Die Entwürfe (Start, Wischen, Papierkorb) wurden am 09.11. im Chat gezeigt. Sie sind die Vorlage, keine
  pixelgenaue Vorgabe.

## Technik

- **SwiftUI**, eigene iPhone-App. Mindestens iOS 18, getestet auf iOS 26.
- **Fotos:** über Apples Fotos-Schnittstelle (PhotoKit). Alles passiert auf dem iPhone, es gibt keinen Server und
  keine Analyse-Dienste, und kein Foto verlässt das Gerät. Nur Originale aus iCloud lädt iOS bei Bedarf selbst nach.
- **Screenshots:** iOS kennzeichnet sie selbst, die App filtert danach.
- **Ähnliche Fotos:** erst Serien und zeitlich nahe Aufnahmen bündeln, dann mit Apples Bilderkennung (Vision)
  prüfen, wie ähnlich die Bilder sind. Das beste Foto wählt Apples Bildbewertung (ab iOS 18). Die Berechnung läuft
  auf dem iPhone im Hintergrund, die Ergebnisse werden gespeichert.
- **Videos nach Größe:** Die Dateigröße liest die App aus den Fotodaten.
- **Speicher in der App:** Entscheidungen, Papierkorb und Zähler liegen lokal auf dem Gerät (SwiftData).
- **Sprachen:** Alle Texte stehen in einem String Catalog, Deutsch und Englisch.

## Bauweg ohne Kosten

| Schritt | Wer | Was |
|---|---|---|
| 0 | Agent | Platz schaffen. **Erledigt am 09.11.:** 22,4 GB alte Aufgaben-Ordner und kleine Caches gelöscht, von Gary freigegeben |
| 1a | Gary | macOS auf dem Mac mini auf mindestens 15.6 aktualisieren (installiert ist 15.5, Xcode 26 braucht 15.6). Neustart nötig, die Dienste auf dem Mac sind kurz weg |
| 1b | Gary | Xcode aus dem Mac App Store laden (eigene Apple-ID), einmal öffnen, unter *Einstellungen → Accounts* die Apple-ID eintragen. Auf dem Mac mini ist am 09.11. kein Xcode installiert |
| 2 | Gary | iPhone einmal per Kabel an den Mac: Entwicklermodus einschalten, dem Mac vertrauen. Danach geht es über WLAN |
| 3 | Agent | Bauen, im Simulator testen, Bildschirmfotos zeigen, dann per WLAN aufs iPhone spielen |
| 4 | Agent | Nach 6 Tagen erinnern und neu aufspielen. iPhone zu Hause, entsperrt, im selben WLAN. Die Daten in der App bleiben |

Grenzen der kostenlosen Apple-ID: Die App läuft je 7 Tage, es gehen höchstens 3 eigene Apps gleichzeitig, und es
gibt kein TestFlight. Für den App Store bräuchte es später doch das Bezahlkonto (99 € pro Jahr).

## Meilensteine

Jeder Meilenstein endet mit einem Test auf Garys echtem iPhone, nicht nur im Simulator.

1. **Kernablauf:** Grundgerüst, Fotozugriff, Wischen über „Alle Fotos“, Papierkorb, einmal gesammelt löschen,
   Hinweis zu „Zuletzt gelöscht“. Erster Test auf dem Gerät.
2. **Modi und Extras:** Screenshots, Videos (größte zuerst), nach Monat oder Jahr, Rückgängig, Favorit, Später,
   Speicher-Zähler.
3. **Ähnliche Fotos:** Gruppen erkennen, bestes Foto vorschlagen, Gruppen-Ansicht.
4. **Feinschliff:** Design nach den Entwürfen, Animationen und Vibration, englische Texte, App-Symbol, Startbildschirm.

## Risiken und was zuerst geprüft wird

- **Platz auf dem Mac:** 22,4 GB sind gelöscht. Frei werden sie erst, wenn macOS den lokalen Time-Machine-
  Schnappschuss vom 09.11. 19:10 entfernt. Das passiert von selbst innerhalb eines Tages oder sobald Platz gebraucht
  wird. Xcode mit Simulator braucht rund 20 GB.
- **macOS-Version:** Der Mac mini hat macOS 15.5. Xcode 26 läuft erst ab 15.6, also muss vorher ein Update rein.
- **Favoriten:** Möglicherweise fragt iOS beim Markieren jedes Mal nach. Dann sammelt die App die Favoriten genau wie
  den Papierkorb und setzt sie auf einmal. Das wird im ersten Gerätetest geklärt.
- **Videogröße:** Die Dateigröße steht in den Fotodaten, Apple dokumentiert das Feld aber nicht offiziell. Fällt es
  weg, sortiert die App ersatzweise nach Länge mal Auflösung.
- **Fotos nur in iCloud:** Ist „iPhone-Speicher optimieren“ aktiv, liegen viele Originale nur in der Cloud. Die App
  zeigt dann zuerst die kleine Vorschau und lädt die scharfe Fassung nach.
- **Zähler:** Der Zähler zeigt die Größe der gelöschten Dateien. Die Speicheranzeige von iCloud kann dem
  hinterherhinken.
- **Name:** Ob „Yolk“ im App Store frei ist, wird erst vor einem App-Store-Start geprüft.

## Hinweis zum Repo

Das Repo ist öffentlich. Rechnerbezogene Details wie die Platzliste des Mac mini stehen deshalb nicht hier, sondern
nur lokal auf dem Mac.
