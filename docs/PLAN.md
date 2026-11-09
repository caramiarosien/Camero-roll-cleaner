# Yolk: Plan

Stand: Mo 09.11.2026 abends. **Status: Go von Gary am 09.11.2026.** Gebaut wird auf Garys MacBook, los geht es mit
Meilenstein 1.

## Ziel

Eine iPhone-App, mit der Gary seine Mediathek im Tinder-Stil aufräumt, damit iCloud nicht mehr voll ist.
Rechts wischen heißt behalten, links wischen heißt löschen. Schwerpunkt sind alte Screenshots, sehr
ähnliche Fotos und große Videos.

## Entscheidungen

| Nr. | Frage | Entscheidung |
|---|---|---|
| Q1 | Geräte | Nur iPhone |
| Q2 | Wer nutzt die App | Erst nur Gary, App Store vielleicht später. Deshalb so sauber bauen, dass ein späterer Start ohne Umbau geht |
| Q3 | Apple-Konto | Kein Bezahlkonto. Kostenlose Apple-ID, gebaut wird auf Garys MacBook |
| Q4 | Wann wird gelöscht | Sammeln: Links-Wischer landen im App-Papierkorb, am Ende einmal prüfen und einmal bestätigen |
| Q5 | Modi | Screenshots, ähnliche Fotos und Serien, Videos (größte zuerst), alle Fotos chronologisch, nach Monat oder Jahr |
| Q6 | Extras | Rückgängig, nach oben = Favorit, nach unten = später, Zähler für freigeräumten Speicher |
| Q7 | Grundton | Hell |
| Q8 | Platz für Xcode | Erledigt: Platz auf dem Mac mini geschaffen. Seit dem Wechsel aufs MacBook nicht mehr nötig |
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
- **Schrift:** Überschriften in *Instrument Serif* (SIL Open Font License 1.1, wird in die App eingebaut,
  Lizenztext kommt unter „Danksagungen“ in die Einstellungen), alles andere in der iPhone-Systemschrift. Phias eigene Schriften (GT Super, PP Neue Montreal) kosten Lizenzgebühren und werden
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
- **Eingeschränkter Zugriff:** Erlaubt Gary nur „Ausgewählte Fotos“, erklärt Yolk den Unterschied und bietet die
  Auswahl oder den Weg in die Einstellungen an. Die automatische iOS-Abfrage wird abgeschaltet
  (`PHPhotoLibraryPreventAutomaticLimitedAccessAlert`).
- **Serien:** Normalerweise liefert iOS von einer Serie nur das Titelbild. Für „Ähnliche“ holt Yolk alle Bilder einer
  Serie (`includeAllBurstAssets`). Was beim Löschen des Titelbilds mit dem Rest passiert, wird auf dem Gerät getestet.
- **Bilderkennung schonend:** Die Analyse ähnlicher Fotos läuft auf den kleinen Vorschaubildern, die schon auf dem
  iPhone liegen, ohne iCloud-Download. Sonst würde die halbe Mediathek heruntergeladen. iOS lässt Apps im Hintergrund
  nur kurz rechnen, also läuft die Analyse vor allem, solange Yolk offen ist, und macht beim nächsten Start weiter.
  Vision wird nur auf dem echten iPhone beurteilt, nicht im Simulator.
- **Mediathek ändert sich:** Yolk hört auf Änderungen der Mediathek (`PHPhotoLibraryChangeObserver`). So enthalten
  Papierkorb und gemerkte Entscheidungen keine Fotos, die woanders schon gelöscht wurden.
- **Was sich nicht löschen lässt:** Fotos, die iOS nicht löschen darf, überspringt Yolk (`canPerform(.delete)`). Fotos
  aus einer geteilten iCloud-Mediathek sind beim Löschen für alle weg, darauf weist Yolk vor dem Löschen hin.
- **Größe:** Live Photos, RAW+JPEG und bearbeitete Fotos bestehen aus mehreren Dateien, Yolk zählt alle zusammen.
  Unter iOS 18–26 steht die Größe nur in einem nicht dokumentierten Feld. Das offizielle Feld (`dataSize`) gibt es
  erst ab iOS 27 und mit Xcode 27. Für die private Nutzung ist das in Ordnung, vor einem App-Store-Start wird es
  geprüft.
- **Fotos-App öffnen:** Für den Sprung in die Fotos-App gibt es nur einen nicht dokumentierten Link. Direkt zu
  „Zuletzt gelöscht“ geht es gar nicht. Yolk zeigt deshalb eine kurze Anleitung und öffnet die Fotos-App, wo das geht.
- **Schnelles Wischen:** Die nächsten Karten werden vorgeladen, erst unscharf, dann scharf. Ladevorgänge für
  weggewischte Fotos werden abgebrochen. Fehlt ein Vorschaubild, zeigt Yolk einen Platzhalter statt zu hängen.

## Bauweg ohne Kosten

Gebaut wird auf **Garys MacBook Air** (Apple M4, macOS 26.6.2, Xcode 27.2, Simulatoren für iOS 18.5 und 26.4),
nicht auf dem Mac mini. Der Mac mini ist der Heimserver und dafür nicht gedacht (Entscheidung Gary, 09.11.). Der
Agent arbeitet vom Mac mini aus: Der Code liegt im Repo, gebaut und installiert wird per SSH auf dem MacBook. Ein
Apple-Development-Zertifikat ist dort bereits eingerichtet.

| Schritt | Wer | Was |
|---|---|---|
| 1 | Gary | Xcode auf dem MacBook einmal öffnen und die Zusatzkomponenten installieren lassen (fragt nach dem Mac-Passwort). Ohne das klappt das Installieren aufs iPhone aus dem Terminal nicht |
| 2 | Gary | In Xcode unter *Einstellungen → Apple Accounts* prüfen, ob die Apple-ID angemeldet ist |
| 3 | Gary | Das MacBook in T3 als Geräte-Host (SSH) eintragen, damit der Simulator im Geräte-Fenster von T3 erscheint |
| 4 | Gary | iPhone per Kabel ans MacBook, „Diesem Computer vertrauen“ tippen. Nach dem Koppeln erscheint der Entwicklermodus (*Einstellungen → Datenschutz & Sicherheit*): einschalten, neu starten, bestätigen |
| 5 | Agent | Erster Build aufs iPhone. Fragt der Mac, ob `codesign` den Schlüssel nutzen darf, einmal „Immer erlauben“ (Gary am MacBook) |
| 6 | Gary | Auf dem iPhone *Einstellungen → Allgemein → VPN & Geräteverwaltung → Entwickler-App → Vertrauen*. Braucht Internet |
| 7 | Agent | Ab jetzt bauen, im Simulator auf dem MacBook testen, Bildschirmfotos zeigen und aufs iPhone spielen |
| 8 | Agent | Nach 6 Tagen erinnern und neu aufspielen. MacBook an, iPhone entsperrt im selben WLAN. Vorher die App-Daten per `devicectl` sichern und danach prüfen, ob das neue Profil wirklich 7 neue Tage hat |

Grenzen der kostenlosen Apple-ID: Profile gelten je 7 Tage. Höchstens 3 Geräte und 3 eigene Apps pro Gerät, höchstens
10 App-IDs in 7 Tagen. Es gibt kein TestFlight, keine iCloud-Synchronisation und keine Push-Mitteilungen. Für Yolk
ist das egal, denn der Fotozugriff braucht keine Sonderfreigabe, nur einen Hinweistext in der App. Für den App Store
bräuchte es später doch das Bezahlkonto (99 € pro Jahr).

## Meilensteine

Jeder Meilenstein endet mit einem Test auf Garys echtem iPhone, nicht nur im Simulator.

1. **Kernablauf:** Grundgerüst, Fotozugriff, Wischen über „Alle Fotos“, Papierkorb, einmal gesammelt löschen,
   Hinweis zu „Zuletzt gelöscht“. Erster Test auf dem Gerät.
2. **Modi und Extras:** Screenshots, Videos (größte zuerst), nach Monat oder Jahr, Rückgängig, Favorit, Später,
   Speicher-Zähler.
3. **Ähnliche Fotos:** Gruppen erkennen, bestes Foto vorschlagen, Gruppen-Ansicht.
4. **Feinschliff:** Design nach den Entwürfen, Animationen und Vibration, englische Texte, App-Symbol, Startbildschirm.

## Risiken und was zuerst geprüft wird

- **Bauen per SSH:** Simulator-Builds brauchen keine Signatur und gehen per SSH. Fürs iPhone kann das Signieren
  über SSH scheitern (abgelaufene Anmeldung, gesperrter Schlüsselbund). Dann reicht es, wenn Gary in Xcode einmal auf
  „Ausführen“ klickt. Das wird beim ersten iPhone-Build geklärt.
- **Neuere Werkzeuge:** Xcode 27.2 bringt die iOS-27-Werkzeuge mit. Das offizielle Größenfeld `dataSize` nutzt Yolk
  deshalb auf iOS 27 und fällt auf iOS 18–26 auf das alte Feld zurück.
- **WLAN-Installation:** Das WLAN muss IPv6 können, und nach jedem iOS-Update muss das iPhone neu gekoppelt werden.
  VPNs wie Tailscale können die Verbindung zwischen MacBook und iPhone stören. Notfalls geht es per Kabel.
- **Löschen hängt:** Apple bestätigt einen Fehler (iOS 18.6 bis 27), bei dem das Löschen nie fertig wird, oft bei
  48-MP-ProRAW-Fotos. Yolk braucht deshalb eine Zeitgrenze, eine verständliche Meldung und einen Weg, es erneut zu
  versuchen.
- **Favoriten:** Möglicherweise fragt iOS beim Markieren jedes Mal nach. Dann sammelt die App die Favoriten genau wie
  den Papierkorb und setzt sie auf einmal. Das wird im ersten Gerätetest geklärt.
- **Videogröße:** Die Dateigröße steht in den Fotodaten, Apple dokumentiert das Feld aber nicht offiziell. Fällt es
  weg, sortiert die App ersatzweise nach Länge mal Auflösung.
- **Fotos nur in iCloud:** Ist „iPhone-Speicher optimieren“ aktiv, liegen viele Originale nur in der Cloud. Die App
  zeigt dann zuerst die kleine Vorschau und lädt die scharfe Fassung nach.
- **Zähler:** Der Zähler zeigt die Größe der gelöschten Dateien und sagt dazu, dass der Platz erst nach dem Leeren
  von „Zuletzt gelöscht“ frei wird. Die Speicheranzeige von iCloud kann dem hinterherhinken.
- **Name:** Ob „Yolk“ im App Store frei ist, wird erst vor einem App-Store-Start geprüft.

## Hinweis zum Repo

Das Repo ist öffentlich. Rechnerbezogene Details wie die Platzliste des Mac mini stehen deshalb nicht hier, sondern
nur lokal auf dem Mac.
