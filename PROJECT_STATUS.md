# Project Status

**Spiel:** Our Story — Kapitel 1: Berlin
**Engine:** Godot 4.5 (GDScript)
**Aktuelle Stufe:** Stage 1 — Foundation (implementiert, wartet auf Fahrgefühl-Test)

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

## Bekannte Fehler

Keine offenen. Die während Stage 1 gefundenen sind oben unter „Gelöste
Probleme" beschrieben.

---

## Nächste sinnvolle Schritte

**Zuerst: Probespielen.** Stage 1 gilt erst als fertig, wenn sich das Laufen
gut anfühlt. Am schnellsten geht das über **F1** im laufenden Spiel; dieselben
Werte stehen im Editor unter den Knoten `Player` und `ThirdPersonCamera`.
Erfahrungsgemäß zuerst zu prüfen:

| Empfindung | Stellschraube |
| --- | --- |
| stoppt zu abrupt / zu rutschig | `Player > braking` (aktuell 26) |
| läuft zu träge an | `Player > acceleration` (18) |
| dreht zu behäbig / zu zappelig | `Player > turn_responsiveness` (14) |
| Tempo insgesamt falsch | `walk_speed` (3,4) und `sprint_speed` (6,2) |
| Kamera klebt / schwimmt | `follow_damping` (9,0) |
| Kamera zu nah / zu weit | `SpringArm3D > spring_length` (4,2) |
| Kamera dreht sich ungefragt | `auto_align_enabled` / `auto_align_rate` |

Danach, wenn ausdrücklich beauftragt: **Stage 2 — Meeting Oliver**
(Platzhalterfiguren, Startbereich, Näherungs-Trigger, Dialog,
Companion-Aktivierung).

Nicht begonnen und bewusst nicht vorbereitet: Alexanderplatz, Dialogsystem,
Dart-Minispiel, spätere Kapitel.
