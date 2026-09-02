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
| **Typ** | Animationen (Idle, Walk, Übergänge) |
| **Stil** | Natürlich |
| **Animation** | Mocap blendet Stehen/Gehen über das gemessene Tempo |
| **Platzhalter** | **Erledigt durch echte CMU-Motion-Capture** (`assets/mocap/`): Gehen 07_01, Stehen 40_10. Gangwerk als Rückfallebene. |
| **Priorität** | ~~CRITICAL~~ abgedeckt — offen bleiben nur Zusatzclips (Gesten, Drehungen) |

Andockpunkte sind vorhanden: `Player.speed_ratio`, `Player.current_speed`
und die Signale `started_moving` / `stopped_moving`. Neue Clips:
BVH von der CMU-Datenbank laden und `tools/bvh_konverter.py` aufrufen.

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

### Tinder-Intro (Hand, Handy, Profilbilder)
| | |
| --- | --- |
| **Zweck** | Die Vorgeschichte: Anne swipet, Oliver taucht auf, Match |
| **Szene** | `chapters/intro/tinder_intro.tscn` |
| **Typ** | Hand-mit-Handy-Modell, App-Oberfläche, Profilfotos |
| **Stil** | Nahaufnahme, abends, warmes Bokeh; die App bewusst generisch („zünder") |
| **Animation** | Daumen wischt mit, Hand atmet; Karten fliegen/federn |
| **Platzhalter** | `assets/intro/hand_handy.glb` — echtes WebXR-Handmodell (MIT, `assets/intro/quelle/`) in Griffpose gebogen (`tools/make_hand_echt.py`; Rückfallebene: Skin-Modifier-Hand aus `make_intro_props.py`), Scherz-Profile als Silhouetten-Porträts, Olivers drei Fotos aus dem 3D-Modell gerendert (`tools/_foto_oliver.gd` + `make_tinder_fotos.py veredeln`) |
| **Priorität** | POLISH — trägt; echte Fotos der beiden würden die Match-Avatare ersetzen |

### Straßenzug Berlin-Mitte
| | |
| --- | --- |
| **Zweck** | Wiedererkennbares Berlin statt grauer Blöcke |
| **Szene** | `chapters/berlin/berlin_chapter.tscn` |
| **Typ** | Modulare Gebäude, Bodenmaterialien, Straßenmöbel |
| **Stil** | Stilisiert, warme Farben, starke Silhouetten |
| **Animation** | Dezente Bewegung: Fahnen, Blätter, ferne Bahnen |
| **Platzhalter** | Prozedurale Nachtkulisse aus `kulisse.gd`: Fassaden mit Putzkörnung (Rauschtexturen, triplanar), Fenster/Türen/Gesimse als Blender-Module mit gebackener AO (`tools/make_fassade.py`, Vorhänge und Scheiben dahinter), Dächer mit Schornsteinen und Antennen, nasser Asphalt mit Pfützen, Tram-Oberleitung, geparkte Autos, Ampeln, Mülleimer, Gullys, Plakate, Mond und Sterne, flackernde Laterne |
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
| **Platzhalter** | Offener Verkaufsraum (Rückwand, Seiten, Dach), Tresen, drehender Schichten-Spieß vor glühendem Heizelement, Verkäufer (Olivers Modell mit Schürze und Papiermütze), Lichterkette |
| **Priorität** | IMPORTANT |

Die Fallzone des Minispiels (fallende FFP2-Masken) liegt an der Seitenwand
dieser Bude — beim Entwurf freie Wandfläche daneben einplanen.

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

## Kapitel 2 — Frankfurt

### Umzugs-LKW
| | |
| --- | --- |
| **Zweck** | Trägt die Abschieds- und die Autobahn-Sequenz |
| **Szene** | `chapters/frankfurt/frankfurt_chapter.tscn` → Kulisse |
| **Typ** | 7,5-Tonner mit Kofferaufbau |
| **Stil** | Leicht stilisiert, Mietwagen-Look |
| **Animation** | Fährt (Kapitelskript schiebt ihn); Räder drehen wäre Feinschliff |
| **Platzhalter** | `assets/props/lkw.glb` aus `tools/make_ffm_props.py`: rote Kabine, weißer Koffer mit orangen Streifen, sechs Räder |
| **Priorität** | POLISH — trägt |

### Bembel (Apfelweinkrug)
| | |
| --- | --- |
| **Zweck** | Die Wurfziele des Minispiels und Deko in der Kneipe |
| **Szene** | `chapters/frankfurt/krug_spiel.gd` (Türme), Kulisse (Deko) |
| **Typ** | Steinzeugkrug mit Henkel, grau mit blauem Dekor |
| **Stil** | Erkennbar hessisch, leicht überzeichnet |
| **Animation** | Starre Körper — kippen und fallen echt |
| **Platzhalter** | `assets/props/bembel.glb` aus `tools/make_ffm_props.py` mit gebackener Sprenkel-und-Ringe-Textur |
| **Priorität** | POLISH — trägt |

### Sachsenhausen und Kneipenstube
| | |
| --- | --- |
| **Zweck** | Ankunftsort und Schauplatz des Krug-Werfens |
| **Szene** | `chapters/frankfurt/kulisse_ffm.gd` (prozedural) |
| **Typ** | Fachwerkzeile, Putzhäuser, Kneipenfront, holzvertäfelte Stube |
| **Stil** | Tageslicht, warm; die Bankentürme im Dunst dahinter |
| **Animation** | Keine nötig |
| **Platzhalter** | Foto-PBR (ambientCG: Kopfstein, Platten, Putz, Asphalt) + Fassaden-Kit-Fenster + Fachwerkbalken als Geometrie + Satteldächer; Stube mit Tresen, Tischen, Bänken, Bembel-Regal |
| **Priorität** | POLISH — trägt |

### Straßenmöbel der Gasse
| | |
| --- | --- |
| **Zweck** | Aus dem Durchgang einen Ort machen |
| **Szene** | `chapters/frankfurt/kulisse_ffm.gd` |
| **Typ** | Bistrotische, Stühle, Blumenkästen, Fahrräder, Auslegerschild |
| **Stil** | Hessische Wirtshausgasse, benutzt statt aufgeräumt |
| **Animation** | Keine nötig |
| **Platzhalter** | Blender-Requisiten aus `tools/make_ffm_props.py` |
| **Priorität** | POLISH — trägt |

### Passanten
| | |
| --- | --- |
| **Zweck** | Die Gasse soll bewohnt wirken |
| **Szene** | `chapters/frankfurt/passant.gd`, gesetzt in der Kulisse |
| **Typ** | Vier Menschen am Rand der Gasse |
| **Stil** | Beiläufig, aus Spielentfernung — nie in einer Nahaufnahme |
| **Animation** | Mocap „auf den Bus warten" (Gewicht verlagern, umschauen) |
| **Platzhalter** | **Umgefärbte Kopien von Anne und Oliver** — anderes Haar, andere Kleidung, andere Körpergröße |
| **Priorität** | IMPORTANT — hier fehlen echte eigene Modelle |

Es gibt keine freie, in dieser Umgebung erreichbare Quelle für geriggte
Menschmodelle in dieser Qualität: Mixamo und die Avatar-Generatoren
brauchen einen Browser mit Konto, die CC0-Sammlungen (Quaternius, Kenney)
liegen auf Anbieter-CDNs, die hier gesperrt sind. Erreichbar wäre
**CesiumMan** aus `KhronosGroup/glTF-Sample-Assets` (geriggt, mit
Laufzyklus) — ein grob aufgelöster Klotzmensch, der neben den echten
Modellen von Anne und Oliver auffälliger wäre als eine umgefärbte Kopie.
Wer echte Statisten will: dieselben Anbieter wie für Anne und Oliver
(MetaPerson, Avaturn) — je Figur eine `.glb` nach `actors/models/`, dann
in `_passanten_setzen` den Pfad tauschen.

### Inventar der Kneipenstube
| | |
| --- | --- |
| **Zweck** | Aus dem Raum mit Möbeln eine Wirtsstube machen |
| **Szene** | `chapters/frankfurt/kulisse_ffm.gd` → `_kneipe_bauen` |
| **Typ** | Geripptes, Schanktresen, Pendellampe, Bilderrahmen, Wurfball |
| **Stil** | Hessische Apfelweinwirtschaft, benutzt und warm |
| **Animation** | Keine nötig |
| **Platzhalter** | Blender-Requisiten aus `tools/make_ffm_props.py`; Wandbilder als gebackene Sepia-Motive (PIL) |
| **Priorität** | POLISH — trägt |

Das **Geripptes** ist das wiedererkennbarste Detail des Kapitels: die
Rippen sind Geometrie, keine Textur. Wer es austauscht, sollte das
beibehalten — eine Rippentextur verschwindet aus zwei Metern Entfernung.

### Der Wirt
| | |
| --- | --- |
| **Zweck** | Hinter dem Tresen soll jemand stehen |
| **Szene** | `chapters/frankfurt/wirt.gd` |
| **Typ** | Wirt mit Schürze und Handtuch |
| **Stil** | Beiläufig, im Halbdunkel hinter dem Tresen |
| **Animation** | Mocap-Ruhehaltung; sieht auf, wenn jemand nah ist |
| **Platzhalter** | Olivers Modell, dunkler getöntes Haar, blaue Schürze, Handtuch am Schulterknochen |
| **Priorität** | IMPORTANT — wie bei den Passanten fehlt ein eigenes Modell |

### Kapitel-2-Klänge
| | |
| --- | --- |
| **Zweck** | Motor auf der Autobahn, Stubenmurmeln, Klirren der Krüge |
| **Szene** | `chapters/frankfurt/frankfurt_chapter.tscn` → `Klang` |
| **Typ** | Motorschleife, Kneipenschleife, Klirr-Einschlag |
| **Stil** | Unaufdringlich; das Klirren satt, aber nicht scherbig |
| **Animation** | — |
| **Platzhalter** | Synthetisch aus `tools/make_placeholder_audio.py` (`motor`, `kneipe`, `klirren`) |
| **Priorität** | IMPORTANT |

**Offen und nur von Oliver zu beantworten: das Umzugsjahr.** Die
Kapitelkarte zeigt derzeit „FRANKFURT — 2021" als Platzhalter
(`KARTE_ZEILE` in `chapters/frankfurt/dialogue_lines_ffm.gd`).

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
| **Platzhalter** | Erkennbare Spritze aus Grundkörpern: durchsichtiger Glaszylinder, oranges Serum, Gummistopfen, Fingerflansch, Kolbenstange, Kanüle mit Ansatz |
| **Priorität** | IMPORTANT |

### FFP2-Masken (Ziele des Minispiels)
| | |
| --- | --- |
| **Zweck** | Zehn fallende Ziele — fünf Treffer gewinnen |
| **Szene** | `chapters/berlin/darts/darts_game.tscn` (gespawnt zur Laufzeit) |
| **Typ** | FFP2-Maske mit Bootsfalte, Nasenbügel, Ohrschlaufen |
| **Stil** | Weißes Vlies, dezenter Aufdruck, trudelt wie Papier |
| **Animation** | Fallen, seitlich pendeln, trudeln (im Spielcode) |
| **Platzhalter** | `assets/props/atemmaske.glb` aus `tools/make_maske.py` — Gitter mit Wölbungsprofil, PIL-Vlies-Textur (Fasern, Faltlinie, Nähte, „FFP2 NR") |
| **Priorität** | POLISH — trägt |

Trefferzone (`MASKEN_RADIUS`) und sichtbare Größe (Skalierung in
`maske_setzen`) gehören zusammen — wer die Optik ändert, prüft die Wertung.

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
`titelmusik`, `wellen_moewen`, `zug_rumpeln`) brauchen in der
`.import`-Datei `edit/loop_mode=2` — die Werte des Importeurs sind
*0 = aus WAV lesen, 1 = aus, 2 = vorwärts*.

### Kenney-Klänge (CC0) — GELIEFERT
| | |
| --- | --- |
| **Zweck** | Echte Aufnahmen statt Synthese für UI, Karten, Sieg, Truhe |
| **Szene** | `audio/kenney/` — Zuordnung in `audio/kenney/HERKUNFT.txt` |
| **Typ** | Kartenwischen, Tippen, Menüklick, Match-/Sieg-Jingle, Zahlenpad, Schloss, Deckelknarren, Schweben, Krug-Klirren |
| **Stil** | Kenney Asset Pack, CC0 — keine Attributionspflicht |
| **Platzhalter** | Keiner mehr; `sieg_fanfare.ogg` ist eine Montage aus zwei aufsteigenden Sax-Jingles (`tools`-frei, per numpy/soundfile gebaut) |
| **Priorität** | GELIEFERT |

### Ambience-Synthese — GELIEFERT
| | |
| --- | --- |
| **Zweck** | Spree-Wellen mit Möwen (Hochzeit), Zugrumpeln + Bremszischen (Zugszene) |
| **Szene** | `chapters/hochzeit/chapter_hochzeit.gd` (`wellen_moewen`), `chapters/frankfurt/chapter_frankfurt.gd` → `_zug_sequenz` |
| **Typ** | `audio/wellen_moewen.wav` (24-s-Loop), `audio/zug_rumpeln.wav` (8-s-Loop), `audio/brems_zisch.wav` (One-Shot) |
| **Stil** | FFT-gefiltert und darum an der Loop-Naht mathematisch nahtlos; Möwenrufe als FM-Synthese |
| **Platzhalter** | `tools/make_ambience.py` — echte Feldaufnahmen wären noch schöner, gleiche Dateinamen genügen |
| **Priorität** | POLISH |

---

## Kapitel 3 — Hochzeit

### Die Gäste-Avatare — GELIEFERT
| | |
| --- | --- |
| **Zweck** | Zwölf Menschen auf der Hochzeit |
| **Szene** | `chapters/hochzeit/kulisse_hochzeit.gd` → `_gaeste_setzen` |
| **Stand** | Acht Mixamo-Charaktere (`actors/models/gast_1`–`gast_8.glb`), von Oliver als FBX über das GitHub-Release „Avatare" geliefert |
| **Pipeline** | FBX 6100 → FBX2glTF → `tools/mixamo_gast.py` (Knochen umbenennen, Transparenz reparieren) → `tools/gast_verschlanken.py` (Decimate 0.35, Diffuse 256, Normal/Glanz raus) — aus 440 MB FBX wurden 8,7 MB GLB |
| **Grenze** | Mocap/Gangwerk sind auf das RPM-Rig geeicht und für die Gäste abgeschaltet — sie stehen still. Bewegung bräuchte ein Retargeting auf das Mixamo-Skelett. |
| **Priorität** | erledigt; NICE wäre Leben (Klatschen, Kopfdrehen) via Retargeting |

**Weitere Gäste einsetzen:** FBX in ein GitHub-Release hängen, dann die
Pipeline oben durchlaufen lassen und in `_gaeste_setzen` den
`modell_pfad` des Platzes tauschen. Größe regelt `zielhoehe`.

### Brautstrauß, Weide, Traubogen, Stuhl, Stehtisch, Lichterkette
| | |
| --- | --- |
| **Zweck** | Das Inventar der Hochzeit |
| **Szene** | `chapters/hochzeit/` |
| **Typ** | Blender-Requisiten |
| **Stil** | Sommerlich, creme und blassrosa, nichts Knalliges |
| **Animation** | Der Strauß dreht sich im Flug |
| **Platzhalter** | `tools/make_hochzeit_props.py` |
| **Priorität** | POLISH — trägt |

### Der Geschenktext
| | |
| --- | --- |
| **Zweck** | Das Ende des Versprechens aus der Widmung |
| **Szene** | `chapters/hochzeit/dialogue_lines_hochzeit.gd` |
| **Typ** | Zwei Zeilen Text |
| **Stil** | Deine Worte, nicht meine |
| **Animation** | — |
| **Platzhalter** | „[Hier steht dein Geschenk — der Text ist noch ein Platzhalter.]" |
| **Priorität** | **CRITICAL** — ohne ihn endet das Spiel mit einer leeren Zusage |

---

## Nicht in dieser Liste

Die Testfläche `scenes/test_playground.tscn` ist ein Entwicklungswerkzeug zum
Beurteilen des Fahrgefühls, kein Spielinhalt. Sie wird verworfen, sobald die
echten Berlin-Szenen stehen, und braucht deshalb keine Asset-Ersetzung.
