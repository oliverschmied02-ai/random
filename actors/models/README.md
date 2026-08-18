# Figurenmodelle

Hierher gehören die beiden Personenmodelle. Sobald sie hier liegen, tauchen sie
im Spiel auf — es ist keine Code- oder Szenenänderung nötig, die Kapseln
verschwinden von selbst.

| Datei | Figur | Höhe im Spiel | Stand |
| --- | --- | --- | --- |
| `anne.glb` | Spielfigur (`actors/player/player.tscn` → `Visual`) | 1,72 m | **da** — 73 Knochen, 1,74 m |
| `oliver.glb` | Begleiter (`actors/companion/companion.tscn` → `Visual`) | 1,82 m | **da** — 90 273 Dreiecke, 73 Knochen, 1,81 m |

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

## Größe

Ein Modell wiegt schwer: Olivers Datei bringt 15 MB mit, im fertigen Spiel
werden daraus rund 18 MB. Zwei Vorkehrungen dagegen:

* **Texturen auf 512 Pixel** begrenzt (`process/size_limit` in den
  `.import`-Dateien der ausgepackten Bilder). Aus vier Metern Entfernung — und
  weiter kommt die Kamera nie heran — ist von 1024 nichts zu sehen; es spart
  rund 10 MB.
* **Notfalls das Netz halbieren.** `npx gltfpack -i modell.glb -o klein.glb
  -noq -si 0.5` macht aus 90 000 Dreiecken 45 000, und selbst in einer
  Gesichts-Nahaufnahme ist der Unterschied nicht zu erkennen. Das `-noq` ist
  Pflicht: Godot 4.5 kann `KHR_mesh_quantization` **nicht** lesen und weigert
  sich, eine so gepackte Datei zu importieren.

Trotzdem bleibt die fertige App mit echten Figuren über 30 MB und passt damit
nicht mehr durch den Chat — sie muss über das Repository kommen.

## Wenn etwas nicht stimmt

| Beobachtung | Stellschraube |
| --- | --- |
| Figur zu groß oder zu klein | `Visual > zielhoehe` |
| Figur läuft rückwärts | `Visual > blickrichtung_drehen` |
| Figur steht im Boden oder schwebt | Modell muss auf y = 0 stehen, sonst `Visual` verschieben |
| Kapsel bleibt sichtbar | Dateiname prüfen, Godot einmal starten lassen (Import) |

## Animationen

**Bis echte Animationen da sind, bewegt ein prozedurales Gangwerk die Figur**
(`systems/figur/gangwerk.gd`): Schritte im Takt des zurückgelegten Wegs mit
Hüft- und Schulterrotation, wanderndem Gewicht und abrollenden Füßen; Arme
gegenläufig mit nachlaufendem Unterarm; entspannte Hände; ein Kopf, der Ziele
ansieht (`Figur.schaue_an`), zur Sprechzeile nickt (`Figur.betone`) und im
Stand beiläufig umherschaut. Es braucht nur die Mixamo-Knochennamen — fehlt
einer, bleibt die Figur starr und eine Warnung sagt welcher.

Für echte Bewegungen ist **Mixamo** geplant (kostenlos mit Adobe-Konto,
royaltyfrei). Zwei Dinge dazu:

* Mixamo liefert **FBX**; Godot 4.5 liest das direkt (eingebauter
  ufbx-Importeur). Die Datei kommt als eigene Animationsdatei hierher — der
  Avatar selbst bleibt die `.glb`.
* Wichtig: FBX oder GLB macht nichts animiert. Ob sich etwas bewegt, hängt
  davon ab, ob Animationsspuren **in der Datei stecken** — Avatar-Generatoren
  exportieren in beiden Formaten dieselbe starre T-Pose. Die Bewegung wählt
  man bei Mixamo aus, und erst dessen Download enthält sie.
* Der Dienst wird von Adobe nicht mehr gepflegt und hatte 2025 längere
  Ausfälle. Wenn er wegbricht, kommen die Bewegungen aus einer freien
  Mocap-Sammlung; das Rig entscheidet, nicht der Anbieter.
