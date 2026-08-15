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
