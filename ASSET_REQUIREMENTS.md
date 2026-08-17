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

### Straßenzug Berlin-Mitte
| | |
| --- | --- |
| **Zweck** | Wiedererkennbares Berlin statt grauer Blöcke |
| **Szene** | `chapters/berlin/berlin_chapter.tscn` |
| **Typ** | Modulare Gebäude, Bodenmaterialien, Straßenmöbel |
| **Stil** | Stilisiert, warme Farben, starke Silhouetten |
| **Animation** | Dezente Bewegung: Fahnen, Blätter, ferne Bahnen |
| **Platzhalter** | CSG-Blöcke, Laternen aus Zylinder und Box |
| **Priorität** | IMPORTANT |

Fünf Abschnitte mit vier Ecken. Beim Austausch erhalten bleiben sollten: die
Fahrbahnbreite von 24 m (schmalere Straßen liegen komplett im Schatten und
wirken bedrückend statt nostalgisch), die Blickachsen nach Norden mit dem
Fernsehturm, und dass die Häuserblöcke gleichzeitig die Begrenzung sind.

### Bürohaus mit Eingang
| | |
| --- | --- |
| **Zweck** | Oliver *wartet* dort — an einer Tür, nicht auf freier Fläche |
| **Szene** | `chapters/berlin/berlin_chapter.tscn` → `OfficeEntrance` |
| **Typ** | Fassade mit Eingangsnische, Tür, Vordach, Klingelschild |
| **Stil** | Berliner Altbau oder nüchternes Bürohaus, warm beleuchtet |
| **Animation** | Keine nötig; später evtl. Oliver an die Wand gelehnt |
| **Platzhalter** | Nische aus Blöcken, dunkle Türplatte, orangefarbenes Vordach |
| **Priorität** | IMPORTANT |

Die Nische gibt der Gesprächskamera zugleich einen Hintergrund statt leerer
Fläche — beim Austausch bitte erhalten.

### Dönerbude
| | |
| --- | --- |
| **Zweck** | Ziel des Spaziergangs und Schauplatz des Dart-Minispiels |
| **Szene** | `chapters/berlin/berlin_chapter.tscn` → `Doenerbude` |
| **Typ** | Kiosk mit Tresen, Leuchtschild, Dönerspieß, Stehtischen |
| **Stil** | Warm, leicht überzeichnet, spätabendlich leuchtend |
| **Animation** | Drehender Spieß, flackerndes Leuchtschild |
| **Platzhalter** | Roter Block mit Vordach, Tresenbrett, gelbes Schild |
| **Priorität** | IMPORTANT |

Die Dartscheibe für Stage 4 gehört an diese Bude — beim Entwurf Platz dafür
einplanen (Seitenwand oder überdachter Bereich daneben).

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
