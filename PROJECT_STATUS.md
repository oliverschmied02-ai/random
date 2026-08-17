# Project Status

**Spiel:** Our Story — Kapitel 1: Berlin
**Engine:** Godot 4.5 (GDScript)
**Aktuelle Stufe:** Stage 6 — der Rahmen ums Spiel: Titelbildschirm, Ton,
Kapitelauftakt (implementiert, wartet auf Probespielen). Stage 1 bis 4
abgenommen, Stage 5 ausgeliefert.

**Kapitel 1 ist damit von Anfang bis Ende erzählt:** abholen, laufen, ankommen,
werfen, gewinnen — und danach ein Schlussbild, in dem die beiden miteinander
reden, gefolgt vom Abspann.

---

## Was funktioniert

### Rahmen (`ui/title_screen.tscn`, `ui/chapter_card.tscn`)
Das Spiel fiel vorher mit der Tür ins Haus: Doppelklick, und man stand mitten
in Berlin, mit gefangener Maus. Jetzt gibt es einen Anfang.

* **Titelbildschirm** mit gezeichneter Dachlinie (`ui/skyline.gd`, `_draw()`
  statt Bilddatei — zwei Dutzend Rechtecke und ein Kreis, passt sich jeder
  Fenstergröße an), Titel, *Anfangen*, *Beenden* und leiser Musik. *Anfangen*
  blendet ab und wechselt erst dann die Szene.
* **Kapitelkarte** — dieselbe Tafel am Anfang und am Ende: `auftakt()` beginnt
  schwarz und gibt das Bild frei, `abspann()` nimmt es weg und behält es.
  Während des Auftakts ruht die Steuerung.
* **Pausenmenü** mit Lautstärkereglern und *Zum Titelbildschirm*.

### Ton (`audio/`, `systems/audio/`)
Alle Klänge sind **synthetische Platzhalter** und entstehen in
`tools/make_placeholder_audio.py` — ohne Fremdmaterial, ohne Abhängigkeiten,
reproduzierbar. Ein Schritt kürzer oder ein Einschlag trockener heißt: eine Zahl
im Skript ändern und neu erzeugen. Ersetzen heißt: gleiche Datei, gleicher Name.

* Vier Tritte, Stadtschleife, Brummen des Budenschilds, Dart-Einschlag,
  Ladeton, Volltreffer, Siegfanfare, Menüklick, Titelmusik
* **Schritte** (`systems/audio/schritte.gd`) zählen den zurückgelegten *Weg*
  statt der Zeit: alle 1,5 m ein Tritt. Damit hängt die Kadenz am Tempo — wer
  rennt, tritt öfter auf. Gemessen: 2,2 Schritte je Sekunde beim Gehen.
* Zwei Busse, **Musik** und **Klang**, je ein Regler im Pausenmenü.
  `systems/audio/ton.gd` merkt die Werte in `user://einstellungen.cfg` — als
  statische Klasse und nicht als Autoload, damit auch die Prüfläufe drankommen.

### Platz für die echten Figuren (`systems/figur/figur.gd`)
Der Knoten `Visual` beider Figuren ist ein Steckplatz: liegt unter
`actors/models/` eine Datei mit dem erwarteten Namen, wird sie geladen, um 180°
gedreht (glTF schaut nach +Z, Godot nach −Z), **gemessen** und auf die
Sollhöhe skaliert; der Kapsel-Platzhalter blendet sich aus. Fehlt die Datei,
bleibt alles beim Alten — Bewegung, Kollision und Kamera hängen an der Figur,
nie an ihrem Aussehen.

Skaliert wird nicht nach Gefühl, sondern aus den Ausmaßen aller sichtbaren
Teile: ein Mensch, der einen Kopf zu groß ist, fällt sofort auf. Der Prüflauf
baut sich dafür einen 2,40 m großen Prüfling und verlangt 1,75 m ± 2 cm.

Erwartet werden `actors/models/anne.glb` (1,72 m) und `oliver.glb` (1,82 m);
die Anleitung dazu steht in `actors/models/README.md`.

**Oliver ist da** (2026-08-17): 90 273 Dreiecke, 73 Knochen im Mixamo-Schema,
1,81 m, T-Pose, keine Animationen. Er steht im Kapitel, in richtiger Größe und
Blickrichtung; Anne ist noch eine Kapsel. Weil es noch keine Animationen gibt,
nimmt die Figur beim Aufbau die Arme aus der T-Pose herunter — eine ruhige
Haltung ist das Mindeste, bevor jemand mit ausgestreckten Armen durch Berlin
gleitet.

Damit wächst der fertige Build von 29 auf 47 MB und passt nicht mehr durch den
Chat. Texturen sind bereits auf 512 Pixel begrenzt (spart 10 MB, aus
Spielentfernung nicht zu sehen); mehr geht nur über das Netz der Figur.

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
  vollständig (siehe „Gelöste Probleme"). Liegt als eigener Baustein in
  `systems/motion/step_climber.gd`, weil Spielerin **und** Begleiter ihn
  brauchen und GDScript keine Mehrfachvererbung kennt
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
Fünf Abschnitte, als lesbare Abfolge geschrieben statt als Zustandsautomat:
Abholen an der Bürotür (auf Tastendruck), zwei Gespräche unterwegs und die
Ankunft an der Dönerbude (lösen beim Betreten aus, sie sind Teil der Geschichte
und keine optionalen Fundstücke).

Jede Szene läuft gleich ab: Steuerung abgeben, Oliver neben die Spielerin
holen, Kamera zur Seite schwenken, reden, alles zurückgeben. Auf Oliver wird
dabei höchstens 2,5 s gewartet — ein Gespräch, das nicht anfängt, weil jemand
hängengeblieben ist, wäre schlimmer als eine unsaubere Bildaufteilung.

Eine Station ergänzt man mit einem Area3D in der Szene und einer Zeile in
`_STATIONEN`.

### Erinnerungen am Weg (`systems/interaction/memory_point.tscn`)
Drei optionale Fundstücke, die niemand sehen muss: ein Abstandsschild an der
Bürostraße, eine Parkbank an der Café-Straße, ein Fahrrad ohne Sattel an der
letzten Geraden. Sie halten den Weg nicht an, sondern warten darauf,
angesprochen zu werden — deshalb `Interactable` statt Auslösefläche.

Der Ablauf ist bewusst viel leichter als bei einer Station: niemand wird
umgestellt, die Kamera bleibt stehen, nur die Steuerung ruht für die Dauer der
ein bis zwei Sätze. Ein weiteres Fundstück ergänzt man mit einer Instanz von
`memory_point.tscn` unter `Erinnerungen` und einer Zeile in `_ERINNERUNGEN`.

### Abschluss des Kapitels
Nach der gewonnenen Runde tritt das Minispiel ab (`abschluss_uebernehmen()`:
Anzeige weg, Eingaben aus, Kamerawackeln beendet), beide Figuren gehen auf ihre
Marken unter `Abschluss` und drehen sich zueinander, die Kamera fährt daneben
und weitet ihren Bildwinkel von 27° auf 50°. Dann reden sie, dann kommt der
Abspann (`ui/chapter_end.tscn`): abblenden, Titel stehen lassen, leiser Hinweis
auf das Menü.

Die Reihenfolge ist der ganze Trick — erst wenn das Minispiel die Kamera
losgelassen hat, darf die Fahrt beginnen; erst wenn beide stehen, darf geredet
werden.

Kadrage und Zeiten stehen als Werte am Kapitelknoten (`abschluss_vorlauf`,
`abschluss_fahrt`, `abschluss_blickhoehe`, `abschluss_bildwinkel`), die Marken
für beide Figuren und die Kamera als Marker3D in der Szene.

### Pausenmenü (`ui/pause_menu.gd`)
Escape hält das Spiel an und gibt dabei die Maus frei; *Weiter* und
*Spiel beenden*. Vorher gab Escape nur die Maus frei — praktisch beim
Entwickeln, aber für jemanden, der einfach kurz weg muss, kein Verhalten.

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
Spielerin. Steigt Stufen wie die Spielerin (derselbe `StepClimber`). Bewusst
keine autonome KI.

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
| Gesamtdauer | 128 s (2,1 min) |
| davon Laufen | 106 s |
| davon Dialoge | 12 s |
| Von Oliver mitgelaufene Strecke | 354 m |
| Größter Rückstand von Oliver | 2,5 m |
| Ausgelöste Gespräche | 4 von 4 |

Die 12 s für die Dialoge sind der Prüflauf beim Durchklicken in
Höchstgeschwindigkeit. Wer die Zeilen wirklich liest, braucht dafür eher eine
Minute — die Gesamtdauer landet damit bei etwa 2,5 bis 3 Minuten, also im
angepeilten Bereich.

Dazu der Prüflauf für die beiden Enden des Kapitels:

```bash
godot --headless --path . --script res://tools/headless_ending_check.gd
```

Er spricht jedes Fundstück am Weg an und prüft, dass es redet und die Steuerung
zurückgibt; danach gewinnt er eine Runde und misst das Schlussbild nach: beide
auf ihren Marken (< 0,35 m), einander zugewandt (Blickübereinstimmung > 0,9),
Kamera auf ihrer Marke und auf die Mitte gerichtet — und beide **ganz** im Bild,
von den Füßen bis über den Kopf.

Und der Dart-Prüflauf:

```bash
godot --headless --path . --script res://tools/headless_darts_check.gd
```

Die Prüfläufe ersetzen **kein** Probespielen. Sie belegen, dass die Werte
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

**Die Dart-Anzeige lag von Anfang an über dem Bild.** Wurfzähler und
Punktestand gehören zum Minispiel, das aber von Beginn an in der Szene steht —
also stand seine Anzeige schon während des Spaziergangs über der Zielangabe.
Aufgefallen ist es erst auf einem Prüfbild, nicht im Code. Die Anzeige taucht
jetzt mit dem Minispiel auf und verschwindet mit ihm.

**Das Schlussbild zeigte zwei angeschnittene Oberkörper.** Die Minispielkamera
steht auf 27° Bildwinkel — ein Teleobjektiv, das aus fünf Metern die Scheibe
füllt. Aus zwei Metern passen damit keine zwei Menschen ins Bild. Der Abschluss
weitet den Bildwinkel auf 50°, geht auf knapp vier Meter zurück und zielt auf
Hüft- statt Kopfhöhe, sonst stehen beide in der unteren Bildhälfte und die
Dialogbox schneidet ihnen die Füße ab. Der Prüflauf misst das jetzt mit: er
verlangt Füße, Mitte und Kopf beider Figuren im Sichtkegel.

**Lambdas fangen lokale Variablen als Kopie ein.** In GDScript ist
`var fertig := false` plus `func(): fertig = true` wirkungslos — die Zuweisung
trifft eine Kopie. Im Kapitel wartete deshalb die Aufstellung vor jedem Gespräch
immer in die volle Frist von 2,5 s, statt loszulegen, sobald Oliver steht; und
im Prüflauf zählte der Schrittzähler ins Leere und meldete „gar kein Ton". Beide
Stellen benutzen jetzt ein Dictionary bzw. ein Feld — beides wird als Referenz
gefangen.

**Die Schleifen liefen nicht.** Godots WAV-Importeur nummeriert
`edit/loop_mode` anders als die Laufzeit-Aufzählung: *0 = aus der WAV lesen,
1 = aus, 2 = vorwärts*. Mit der naheliegenden 1 blieb die Titelmusik nach einem
Durchlauf still. Der Rahmen-Prüflauf prüft das jetzt mit.

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
* Aller Ton ist synthetisch — Platzhalter in der richtigen Rolle und Länge,
  keine Aufnahmen. Es gibt keine Stimmen, keine Schrittvarianten nach
  Untergrund, keine Ereignisse in der Stadtschleife.
* Kamera und Spieler laufen beide im 60-Hz-Physiktakt. Das vermeidet Ruckeln
  zwischen beiden, deckelt die Kamerabewegung aber auf 60 Hz. Falls sich das
  auf einem 144-Hz-Monitor stockend anfühlt, ist das der erste Punkt zum
  Nachbessern.
* Die 45°-Rampe liegt exakt auf Godots Grenzwinkel — ob sie begehbar ist, ist
  Zufall. Sie steht als Grenzfall-Test dort, nicht als Zusicherung.
* Der Companion kollidiert nicht mit der Spielerin (eigene Physik-Ebene). Das
  garantiert, dass er nie im Weg steht, sieht aber beim Durchlaufen komisch
  aus. Bewusste Wahl für diese Stufe, bei echten Figuren neu zu bewerten.
* Der Companion folgt der Fußspur der Spielerin. Das bewältigt alle Ecken der
  Strecke, hat aber eine Grenze: läuft man weiter als die gespeicherte Spur
  reicht (rund 67 m), schneidet er die Kurve. Beim Gehen und Sprinten auf
  dieser Strecke tritt das nicht auf.
* Der Dialog wartet auf Tastendruck, ohne Zeitautomatik und ohne Ton.
* Nach dem Abspann bleibt der Titel stehen. Eine Rückkehr ins Menü oder ein
  zweites Kapitel gibt es noch nicht — Escape öffnet das Pausenmenü, dort
  lässt sich das Spiel beenden.
* Die Figuren stehen **beim Werfen** weiter außerhalb des Bildausschnitts; erst
  der Abschluss zeigt sie. Eine Reaktion zwischen den Würfen gehört in den
  Feinschliff.
* Die Farben der Partikel konnte ich hier nicht abschließend beurteilen — die
  Prüfbilder entstehen mit Software-Rendering, nicht mit dem Renderer, den das
  fertige Spiel verwendet.
* Die zwei Gespräche unterwegs lösen beim Betreten aus. Läuft man versehentlich
  während eines laufenden Gesprächs in den nächsten Auslöser, wird dieser
  übersprungen. Auf der linearen Strecke praktisch ausgeschlossen.
* Die drei Erinnerungen lassen sich beliebig oft ansprechen. Für kurze
  Fundstücke ist das richtig; sobald dort echte Sätze stehen, ist `one_shot`
  am Knoten die Stellschraube.
* Der Abschluss versetzt beide Figuren mit abgeschalteter Physik auf ihre
  Marken — sie gleiten dorthin, statt zu gehen. Ohne Animationen fällt das
  nicht auf, mit echten Figuren muss daraus ein Weg werden.

## Bekannte Fehler

Keine offenen. Die während Stage 1 gefundenen sind oben unter „Gelöste
Probleme" beschrieben.

---

## Nächste sinnvolle Schritte

Stage 1 bis 4 sind abgenommen. Stage 5 (Abschluss, Pausenmenü, Erinnerungen)
liegt zum Probespielen bereit; die echten Dialogtexte sind ausdrücklich
zurückgestellt.

### Beim Probespielen von Stage 5 und 6 zu beurteilen

* Trägt das Schlussbild? Stehen die beiden gut zueinander, ist der Abstand
  richtig, kommt der Umschnitt zu früh oder zu spät?
  Stellschrauben am Knoten `BerlinChapter`: `abschluss_vorlauf` (2,2 s bis der
  Umbau beginnt), `abschluss_fahrt` (2,0 s Kamerafahrt), `abschluss_bildwinkel`
  (50°), `abschluss_blickhoehe` (0,8 m). Die Marken für beide Figuren und die
  Kamera stehen als Marker3D unter `Abschluss`.
* Steht der Abspann lange genug? (`ui/chapter_card.tscn`: `verdunkeln_dauer`,
  `titel_dauer`, `stehen_lassen`, `auftakt_stehen`)
* Findet man die drei Erinnerungen am Weg — oder läuft man an allen vorbei?
* Ist der Auftakt (5 s Titeltafel) zu lang oder zu kurz?
* Sind die Schritte zu laut, zu schnell, zu blechern? Die Kadenz sitzt in
  `Player > Schritte > schrittlaenge` (1,5 m), die Lautstärke am Knoten selbst.
* Trägt die Stadtatmosphäre, oder fällt auf, dass nichts passiert?
* Passt die Grundmischung — Musik zu Geräuschen? (Regler in der Pause)

### Danach

**Die echten Texte.** Alle Dialoge sind Platzhalter in der beabsichtigten
Tonlage. `chapters/berlin/dialogue_lines.gd` enthält ausschließlich Inhalt —
Sätze umschreiben, ergänzen oder streichen ist gefahrlos. Die drei Erinnerungen
sind der offensichtliche Ort für Insider.

**Die Figuren.** Entschieden ist: **realistisch**, nach den Fotos vom
2026-08-17. Der Steckplatz steht und ist geprüft; es fehlen nur die beiden
Dateien, und die entstehen im Browser mit Konto — das kann diese Umgebung nicht.

Ready Player Me, ursprünglich dafür vorgesehen, wurde am 31. Januar 2026
abgeschaltet. Ersatz und Anleitung stehen in `actors/models/README.md`
(MetaPerson Creator, Avaturn, Character Creator). Der Steckplatz ist bewusst
werkzeugunabhängig: er nimmt jede `.glb`, gleich woher.

Danach: **Animationen** (Mixamo oder eine freie Mocap-Sammlung) und eine
Mischschicht, die zwischen Stehen, Gehen und Laufen über `Player.speed_ratio`
überblendet. Erst mit den Modellen zu bauen — ohne sie wären die Zustände
geraten.

Die Platzhalter tragen bereits die Farben der Vorlagen: Anne dunkles Oberteil
und blondes Haar, Oliver dunkelblauer Pullover, helles Haar, weißer Kragen.

**Kulisse und Feinschliff.** Berliner Kulisse statt Blöcke, echte Aufnahmen
statt synthetischer Klänge, Kameraübergänge, Pacing, Dialogtiming. Dazu die
gesammelten Punkte: eine Reaktion zwischen den Würfen, ein echter Weg statt des
Gleitens auf die Abschlussmarken.

Nicht begonnen und bewusst nicht vorbereitet: spätere Kapitel.

### Falls das Fahrgefühl nachjustiert werden soll

Über **F1** im laufenden Spiel, dieselben Werte stehen im Editor unter `Player`
und `ThirdPersonCamera`:

| Empfindung | Stellschraube |
| --- | --- |
| stoppt zu abrupt / zu rutschig | `Player > braking` (aktuell 26) |
| läuft zu träge an | `Player > acceleration` (18) |
| dreht zu behäbig / zu zappelig | `Player > turn_responsiveness` (14) |
| Tempo insgesamt falsch | `walk_speed` (3,4) und `sprint_speed` (6,2) |
| Kamera klebt / schwimmt | `follow_damping` (9,0) |
| Kamera zu nah / zu weit | `SpringArm3D > spring_length` (4,2) |
| Kamera dreht sich ungefragt | `auto_align_enabled` / `auto_align_rate` |

### Offen aus früheren Runden

* Stimmt der Abstand, in dem der Hinweis „Ansprechen" erscheint?
* Ist das Dialogtempo richtig — Schreibgeschwindigkeit, Zeilenlänge?
* Sitzt der Kamerawinkel im Gespräch gut? (`gespraechswinkel_grad`, 48°)
* Ist der Wurf verständlich, ohne dass es jemand erklärt? Ist die Idealzone
  breit genug, trifft man gut genug für Stolz statt Langeweile?
* Stimmt die Gehzeit von 2–3 Minuten, sitzen die Gespräche an den richtigen
  Stellen?
