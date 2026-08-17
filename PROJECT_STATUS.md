# Project Status

**Spiel:** Our Story — Kapitel 1: Berlin
**Engine:** Godot 4.5 (GDScript)
**Aktuelle Stufe:** Stage 4 — Vaccination Darts (implementiert, wartet auf
Probespielen). Stage 1 bis 3 abgenommen.

**Kapitel 1 ist damit von Anfang bis Ende spielbar:** abholen, laufen,
ankommen, werfen, gewinnen.

---

## Was funktioniert

### Projektgerüst
* `project.godot` mit Forward+ Renderer, 60 Hz fester Physik-Tick, 1920×1080
* Input-Map vollständig über Actions (nie harte Keycodes):
  `move_forward/back/left/right`, `look_left/right/up/down`, `sprint`,
  `interact`, `pause`, `debug_overlay` — jeweils Tastatur **und** Gamepad
* Physik-Layer benannt: `world`, `player`, `npc`, `interactable`

### Spielerfigur (`actors/player/`)
* `CharacterBody3D`, kamerarelative Bewegung
* Getrennte Werte für Beschleunigung (18 m/s²) und Bremsen (26 m/s²) —
  das Bremsen ist bewusst kräftiger, damit Stoppen knackig wirkt
* Gehen 3,4 m/s, Sprint 6,2 m/s, weicher Übergang dazwischen
* Analoge Teilauslenkung am Stick ergibt Teilgeschwindigkeit
* Framerate-unabhängige Drehung, die bei hohem Tempo etwas träger wird
* **Stufen-Steigen** bis 0,4 m — Godots `CharacterBody3D` bringt das nicht mit;
  ohne diese Ergänzung blockiert bereits eine 18-cm-Treppenstufe die Figur
  vollständig (siehe „Gelöste Probleme")
* Signale `started_moving` / `stopped_moving` für die spätere Animationsschicht

### Kamera (`camera/`)
* Gedämpfte Verfolgerkamera, **nicht** an den Spieler geparented
* Getrennte horizontale (9.0) und vertikale (5.0) Dämpfung — die weichere
  Vertikale glättet Treppen und Rampen
* `SpringArm3D` löst Hindernisse auf, 4,2 m Abstand
* Maus und Gamepad, Y-Achse invertierbar, Pitch auf −55°…+22° begrenzt
* Sanfte Auto-Ausrichtung hinter die Figur nach 1,4 s ohne Kameraeingabe
* Dezenter FOV-Zuwachs beim Sprinten (68° → 74°)

### Testumgebung (`scenes/test_playground.tscn`)
Bewusst diagnostisch, nicht hübsch:
* 100-m-Bahn mit Markierungen alle 5 m → Geschwindigkeit wird sichtbar
* Rampen mit 15°, 30°, 45°
* Treppe mit 8 Stufen à 18 cm plus Podest
* Slalom aus 6 Pfosten → Wendigkeit
* Enge Gasse mit Torbogen und Pfeiler → Kamerakollision
* Referenzquader in Figurenhöhe → Maßstabsgefühl

### Debug-Overlay (`ui/`)
F3 blendet fps, Geschwindigkeit, Spitzenwert, Bodenkontakt, Position und
Kameraabstand ein.

### Kapitelszene (`chapters/berlin/berlin_chapter.tscn`)
Eine durchgehende Strecke von rund 360 m in fünf Abschnitten mit vier Ecken:

1. **Bürostraße** — die Spielerin startet hier, Oliver wartet rechts in einer
   Eingangsnische mit Vordach und warmem Licht
2. **Querstraße** mit Tramgleisen
3. **Zweite Nord-Süd-Straße** — hier das geschlossene Café mit Markise,
   Absperrband und herausgestellten Stühlen (erstes Gespräch)
4. **Zweite Querstraße**
5. **Straße zur Dönerbude** — Desinfektionsspender am Weg (zweites Gespräch),
   am Ende die Bude mit Tresen, Vordach, Leuchtschild und Stehtischen

Der Fernsehturm steht 700 m nördlich und ist so bemessen, dass die Kugel
zwischen Dachlinie (13°) und oberem Bildrand (20°) liegt — er taucht in den
nach Norden führenden Abschnitten immer wieder auf. Wer ihn verschiebt, sollte
das nachrechnen, sonst verschwindet er aus dem Bild.

Die Häuserblöcke sind gleichzeitig die Begrenzung: es gibt keine unsichtbaren
Wände, man kann nirgends hinauslaufen.

### Interaktion (`systems/interaction/`)
`Interactable` ist eine Area3D-Komponente mit Text, An/Aus und Einmal-Flag;
sie weiß nicht, *was* passiert — das bleibt beim Kapitelskript. Der
`InteractionSensor` am Spieler wählt aus mehreren Kandidaten den plausibelsten
(Nähe **und** Blickrichtung) und schweigt, während eine Sequenz die Steuerung
hat. Dieselbe Komponente trägt später Café, Desinfektionsspender und Fahrrad.

### Kapitelablauf (`chapters/berlin/chapter_berlin.gd`)
Vier Stationen, als lesbare Abfolge geschrieben statt als Zustandsautomat:
Abholen an der Bürotür (auf Tastendruck), zwei Gespräche unterwegs und die
Ankunft an der Dönerbude (lösen beim Betreten aus, sie sind Teil der Geschichte
und keine optionalen Fundstücke).

Jede Szene läuft gleich ab: Steuerung abgeben, Oliver neben die Spielerin
holen, Kamera zur Seite schwenken, reden, alles zurückgeben. Auf Oliver wird
dabei höchstens 2,5 s gewartet — ein Gespräch, das nicht anfängt, weil jemand
hängengeblieben ist, wäre schlimmer als eine unsaubere Bildaufteilung.

Eine Station ergänzt man mit einem Area3D in der Szene und einer Zeile in
`_STATIONEN`.

### Dialog (`systems/dialogue/`)
`DialogueBox` spielt eine Liste aus `{"speaker", "text"}` ab, mit
Schreibmaschineneffekt; der erste Tastendruck vervollständigt die Zeile, der
zweite blättert weiter. `await dialogue.play(...)` kehrt zurück, wenn der
Spieler fertig gelesen hat. Die vier Gespräche stehen in
`chapters/berlin/dialogue_lines.gd` — reiner Inhalt, keine Logik.
**Alle Texte sind Platzhalter** in der beabsichtigten Tonlage, damit sich Länge
und Tempo beurteilen lassen.

### Companion (`actors/companion/`)
Vier Zustände: wartend, folgend, auf Position gehend, festgehalten.

Gefolgt wird **entlang der Fußspur der Spielerin**, nicht in gerader Linie zu
ihr. Der direkte Weg funktioniert auf einem offenen Platz und scheitert an der
ersten Ecke — der Begleiter läuft in die Hauswand, um die sie gerade herum ist.
Das Nachlaufen auf der Spur kostet knapp hundert gespeicherte Positionen und
bewältigt jede Ecke der Strecke, ohne Navigationsnetz. Ein kleiner seitlicher
Versatz sorgt dafür, dass er neben der Spur läuft statt exakt darin.

Holt bei Abstand bis 5,4 m/s auf — gemessen *entlang der Spur*, nicht Luftlinie,
sonst wirkt er hinter einer Ecke näher als er ist. Dreht sich im Stehen zur
Spielerin. Bewusst keine autonome KI.

### Minispiel Vaccination Darts (`chapters/berlin/darts/`)
Fünf Würfe, Zielpunktzahl 60, beides in `darts_config.gd` — im Spielcode steht
keine dieser Zahlen ein zweites Mal.

Ablauf eines Wurfs: mit der Maus zielen, Taste halten, im grünen Bereich des
Kraftbalkens loslassen. Zwei Entscheidungen prägen das Gefühl:

* Das Fadenkreuz bewegt sich in der **Ebene der Scheibe**, nicht über den
  Bildschirm. Dadurch ist das Zielen unabhängig von Auflösung und Bildwinkel.
* Die Wurfkraft wirkt **nur auf die Höhe**, nie auf die Seite. Das folgt daraus,
  dass die ganze Anfangsgeschwindigkeit skaliert wird: waagerechter Weg und
  Flugzeit ändern sich gegenläufig und heben sich exakt auf. Der Prüflauf misst
  0,0000 m seitliche Abweichung zwischen vollem und leerem Ladebalken. Zwei
  getrennte, verständliche Fehlerquellen statt einer diffusen.

Die Wertung ist absichtlich gutmütig: sechs Ringe von 5 bis 50 Punkten, und
selbst der schlechteste Ladestand landet noch im 15-Punkte-Ring. Wer die
Scheibe trifft, schafft die 60 also praktisch immer — Scheitern erfordert
Danebenzielen und wird mit einer freundlichen Zeile und sofortigem Neustart
quittiert.

Rückmeldung: Einschlagpartikel, aufsteigende Punktzahl, Kamerawackeln (stärker
ab 25 Punkten), Konfetti und Banner beim Gewinn.

### Einstellmenü (`ui/tuning_panel.gd`)
F1 öffnet im laufenden Spiel Schieberegler für alle Fühl-Werte. Damit lässt
sich das Fahrgefühl ohne Godot-Editor abstimmen — wichtig, weil das Beurteilen
der Bewegung am Rechner passieren muss, an dem gespielt wird.
*Werte kopieren* legt die Einstellungen als Text in die Zwischenablage,
*Zurücksetzen* stellt die Startwerte wieder her.
Einen weiteren Regler ergänzt man mit einer Zeile in der Liste `ROWS`.

---

## Start

```bash
godot --path .          # oder Projekt im Editor öffnen und F5
```

Steuerung: WASD / linker Stick, Maus / rechter Stick für die Kamera,
Shift / rechter Trigger zum Sprinten, Escape gibt die Maus frei
(Klick fängt sie wieder ein), **F1** öffnet die Einstellungen, F3 das Overlay.

Alternativ als fertige App bauen — dafür werden die Export-Vorlagen benötigt:

```bash
godot --headless --path . --export-release "macOS" "build/Our Story.zip"
```

---

## Automatischer Prüflauf

```bash
godot --headless --path . --script res://tools/headless_check.gd
```

Fährt die Figur mit simulierten Eingaben und prüft die Zahlen nach.
Aktueller Stand — alle Prüfungen bestanden:

| Messung | Wert |
| --- | --- |
| Gehgeschwindigkeit | 3,40 m/s |
| Sprintgeschwindigkeit | 6,20 m/s |
| Bremsweg aus 3,40 m/s | 0,19 m |
| Treppe (8 × 18 cm) | erreicht Podest bei y = 1,44 |
| Rampe 30° | erreicht y = 3,18 |
| Kamera | bleibt hinter der Figur, innerhalb der Federarmlänge |

Dazu der Kapitel-Prüflauf:

```bash
godot --headless --path . --script res://tools/headless_chapter_check.gd
```

Spielt **das ganze Kapitel** mit simulierter Eingabe durch — die Strecke wird
wirklich abgelaufen, nicht übersprungen. Deshalb dauert er ungefähr so lange
wie das Kapitel selbst, rund zwei Minuten.

| Messung | Wert |
| --- | --- |
| Gesamtdauer | 126 s (2,1 min) |
| davon Laufen | 106 s |
| davon Dialoge | 12 s |
| Von Oliver mitgelaufene Strecke | 343 m |
| Größter Rückstand von Oliver | 2,5 m |
| Ausgelöste Gespräche | 4 von 4 |

Die 12 s für die Dialoge sind der Prüflauf beim Durchklicken in
Höchstgeschwindigkeit. Wer die Zeilen wirklich liest, braucht dafür eher eine
Minute — die Gesamtdauer landet damit bei etwa 2,5 bis 3 Minuten, also im
angepeilten Bereich.

Der Prüflauf ersetzt **kein** Probespielen. Er belegt, dass die Werte
stimmen — nicht, dass sich die Bewegung gut anfühlt.

---

## Gelöste Probleme

**Godot kann keine Stufen steigen.** `move_and_slide()` behandelt eine
Treppenstufe wie eine Wand; die gerundete Kapselunterseite überwindet nur
wenige Zentimeter. Eine normale 18-cm-Stufe stoppte die Figur komplett.
`Player._try_step_up()` tastet nun voraus (blockiert unten, frei eine Stufe
höher, oben etwas Begehbares?) und hebt den Körper um genau die Stufenhöhe.
Zwei Fallstricke dabei, beide behoben: die Vorwärts-Prüfung muss eine feste
Mindestdistanz abtasten (eine Frame-Bewegung ist kleiner als die Physik-Marge),
und `is_on_floor()` allein genügt nicht als Bedingung — verkeilt auf einer
Stufenkante meldet Godot „Wand", was das Stufen-Steigen genau dann abschaltet,
wenn es die Figur befreien müsste.

**Ein perfekt gezielter Wurf traf die Mitte nicht.** Die Flugbahn wurde
schrittweise aufsummiert, und dabei sammelt sich in jedem Schritt ein halber
Schwerkraftschritt Fehler an — bei 60 Hz landet der Wurf rund drei Zentimeter
zu tief. Bei einem Innenring von 2,4 cm ist das der Unterschied zwischen
Volltreffer und Nebenring. Die Bahn wird jetzt geschlossen ausgewertet: der
Einschlagpunkt steht schon beim Abwurf fest und ist unabhängig von der Bildrate.

**Der Begleiter pendelte 20 Sekunden lang vor der Bürotür.** Er steuert einen
seitlich versetzten Punkt neben der Fußspur an, „erreicht" wurde aber am Punkt
*ohne* Versatz gemessen — den erreicht er nie, also hakte die Spur nie weiter.
Dazu klappte die Seitenrichtung bei jeder Bewegung um, weil sie aus seiner
eigenen Blickrichtung stammte. Er lief also auf der Stelle hin und her, bis
seine gespeicherte Spur überlief und ihn zufällig freigab — der Kapitel-Prüflauf
maß einen Rückstand von 66,8 m, exakt die Spurlänge. Jetzt zählt der Versatz zur
Erreicht-Schwelle, und die Seitenrichtung kommt aus dem Verlauf der Spur.

**Drei Häuserblöcke ragten in die Fahrbahn.** An zwei Kreuzungen verengten sie
die Straße, an der dritten versperrten sie die Abzweigung vollständig — der
Prüflauf blieb dort hängen.

**Die Straßen lagen komplett im Schatten.** 16 m breite Gassen zwischen 20 m
hohen Blöcken bekommen bei tiefstehender Sonne kein Licht; der Auftakt wirkte
bedrückend statt nostalgisch. Fahrbahnen auf 24 m verbreitert, Häuser gesenkt,
Sonne höher gestellt.

**Kamera-Selbstausrichtung ließ die Figur auf der Stelle pendeln.** Beim
Rückwärtsgehen dreht sich die Figur um, die Kamera schwenkt hinterher — und
damit kehrt sich die Bedeutung von „zurück" um, die Figur dreht sich wieder.
Der Kapitel-Prüflauf deckte es auf: Oliver legte nur 2,4 m statt 13 m zurück,
weil die Spielerin gar nicht vom Fleck kam. Die Ausrichtung greift jetzt nur
noch, wenn die Figur sich von der Kamera *weg* bewegt
(`auto_align_min_alignment`).

**Fernsehturm hinter der Sichtweite.** Die Kamera war auf 500 m Sichtweite
begrenzt, der Turm steht bei 700 m — er wurde schlicht weggeschnitten.

**Transponierte Transforms.** Godot serialisiert `Transform3D` in `.tscn`
zeilenweise, nicht spaltenweise. Dadurch stiegen die Rampen zur falschen Seite
(die Figur lief unten durch) und die Sonne leuchtete nach oben.

---

## Aktuelle Grenzen

* Alle Sichtbaren Elemente sind Platzhalter-Geometrie. Die Testfläche ist ein
  Entwicklungswerkzeug und wird später verworfen, nicht ausgebaut.
* Keine Animationen — die Figur gleitet als Kapsel. Der Controller liefert
  bereits `current_speed`, `speed_ratio` und die Bewegungssignale, an die eine
  Animationsschicht andocken kann.
* Kein Ton.
* Kamera und Spieler laufen beide im 60-Hz-Physiktakt. Das vermeidet Ruckeln
  zwischen beiden, deckelt die Kamerabewegung aber auf 60 Hz. Falls sich das
  auf einem 144-Hz-Monitor stockend anfühlt, ist das der erste Punkt zum
  Nachbessern.
* Die 45°-Rampe liegt exakt auf Godots Grenzwinkel — ob sie begehbar ist, ist
  Zufall. Sie steht als Grenzfall-Test dort, nicht als Zusicherung.
* `pause` gibt bisher nur die Maus frei; es gibt kein Pausenmenü.
* Der Companion kollidiert nicht mit der Spielerin (eigene Physik-Ebene). Das
  garantiert, dass er nie im Weg steht, sieht aber beim Durchlaufen komisch
  aus. Bewusste Wahl für diese Stufe, bei echten Figuren neu zu bewerten.
* Der Companion folgt der Fußspur der Spielerin. Das bewältigt alle Ecken der
  Strecke, hat aber eine Grenze: läuft man weiter als die gespeicherte Spur
  reicht (rund 67 m), schneidet er die Kurve. Beim Gehen und Sprinten auf
  dieser Strecke tritt das nicht auf.
* Der Companion hat kein Stufen-Steigen wie die Spielerin. Auf der ebenen
  Strecke egal, bei Treppen in späteren Abschnitten nachzurüsten.
* Der Dialog wartet auf Tastendruck, ohne Zeitautomatik und ohne Ton.
* Nach dem gewonnenen Minispiel bleibt das Bild auf dem Banner stehen. Ein
  Abspann oder eine Rückkehr ins Menü gibt es noch nicht.
* Die Figuren stehen beim Werfen bewusst außerhalb des Bildausschnitts: bei
  diesem engen Bildwinkel wird alles nah an der Kamera riesig. Eine
  Reaktionseinstellung auf die beiden gehört in den Feinschliff.
* Die Farben der Partikel konnte ich hier nicht abschließend beurteilen — die
  Prüfbilder entstehen mit Software-Rendering, nicht mit dem Renderer, den das
  fertige Spiel verwendet.
* Die zwei Gespräche unterwegs lösen beim Betreten aus. Läuft man versehentlich
  während eines laufenden Gesprächs in den nächsten Auslöser, wird dieser
  übersprungen. Auf der linearen Strecke praktisch ausgeschlossen.
* Es gibt noch keine optionalen Erinnerungspunkte zum Ansprechen — die
  `Interactable`-Komponente trägt sie, angelegt ist bisher nur Oliver.

## Bekannte Fehler

Keine offenen. Die während Stage 1 gefundenen sind oben unter „Gelöste
Probleme" beschrieben.

---

## Nächste sinnvolle Schritte

Stage 1 ist abgenommen: die Bewegung fühlt sich gut an, die Startwerte bleiben
wie sie sind. Als nächstes steht **Stage 2 — Meeting Oliver** an, sobald
ausdrücklich beauftragt.

Falls das Fahrgefühl später doch noch nachjustiert werden soll — über **F1** im
laufenden Spiel, dieselben Werte stehen im Editor unter `Player` und
`ThirdPersonCamera`:

| Empfindung | Stellschraube |
| --- | --- |
| stoppt zu abrupt / zu rutschig | `Player > braking` (aktuell 26) |
| läuft zu träge an | `Player > acceleration` (18) |
| dreht zu behäbig / zu zappelig | `Player > turn_responsiveness` (14) |
| Tempo insgesamt falsch | `walk_speed` (3,4) und `sprint_speed` (6,2) |
| Kamera klebt / schwimmt | `follow_damping` (9,0) |
| Kamera zu nah / zu weit | `SpringArm3D > spring_length` (4,2) |
| Kamera dreht sich ungefragt | `auto_align_enabled` / `auto_align_rate` |

### Rückmeldung aus dem Probespielen (2026-08-17)

Stage 2 spielt sich gut, Oliver ist ohne Suchen zu finden — die Blickführung
funktioniert also. Offener Wunsch: **Oliver soll an einem Hauseingang warten**
statt frei auf dem Platz zu stehen. Als Kulissenarbeit in
`ASSET_REQUIREMENTS.md` vermerkt.

### Noch zu beurteilen

* Stimmt der Abstand, in dem der Hinweis „Ansprechen" erscheint?
* Ist das Dialogtempo richtig — Schreibgeschwindigkeit, Zeilenlänge?
* Sitzt der Kamerawinkel im Gespräch gut? (`gespraechswinkel_grad`, 48°)
* Läuft Oliver angenehm mit, oder klebt er / bleibt er zurück?
  Regler dafür stehen unter F1 im Abschnitt *Begleiter*.

### Beim Probespielen von Stage 3 zu beurteilen

* Stimmt die Gehzeit? Zielvorgabe waren 2–3 Minuten.
* Sitzen die zwei Gespräche unterwegs an den richtigen Stellen, oder kommen
  sie zu früh / zu spät?
* Verliert man unterwegs die Orientierung, oder führt die Straße von selbst?
* Läuft Oliver um die Ecken angenehm mit?
* Trägt der Ablauf Abholen → Laufen → Ankommen, oder fehlt dazwischen etwas?

### Beim Probespielen von Stage 4 zu beurteilen

* Ist der Wurf verständlich, ohne dass es jemand erklärt?
* Ist die Idealzone auf dem Kraftbalken breit genug?
* Trifft man gut genug, um Spaß zu haben — oder zu leicht, um stolz zu sein?
* Passt die Kamerafahrt von der Bude auf die Scheibe?
* Ist der Übergang „Ankunft → Minispiel" flüssig, oder ruckelt das Hinstellen
  der beiden Figuren?

Stellschrauben stehen am Knoten `DartsGame` im Inspector: `wurf_tempo`
(flachere Bahn = weniger Wirkung von Ladefehlern), `kraft_einfluss`,
`idealzone`, `maus_empfindlichkeit`, `kamerafahrt`.

### Danach: Stage 5 und 6 — Feinschliff

Echte Modelle und Animationen, Berliner Kulisse statt Blöcke, Ton und Musik,
Kameraübergänge, Pacing, Dialogtiming. Dazu die gesammelten Punkte: Oliver an
den Hauseingang, optionale Erinnerungspunkte unterwegs, Stufen-Steigen für den
Begleiter, eine Reaktionseinstellung beim Gewinn.

Nicht begonnen und bewusst nicht vorbereitet: spätere Kapitel.
