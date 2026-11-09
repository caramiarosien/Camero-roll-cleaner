# Yolk: Briefing für die Weiterarbeit

Stand: Mo 09.11.2026, 22:30. Gedacht für ein neues Projekt direkt auf Garys MacBook. Bisher wurde vom Mac mini aus
per SSH auf dem MacBook gebaut. Ab jetzt läuft alles lokal auf dem MacBook.

Zuerst lesen: dieses Briefing, dann [`docs/PLAN.md`](PLAN.md). Dort stehen alle Entscheidungen mit Begründung, das
Design, die Technik, die Risiken und die Meilensteine.

## Worum es geht

Gary hat tausende Fotos, sein iCloud-Speicher ist ständig voll. **Yolk** ist eine iPhone-App zum Aufräumen der
Mediathek im Tinder-Stil:

- **Rechts wischen:** behalten. **Links wischen:** in den Papierkorb der App.
- **Nach oben:** Favorit (ab Meilenstein 2). **Nach unten:** später, das Foto kommt ans Ende des Stapels (ab Meilenstein 2).
- Am Ende wird der Papierkorb **einmal gesammelt** gelöscht, mit genau einer iOS-Abfrage. Die Fotos landen dann in
  „Zuletzt gelöscht“. Den Ordner muss Gary selbst in der Fotos-App leeren, erst dann wird der Speicher frei. Die App
  erklärt das.
- Schwerpunkte: alte Screenshots, sehr ähnliche Fotos und Serien, große Videos.

## Wo alles liegt

| Was | Wo |
|---|---|
| Repo | https://github.com/caramiarosien/Camero-roll-cleaner (öffentlich, Branch `main`) |
| Plan mit allen Entscheidungen | `docs/PLAN.md` |
| Xcode-Projekt | `Yolk.xcodeproj` (Ordner-synchronisierte Gruppen: neue Dateien in `Yolk/` werden automatisch Teil der App) |
| App-Code | `Yolk/` |
| Build-Skript für den alten Weg (Mac mini → MacBook per SSH) | `scripts/mb-build.sh`, lokal nicht nötig |

Auf dem MacBook liegen noch drei reine Spiegelkopien ohne Git aus dem alten Bauweg: `~/Developer/Yolk`,
`~/Developer/Yolk-data` und `~/Developer/Yolk-review`. Sie können weg. Für das neue Projekt das Repo frisch klonen.

## Stand

- **Meilenstein 1 ist fertig programmiert und kompiliert** mit Xcode 27.2 gegen das iOS-Simulator-SDK, ohne Fehler und
  ohne Swift-Warnungen. Rund 2.000 Zeilen Swift.
- Ein unabhängiges Code-Review hat 10 Fehler gefunden, alle sind behoben (siehe Commit `f4dc8b6`).
- **Die App ist noch nie gelaufen**, weder im Simulator noch auf dem iPhone. Grund: Xcode auf dem MacBook hat seine
  Zusatzkomponenten nach dem Update auf 27.2 noch nicht installiert (`xcodebuild -checkFirstLaunchStatus` meldet 69,
  dazu „CoreSimulator is out of date“).

## Erste Schritte im neuen Projekt

1. **Xcode einmal öffnen** und die Zusatzkomponenten installieren (fragt nach dem Mac-Passwort). Danach muss
   `xcodebuild -checkFirstLaunchStatus` mit 0 enden.
2. **Repo klonen:** `git clone https://github.com/caramiarosien/Camero-roll-cleaner.git`
3. **Signieren:** In Xcode `Yolk.xcodeproj` öffnen, Target *Yolk*, *Signing & Capabilities*, unter *Team* das
   „Personal Team“ der kostenlosen Apple-ID wählen. Ein Apple-Development-Zertifikat ist auf dem MacBook schon
   eingerichtet. Xcode schreibt die Team-ID dann in `project.pbxproj`. Sie ist kein Geheimnis, trotzdem vor dem
   Committen bewusst entscheiden, ob sie ins öffentliche Repo soll. Bundle-ID: `io.github.camerorollcleaner.yolk`.
4. **Im Simulator starten** (iOS 26.4, z. B. iPhone 17 Pro). Der Simulator hat kaum Fotos: Testbilder per Drag & Drop
   ins Simulator-Fenster ziehen oder mit `xcrun simctl addmedia booted <Dateien>` hinzufügen, gern auch Screenshots
   und Videos.
5. **Aufs iPhone:** iPhone per Kabel anschließen, „Diesem Computer vertrauen“ tippen. Den Entwicklermodus einschalten
   (*Einstellungen → Datenschutz & Sicherheit*, erscheint erst nach dem Koppeln), neu starten. In Xcode auf
   „Ausführen“ klicken. Danach auf dem iPhone *Einstellungen → Allgemein → VPN & Geräteverwaltung → Entwickler-App →
   Vertrauen*.
6. **Alle 7 Tage** läuft das kostenlose Profil ab. Dann die App einfach neu aufspielen, die Daten in der App bleiben
   erhalten.

Bauen aus dem Terminal (Simulator, ohne Signatur):

```sh
xcodebuild -project Yolk.xcodeproj -scheme Yolk -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

Beim Durchsuchen der Ausgabe nach Swift-Warnungen auf `\.swift:[0-9]+:[0-9]+: warning:` filtern, denn der Dateipfad
steht vor `warning:`.

## Was Meilenstein 1 kann

- **Erster Start** (`Features/Onboarding/PermissionView.swift`): Erklärung und Frage nach dem Fotozugriff. Eigene Texte
  für „Kein Zugriff“ (Link zu den Einstellungen) und „Ausgewählte Fotos“ (vollen Zugriff erlauben, Auswahl ändern oder
  bewusst mit der Auswahl weitermachen).
- **Start** (`Features/Home/HomeView.swift`): Logo, Überschrift „Weniger *Ballast.* Mehr Platz.“, Speicher-Zähler,
  Papierkorb-Karte und Modus-Kacheln. Nur „Alle Fotos“ ist aktiv, Screenshots, Ähnliche, Videos und Nach Monat
  zeigen „Bald“.
- **Wischen** (`Features/Swipe/`): Kartenstapel, Kippen beim Ziehen, Stempel „Behalten“ und „Weg“, Vibration,
  Rückgängig (auch mehrfach), Vorladen der nächsten Karten, Knöpfe als Alternative zum Wischen.
- **Papierkorb** (`Features/Trash/TrashView.swift`): Raster aller Links-Wischer. Ein Tippen holt ein Foto zurück
  (wird „behalten“). „N Fotos löschen“ löscht alles in einem Schritt mit 120 s Zeitgrenze. Danach erscheint die
  Anleitung zu „Zuletzt gelöscht“ (`DeletedHintView.swift`).
- **Gespeichert** wird mit SwiftData: ein `Decision`-Eintrag je Foto (`assetID`, Art, Zeitpunkt, geschätzte Größe).
  Der Speicher-Zähler liegt in UserDefaults (`freedBytes`).

## Dateikarte

| Datei | Zweck |
|---|---|
| `App/YolkApp.swift` | Einstieg, registriert die Schrift, SwiftData-Container |
| `App/RootView.swift` | wählt je nach Fotozugriff Erklärung oder Start |
| `Design/Theme.swift` | Farben, Rundungen, `Font.display` (Instrument Serif), `DisplayHeadline` mit kursivem Royalblau-Wort |
| `Models/MediaItem.swift` | ein Foto oder Video (PHAsset, ID = `localIdentifier`) |
| `Models/Decision.swift` | SwiftData-Modell der Entscheidungen, `DecisionKind` (keep, trash, favorite, later) |
| `Services/PhotoLibrary.swift` | Zugriff, Abrufen, Größen, gesammeltes Löschen mit Zeitgrenze, Favoriten, Änderungen der Mediathek (`changeToken`), Auswahl bei eingeschränktem Zugriff |
| `Services/PhotoLibrary+Queries.swift` | leichte Abfragen für den Start (Anzahl, neueste offene Fotos, existierende IDs) |
| `Services/AssetByteSize.swift` | Dateigröße: iOS 27 offizielles `dataSize`, iOS 18–26 das undokumentierte `fileSize`, sonst Schätzung |
| `Services/ImagePipeline.swift`, `Services/AssetImageView.swift` | Bilder laden und vorladen über einen gemeinsamen `PHCachingImageManager`, erst unscharf, dann scharf, Platzhalter nach 8 s |
| `Features/...` | Oberfläche (siehe oben) |
| `Resources/Fonts/` | Instrument Serif Regular und Italic, Lizenz `OFL.txt` |
| `Info.plist` | nur `PHPhotoLibraryPreventAutomaticLimitedAccessAlert`, der Rest kommt aus den Build-Einstellungen |

## Design in Kürze

Stil wie phia.com: elegante Serifen-Überschriften mit einem kursiven Wort, viel Weißraum, ruhige Bildkacheln. Hell, fast
neutral.

- Hintergrund `#FAF9F6`, Schrift `#151A2B`, Nebentext `#71768A`, Linien `#E8E6E1`.
- **Royalblau `#2445C6` ist die einzige Farbe**, Hinweise auf `#EEF1FB`.
- Eigelb `#F5BF2A` nur als Punkt im Logo. Gary wollte ausdrücklich „weniger farbig, weniger Gelb“.
- Schrift: Instrument Serif (OFL) für Überschriften, sonst Systemschrift. Karten mit 22 pt Rundung, Kacheln 14 pt,
  Hauptknöpfe als Pille.
- Nur heller Modus.

## Als Erstes testen (Meilenstein 1 auf dem iPhone)

- Fragt iOS beim gesammelten Löschen wirklich nur **einmal**?
- Wird ein Abbruch in der iOS-Abfrage erkannt (Fehlercode 3072), ohne Fehlermeldung?
- Sind die Größen echt (Feld `fileSize` auf iOS 26) oder nur geschätzt?
- Wie verhalten sich Fotos, die nur in iCloud liegen („iPhone-Speicher optimieren“): Vorschau, Ladezeit, Platzhalter?
- Fühlt sich das Wischen flüssig an, auch bei tausenden Fotos? Wie lange dauert das erste Laden?
- Gefällt Gary das Design auf dem echten Gerät? Er beurteilt das selbst. Ohne seinen Daumen gilt ein Meilenstein nicht
  als fertig.

## Nächste Meilensteine

2. **Modi und Extras:** Screenshots (`PHAssetMediaSubtype.photoScreenshot` / `smartAlbumScreenshots`), Videos nach
   Größe (`PhotoLibrary.byteSizes(of:)` misst im Hintergrund), nach Monat oder Jahr, nach oben = Favorit
   (`setFavorite`, vermutlich gesammelt setzen, weil iOS eventuell nachfragt), nach unten = später (ans Ende des
   Stapels).
3. **Ähnliche Fotos:** Serien (`includeAllBurstAssets`) und zeitlich nahe Aufnahmen vorgruppieren, dann mit Vision
   (`GenerateImageFeaturePrintRequest`) auf den lokalen Vorschaubildern vergleichen, ohne iCloud-Download. Das beste Foto
   wählt die Bildbewertung (`CalculateImageAestheticsScoresRequest`, iOS 18) und markiert es vor. Gruppen-Ansicht statt
   Einzelkarte. Vision nur auf dem echten iPhone beurteilen.
4. **Feinschliff:** Animationen, englische Texte (String Catalog), App-Symbol, Startbildschirm, Danksagungen mit der
   Schriftlizenz.

## Stolpersteine

- **Löschen hängt:** Bei einem bestätigten Apple-Fehler (iOS 18.6 bis 27) wird das Löschen nie fertig. Deshalb die
  Zeitgrenze. Wird nach der Zeitgrenze doch noch gelöscht, rechnet der Papierkorb es beim nächsten Neuladen nach.
- **„Zuletzt gelöscht“** kann keine App leeren, und es gibt auch keinen direkten Link dorthin. `photos-redirect://`
  öffnet die Fotos-App, ist aber nicht dokumentiert. Für einen App-Store-Start neu bewerten.
- **Geteilte iCloud-Mediathek:** Löschen trifft alle Beteiligten. Fotos, die iOS nicht löschen lässt, meldet der
  Papierkorb.
- **Kostenlose Apple-ID:** 7 Tage pro Profil, höchstens 3 Apps pro Gerät, 10 App-IDs in 7 Tagen, kein TestFlight,
  kein iCloud und kein Push. Für den App Store bräuchte es das Bezahlkonto (99 € pro Jahr).
- **Installieren per WLAN** braucht IPv6 im Netz, VPNs wie Tailscale können stören. Nach iOS-Updates neu koppeln.

## Arbeitsweise mit Gary

- Auf Deutsch, in einfacher Sprache, Fachbegriffe kurz erklären.
- Erst planen und fragen, bei größeren Schritten Garys Go abwarten. Mehrere Fragen am besten gebündelt zum Anklicken.
- Optik zählt: Gary will modern und hochwertig. Früh auf dem echten Gerät zeigen statt nur Tests zu melden.
- Commits und Pushes nur auf Garys Ansage. Das Repo ist öffentlich, also keine Geheimnisse und keine
  rechnerbezogenen Pfade oder Zugangsdaten.
- Subagenten sind erwünscht (Garys Wunsch), etwa für unabhängige Code-Reviews, Recherchen und parallele Teilaufgaben.
