# Figurenmodelle

Hierher gehören die beiden Personenmodelle. Sobald sie hier liegen, tauchen sie
im Spiel auf — es ist keine Code- oder Szenenänderung nötig, die Kapseln
verschwinden von selbst.

| Datei | Figur | Höhe im Spiel |
| --- | --- | --- |
| `anne.glb` | Spielfigur (`actors/player/player.tscn` → `Visual`) | 1,72 m |
| `oliver.glb` | Begleiter (`actors/companion/companion.tscn` → `Visual`) | 1,82 m |

Die Dateinamen müssen genau so lauten. Die Größe der Datei ist egal: das Modell
wird gemessen und auf die Höhe in der Tabelle skaliert (`Figur.zielhoehe`).

**Das Werkzeug ist austauschbar.** Der Steckplatz nimmt jede `.glb` oder
`.gltf`, egal woher. Welcher Dienst sie erzeugt hat, ist dem Spiel gleichgültig
— das ist Absicht, nachdem der zuerst vorgesehene Anbieter dichtgemacht hat.

## Womit erzeugen?

**Ready Player Me fällt weg.** Der Dienst wurde am 31. Januar 2026 abgeschaltet,
nachdem Netflix das Unternehmen gekauft hatte. Bereits heruntergeladene
`.glb`-Dateien funktionieren weiter — neue lassen sich nicht mehr erzeugen.

Was stattdessen geht, alles im Browser, Foto hinein, Modell heraus:

| Dienst | Anmerkung |
| --- | --- |
| **MetaPerson Creator** (Avatar SDK) | Selfie hochladen, fertig geriggte Ganzkörperfigur, Export als GLB/glTF/FBX. Die erste Figur ist frei, weitere kosten Guthaben. Der direkte Nachfolger von Ready Player Me. |
| **Avaturn** | Ebenfalls Foto zu realistischer Figur mit GLB-Ausgabe. |
| **Character Creator 4 + Headshot** | Programm zum Installieren, kostenpflichtig, am nächsten am Foto. |
| **MakeHuman** oder **Daz3D** | Kostenlos, Gesicht von Hand nachbauen statt aus dem Foto rechnen. |

Nicht geeignet: **MetaHuman**. Die Modelle sehen am besten aus, dürfen aber
lizenzrechtlich nur in der Unreal Engine verwendet werden.

## Was das Modell mitbringen muss

* **Ganzkörper** mit Skelett. Halbkörper-Figuren („Half Body") haben keine Beine
  und sind für VR gedacht.
* Ein **Mixamo-kompatibles Rig**, falls die Animationen später von dort kommen
  sollen. Die meisten der oben genannten Dienste liefern genau das.
* **Y nach oben**, Blick nach +Z. Godot schaut nach −Z; die Figur dreht das
  Modell selbst um 180°. Läuft es rückwärts, ist `blickrichtung_drehen` am
  Knoten `Visual` der Schalter.
* Keine Animationen nötig — die kommen getrennt.

## Wenn etwas nicht stimmt

| Beobachtung | Stellschraube |
| --- | --- |
| Figur zu groß oder zu klein | `Visual > zielhoehe` |
| Figur läuft rückwärts | `Visual > blickrichtung_drehen` |
| Figur steht im Boden oder schwebt | Modell muss auf y = 0 stehen, sonst `Visual` verschieben |
| Kapsel bleibt sichtbar | Dateiname prüfen, Godot einmal starten lassen (Import) |

## Animationen

Geplant ist **Mixamo** (kostenlos mit Adobe-Konto, royaltyfrei). Achtung: der
Dienst wird von Adobe nicht mehr gepflegt und hatte 2025 längere Ausfälle — er
funktioniert, taugt aber nicht als Fundament. Wenn er ausfällt, kommen die
Bewegungen aus einer der freien Mocap-Sammlungen; das Rig entscheidet, nicht
der Anbieter.
