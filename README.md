# Our Story

Ein persönliches, stilisiertes 3D-Story-Spiel in Godot 4 — ein Geburtstagsgeschenk,
das wichtige Momente unserer Beziehung als spielbare Szenen nacherzählt.

## Aktueller Umfang

**Kapitel 1 — Berlin** (COVID-Zeit, Alexanderplatz-Spaziergang, Minispiel
"Vaccination Darts"). Weitere Kapitel sind konzeptionell vorgesehen, werden
aber bewusst noch nicht gebaut.

**Stand:** Stage 6 — Kapitel 1 ist von Anfang bis Ende erzählt, mit Titel und Ton. Oliver vor
seiner Bürotür abholen, zu zweit durch die Stadt laufen (zwei Gespräche
unterwegs, dazu drei optionale Erinnerungen am Weg), an der Dönerbude ankommen,
dort *Vaccination Darts* spielen — und danach ein Schlussbild, in dem die
beiden miteinander reden, gefolgt vom Abspann.
Ausschließlich Platzhalter-Geometrie, alle Dialoge sind Platzhaltertexte, aller
Ton ist synthetisch erzeugt.

## Starten

Godot 4.5 wird benötigt.

```bash
godot --path .        # oder das Projekt im Editor öffnen und F5 drücken
```

| Eingabe | Tastatur / Maus | Gamepad |
| --- | --- | --- |
| Gehen | WASD | linker Stick |
| Kamera | Maus | rechter Stick |
| Sprinten | Shift | rechter Trigger |
| Ansehen / Ansprechen | E | A |
| Werfen (Minispiel) | linke Maustaste | A |
| Pause und Lautstärke | Escape | Select |
| Einstellmenü | F1 | — |
| Debug-Overlay | F3 | — |

## Einstellmenü

**F1** öffnet im laufenden Spiel ein Menü mit Schiebereglern für Tempo,
Beschleunigung, Bremskraft, Drehung und Kamera. Änderungen wirken sofort.
*Werte kopieren* legt die aktuellen Einstellungen als Text in die
Zwischenablage. Damit lässt sich das Fahrgefühl ohne Godot-Editor abstimmen.

Die Regler ändern nur die laufende Sitzung — dauerhaft werden Werte, indem sie
in `actors/player/player.gd` bzw. `camera/third_person_camera.gd` als neue
Standardwerte eingetragen werden.

## Fertige Version bauen

```bash
godot --headless --path . --export-release "macOS" "build/Our Story.zip"
```

Erfordert die Export-Vorlagen der passenden Godot-Version. Der Build ist
ad-hoc signiert, aber nicht von Apple beglaubigt — beim ersten Start meldet
macOS deshalb einen unbekannten Entwickler; Freigabe über
*Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen*.

**Stolperfalle beim arm64-Export:** Godots offizielle `macos.zip`-Vorlage
enthält nur ein Universal-Binary (`godot_macos_release.universal`). Die
Voreinstellung `binary_format/architecture="arm64"` bricht deshalb mit
*„Requested template binary godot_macos_release.arm64 not found"* ab. Zwei
Wege: entweder auf `"universal"` stellen (Ergebnis rund doppelt so groß, läuft
auch auf Intel-Macs), oder den arm64-Teil aus dem Universal-Binary
herausschneiden und als `godot_macos_release.arm64` in die Vorlage packen.

## Prüflauf ohne Editor

```bash
godot --headless --path . --script res://tools/headless_check.gd
godot --headless --path . --script res://tools/headless_darts_check.gd
godot --headless --path . --script res://tools/headless_chapter_check.gd
godot --headless --path . --script res://tools/headless_ending_check.gd
godot --headless --path . --script res://tools/headless_rahmen_check.gd
```

Der erste fährt die Figur über Bahn, Treppe und Rampe und prüft
Geschwindigkeiten, Bremsweg, Bodenkontakt und Kameraposition.

Der zweite wirft mit fest vorgegebenen Ziel- und Kraftwerten auf die
Dartscheibe und prüft Wertung, Rundenende, Wiederholung und die Zusicherung,
dass die Wurfkraft nur die Höhe des Treffers verändert.

Der dritte spielt **das ganze Kapitel** mit simulierter Eingabe durch: zur
Bürotür laufen, Oliver ansprechen, die Strecke ablaufen, alle vier Gespräche
mitnehmen, an der Dönerbude ankommen. Er misst dabei die Gehzeit und wie gut
Oliver mithält. Weil er die Strecke wirklich abläuft, dauert er ungefähr so
lange wie das Kapitel selbst — rund vier Minuten.

Der vierte nimmt sich die beiden Enden vor: er spricht jede Erinnerung am Weg
an und prüft, dass sie redet und die Steuerung zurückgibt, gewinnt danach eine
Runde und misst das Schlussbild nach — beide auf ihren Marken, einander
zugewandt, ganz im Bild.

Der fünfte nimmt den Rahmen: Audiobusse, Lautstärkeregler, Titelbildschirm,
Kapitelauftakt und die Schrittkadenz beim Gehen.

## Ton

Alle Klänge sind synthetische Platzhalter und entstehen hier:

```bash
python3 tools/make_placeholder_audio.py
```

Kein Fremdmaterial, keine Abhängigkeiten. Ersetzen heißt: Datei gleichen Namens
nach `audio/` legen. Schleifen brauchen in der zugehörigen `.import`-Datei
`edit/loop_mode=2`.

## Projektstruktur

```
actors/player/     Spielfigur (CharacterBody3D + Controller)
actors/companion/  Begleitfigur
camera/            Third-Person-Kamerarig
systems/           Wiederverwendbare Systeme (Interaktion, Dialog, Bewegung)
chapters/berlin/   Kapitel 1: Szene, Ablauf, Dialogtexte
audio/             Klänge und Musik (synthetische Platzhalter)
scenes/            Testfläche zum Beurteilen der Bewegung
ui/                Titelbildschirm und Oberfläche (Ziel, Dialog, Pause, Kapitelkarte, Debug)
tools/             Entwicklungswerkzeuge (headless Prüfläufe)
```

Dialogtexte stehen in `chapters/berlin/dialogue_lines.gd` — reiner Inhalt,
ohne Logik, gefahrlos zu ändern.

## Dokumentation

| Datei | Inhalt |
| --- | --- |
| `PROJECT_STATUS.md` | Stand, gelöste Probleme, Grenzen, nächste Schritte, Stellschrauben zum Tunen |
| `ASSET_REQUIREMENTS.md` | Assets mit Zweck, Stil, Platzhalter und Priorität |
| `OUR_STORY_SYSTEM_PROMPT.md` | Vollständiger Projekt-Brief: Vision, Story, Systeme, Entwicklungsstufen |

## Historie

Dieses Repository enthielt zuvor ein unabhängiges Projekt (ZVG Intelligence
Platform). Dessen Inhalt wurde entfernt; er bleibt über die Git-History und den
Branch `claude/connect-repository-lSKFT` erreichbar.
