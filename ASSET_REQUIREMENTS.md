# Asset Requirements

Verzeichnis der Assets, die später echte Inhalte statt Platzhalter brauchen.

**Prioritäten**
* `CRITICAL` — das Kapitel funktioniert oder wirkt ohne dieses Asset nicht
* `IMPORTANT` — deutlich spürbarer Qualitätsgewinn
* `POLISH` — Feinschliff

Nur Assets, die der aktuelle Stand tatsächlich verwendet oder für Stage 1
benötigt. Assets für spätere Stages werden erst eingetragen, wenn die Stage
begonnen wird.

---

## Spielerfigur

### Wife Character Model
| | |
| --- | --- |
| **Zweck** | Die Spielfigur — stilisierte Version meiner Frau |
| **Szene** | `actors/player/player.tscn` → Knoten `Visual` |
| **Typ** | Rigged 3D-Charaktermodell |
| **Stil** | Stilisiert, klare Silhouette, warme Farben, keine Fotorealistik |
| **Animation** | Rig muss zu den Animationen unten passen |
| **Platzhalter** | Kapsel mit Schulterbalken und Nasenmarkierung für die Blickrichtung |
| **Priorität** | CRITICAL |

Austausch: den Inhalt von `Visual` ersetzen. Die Kollisionskapsel (Radius 0,35 m,
Höhe 1,75 m) und der Controller bleiben unberührt — Modellhöhe darauf abstimmen
oder die Kapsel einmalig anpassen.

### Wife Animation Set
| | |
| --- | --- |
| **Zweck** | Bewegung soll gehen statt gleiten |
| **Szene** | `actors/player/player.tscn` |
| **Typ** | Animationen (Idle, Walk, Run, Übergänge, Drehung im Stand) |
| **Stil** | Ausdrucksstark, leicht überzeichnet, freundlich |
| **Animation** | Blend zwischen Idle/Walk/Run über `Player.speed_ratio` (0…1) |
| **Platzhalter** | Keiner — die Kapsel gleitet |
| **Priorität** | CRITICAL |

Andockpunkte sind vorhanden: `Player.speed_ratio`, `Player.current_speed`
und die Signale `started_moving` / `stopped_moving`.

### Oliver Character Model
| | |
| --- | --- |
| **Zweck** | Der Begleiter — stilisierte Version von mir |
| **Szene** | `actors/companion/companion.tscn` → Knoten `Visual` |
| **Typ** | Rigged 3D-Charaktermodell |
| **Stil** | Wie die Spielfigur, klar davon unterscheidbare Silhouette |
| **Animation** | Idle, Gehen, Zuhören/Sprechen |
| **Platzhalter** | Blaue Kapsel mit Schulterbalken und Nasenmarkierung |
| **Priorität** | CRITICAL |

Der Companion liefert `speed_ratio`, `current_speed` und `state` — dieselben
Andockpunkte wie die Spielfigur.

---

## Umgebung

### Alexanderplatz-Kulisse
| | |
| --- | --- |
| **Zweck** | Wiedererkennbares Berlin statt grauer Blöcke |
| **Szene** | `chapters/berlin/berlin_start.tscn` |
| **Typ** | Modulare Gebäude, Bodenmaterialien, Straßenmöbel |
| **Stil** | Stilisiert, warme Farben, starke Silhouetten |
| **Animation** | Dezente Bewegung: Fahnen, Blätter, ferne Bahnen |
| **Platzhalter** | CSG-Blöcke, Laternen aus Zylinder und Box |
| **Priorität** | IMPORTANT |

Die Komposition (Achse zum Fernsehturm, querende Gleise) sollte beim Austausch
erhalten bleiben — sie trägt die Führung zu Oliver.

### COVID-Requisiten
| | |
| --- | --- |
| **Zweck** | Die Zeit sofort lesbar machen |
| **Szene** | `chapters/berlin/berlin_start.tscn` und die Route in Stage 3 |
| **Typ** | Props: Desinfektionsspender, Abstandsschilder, Absperrband, Masken |
| **Stil** | Leicht überzeichnet, nostalgisch-absurd, nicht bedrückend |
| **Animation** | Keine nötig |
| **Platzhalter** | Orange Schilderplatte, geschlossene Café-Front mit Markise |
| **Priorität** | IMPORTANT |

---

## Ton

### Footstep Sounds
| | |
| --- | --- |
| **Zweck** | Schritte tragen das Gewicht der Bewegung |
| **Szene** | `actors/player/player.tscn` |
| **Typ** | Sound-Set (Asphalt, Pflaster) |
| **Stil** | Trocken, nah, leicht stilisiert |
| **Animation** | An Schrittzeitpunkte der Lauf-Animation koppeln |
| **Platzhalter** | Keiner — es gibt bisher keinen Ton |
| **Priorität** | IMPORTANT |

---

## Nicht in dieser Liste

Die Testfläche `scenes/test_playground.tscn` ist ein Entwicklungswerkzeug zum
Beurteilen des Fahrgefühls, kein Spielinhalt. Sie wird verworfen, sobald die
echten Berlin-Szenen stehen, und braucht deshalb keine Asset-Ersetzung.
