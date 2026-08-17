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

### Anne — Spielfigur
| | |
| --- | --- |
| **Zweck** | Die Spielfigur |
| **Szene** | `actors/player/player.tscn` → Knoten `Visual` |
| **Typ** | Rigged 3D-Charaktermodell |
| **Stil** | **Realistisch**, nach Foto (2026-08-17 übergeben) |
| **Vorlage** | Blondes, schulterlanges Haar, glatt; dunkles Oberteil; feine Kette |
| **Animation** | Rig muss zu den Animationen unten passen (Mixamo-kompatibel) |
| **Platzhalter** | Kapsel in Dunkelgrau mit blondem Scheitel, hellen Schulterbalken und Nasenmarkierung |
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

### Oliver — Begleiter
| | |
| --- | --- |
| **Zweck** | Der Begleiter |
| **Szene** | `actors/companion/companion.tscn` → Knoten `Visual` |
| **Typ** | Rigged 3D-Charaktermodell |
| **Stil** | **Realistisch**, nach Foto (2026-08-17 übergeben) |
| **Vorlage** | Kurzes hellbraunes Haar, Seitenscheitel; dunkelblauer Pullover über weißem Hemdkragen |
| **Animation** | Idle, Gehen, Zuhören/Sprechen |
| **Platzhalter** | Kapsel in Dunkelblau mit hellem Scheitel und weißem Kragenbalken |
| **Priorität** | CRITICAL |

**Steckplatz steht.** `actors/models/anne.glb` und `oliver.glb` — Datei
hinlegen genügt, die Kapseln verschwinden von selbst. Anleitung und Fehlersuche
in `actors/models/README.md`.

**Weg zu realistischen Figuren.** Aus je einem Foto lässt sich kein
fotorealistisches Modell rechnen — dafür bräuchte es entweder viele Aufnahmen
aus verschiedenen Winkeln (Photogrammetrie) oder einen Charakter-Generator, der
aus einem Frontalfoto ein Gesicht baut.

**Ready Player Me ist am 31. Januar 2026 abgeschaltet worden** (Netflix hat das
Unternehmen gekauft). Bereits erzeugte Dateien laufen weiter, neue gibt es
nicht. Was bleibt:

* **MetaPerson Creator** (Avatar SDK) — Selfie hinein, geriggte Ganzkörperfigur
  als GLB heraus, im Browser. Erste Figur frei, weitere gegen Guthaben.
* **Avaturn** — dasselbe Prinzip, ebenfalls mit GLB-Ausgabe.
* **Character Creator 4 + Headshot** — näher am Foto, kostenpflichtig.
* **MakeHuman oder Daz3D** — kostenlos, Gesicht von Hand nachbauen.

Nicht geeignet: **MetaHuman**. Die Modelle sehen am besten aus, dürfen aber
lizenzrechtlich nur in der Unreal Engine verwendet werden.

Animationen: **Mixamo** (kostenlos mit Adobe-Konto, royaltyfrei, passt auf
Standard-Rigs) — Idle, Gehen, Laufen, Zuhören, Werfen. Der Dienst wird von
Adobe nicht mehr gepflegt; als Fundament taugt er nicht, als Quelle für den
Anfang schon.

Dass ein Anbieter verschwindet, darf das Spiel nicht treffen: der Steckplatz in
`actors/models/` nimmt jede `.glb`, gleich woher.

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
| **Platzhalter** | Prozedurale Nachtfassaden aus `kulisse.gd`: Fensterraster, Gesimse, Balkone, Läden, Gehwege, brennende Laternen |
| **Priorität** | POLISH — der Platzhalter trägt inzwischen selbst |

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
| **Szene** | `chapters/berlin/berlin_chapter.tscn`, entlang der ganzen Route |
| **Typ** | Props: Desinfektionsspender, Abstandsschilder, Absperrband, Masken |
| **Stil** | Leicht überzeichnet, nostalgisch-absurd, nicht bedrückend |
| **Animation** | Keine nötig |
| **Platzhalter** | Orange Schilderplatte, geschlossene Café-Front mit Markise |
| **Priorität** | IMPORTANT |

### Erinnerungen am Weg
| | |
| --- | --- |
| **Zweck** | Drei Fundstücke, die niemand sehen muss — Beiwerk mit Insidern |
| **Szene** | `chapters/berlin/berlin_chapter.tscn` → `Erinnerungen` |
| **Typ** | Abstandsschild an der Wand, Parkbank, Fahrrad ohne Sattel |
| **Stil** | Beiläufig, kein Ausrufezeichen — man muss sie übersehen können |
| **Animation** | Keine nötig |
| **Platzhalter** | Gelbe Schilderplatte, Sitzblock, Fahrrad aus Zylindern und Stäben |
| **Priorität** | POLISH |

Die Positionen sind Vorschläge; überzeugender wären Orte, an denen ihr wirklich
wart. Verschieben heißt: Knoten unter `Erinnerungen` bewegen, sonst nichts.

### Schlussbild an der Bude
| | |
| --- | --- |
| **Zweck** | Der letzte Blick des Kapitels — die beiden im Gespräch |
| **Szene** | `chapters/berlin/berlin_chapter.tscn` → `Abschluss` |
| **Typ** | Kadrage: Marken für beide Figuren und die Kamera |
| **Stil** | Spätabendlich, warmes Budenlicht von der Seite |
| **Animation** | Später: echtes Hingehen statt Gleiten, Zuhör-Posen |
| **Platzhalter** | Zwei Marken 1,6 m auseinander, Kamera 3,6 m davor bei 50° |
| **Priorität** | POLISH |

---

## Minispiel

### Impfspritze
| | |
| --- | --- |
| **Zweck** | Das Wurfgeschoss — der Witz des Minispiels |
| **Szene** | `chapters/berlin/darts/syringe.tscn` |
| **Typ** | Cartoon-Requisit |
| **Stil** | Überzeichnet, freundlich, keinesfalls medizinisch-nüchtern |
| **Animation** | Leichtes Zittern des Kolbens im Flug wäre ein netter Zusatz |
| **Platzhalter** | Zylinder mit Serum, Nadel und Kolben aus Grundkörpern |
| **Priorität** | IMPORTANT |

### Dartscheibe an der Bude
| | |
| --- | --- |
| **Zweck** | Ziel des Minispiels |
| **Szene** | `chapters/berlin/darts/darts_game.tscn` → `Scheibe` |
| **Typ** | Scheibe mit Holzrückwand und Lampe |
| **Stil** | Abgenutzt, Kneipenecke, warm beleuchtet |
| **Animation** | Keine nötig |
| **Platzhalter** | Sechs Ringe aus Zylindern auf einem Holzbrett |
| **Priorität** | POLISH |

Die Ringradien in `darts_config.gd` und die Ringe in der Szene müssen
zusammenpassen — wer die Optik ändert, ändert die Wertung mit.

---

## Ton

### Minispiel-Klänge
| | |
| --- | --- |
| **Zweck** | Der Einschlag muss sich befriedigend anfühlen |
| **Szene** | `chapters/berlin/darts/` |
| **Typ** | Einschlag, Aufladen, Volltreffer, Erfolgsmusik |
| **Stil** | Trocken, satt, mit einem Augenzwinkern |
| **Animation** | — |
| **Platzhalter** | Synthetisch aus `tools/make_placeholder_audio.py` |
| **Priorität** | IMPORTANT |

### Footstep Sounds
| | |
| --- | --- |
| **Zweck** | Schritte tragen das Gewicht der Bewegung |
| **Szene** | `actors/player/player.tscn` |
| **Typ** | Sound-Set (Asphalt, Pflaster) |
| **Stil** | Trocken, nah, leicht stilisiert |
| **Animation** | An Schrittzeitpunkte der Lauf-Animation koppeln — bis dahin zählt `Schritte` den Weg |
| **Platzhalter** | Vier synthetische Tritte aus `tools/make_placeholder_audio.py` |
| **Priorität** | IMPORTANT |

### Stadtatmosphäre und Musik
| | |
| --- | --- |
| **Zweck** | Der Ort soll klingen, nicht nur aussehen |
| **Szene** | `chapters/berlin/berlin_chapter.tscn` → `Klang`, `ui/title_screen.tscn` |
| **Typ** | Stadtschleife (fern, ereignislos), Brummen des Leuchtschilds, Titelmusik |
| **Stil** | Leer und spätabendlich; die Musik warm, langsam, ohne Pathos |
| **Animation** | — |
| **Platzhalter** | Synthetisch: Rauschteppich, Netzbrummen, vier Akkorde aus Sinustönen |
| **Priorität** | IMPORTANT |

Die Platzhalter sind austauschbar, ohne Code anzufassen: gleicher Dateiname
unter `audio/`, fertig. Schleifen (`stadt`, `bude_summen`, `laden`,
`titelmusik`) brauchen in der `.import`-Datei `edit/loop_mode=2` — die Werte
des Importeurs sind *0 = aus WAV lesen, 1 = aus, 2 = vorwärts*.

---

## Nicht in dieser Liste

Die Testfläche `scenes/test_playground.tscn` ist ein Entwicklungswerkzeug zum
Beurteilen des Fahrgefühls, kein Spielinhalt. Sie wird verworfen, sobald die
echten Berlin-Szenen stehen, und braucht deshalb keine Asset-Ersetzung.
