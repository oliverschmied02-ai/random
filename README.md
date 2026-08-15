# Our Story

Ein persönliches, stilisiertes 3D-Story-Spiel in Godot 4 — ein Geburtstagsgeschenk,
das wichtige Momente unserer Beziehung als spielbare Szenen nacherzählt.

## Aktueller Umfang

**Kapitel 1 — Berlin** (COVID-Zeit, Alexanderplatz-Spaziergang, Minispiel
"Vaccination Darts"). Weitere Kapitel sind konzeptionell vorgesehen, werden
aber bewusst noch nicht gebaut.

**Stand:** Stage 1 — Foundation. Spielbare Testfläche mit Third-Person-Bewegung
und Verfolgerkamera, ausschließlich Platzhalter-Geometrie.

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
| Maus freigeben | Escape | — |
| Debug-Overlay | F3 | — |

## Prüflauf ohne Editor

```bash
godot --headless --path . --script res://tools/headless_check.gd
```

Fährt die Figur mit simulierten Eingaben über Bahn, Treppe und Rampe und prüft
Geschwindigkeiten, Bremsweg, Bodenkontakt und Kameraposition.

## Projektstruktur

```
actors/player/    Spielfigur (CharacterBody3D + Controller)
camera/           Third-Person-Kamerarig
scenes/           Spielszenen (aktuell die Testfläche)
ui/               Oberfläche (aktuell das Debug-Overlay)
tools/            Entwicklungswerkzeuge (headless Prüflauf)
```

Kapitelinhalte bekommen einen eigenen Ordner, sobald Stage 2 beginnt.

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
