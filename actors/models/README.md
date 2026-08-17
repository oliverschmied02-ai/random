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

## Mit Ready Player Me erzeugen

1. [readyplayer.me](https://readyplayer.me) öffnen, *Create Avatar*.
2. **Full Body** wählen — nicht Half Body. Half-Body-Avatare haben keine Beine
   und sind für VR gedacht.
3. Foto hochladen oder eine Grundfigur wählen und Gesicht, Haare und Kleidung
   anpassen. Für Anne: blondes, schulterlanges Haar, dunkles Oberteil. Für
   Oliver: kurzes hellbraunes Haar, dunkelblauer Pullover über weißem Hemd.
4. Fertigstellen. Am Ende gibt es eine Adresse der Form
   `https://models.readyplayer.me/<id>.glb` — das ist die Modelldatei.
5. Herunterladen und als `anne.glb` bzw. `oliver.glb` hier ablegen.

Nützliche Zusätze an der Adresse, falls die Datei zu groß oder zu grob ist:

```
https://models.readyplayer.me/<id>.glb?quality=high&textureSizeLimit=1024
```

## Was das Modell mitbringen muss

* **Ganzkörper** mit Skelett (Ready Player Me liefert ein Mixamo-kompatibles
  Rig — genau das brauchen die Animationen später)
* **Y nach oben**, Blick nach +Z. Godot schaut nach −Z; die Figur dreht das
  Modell selbst um 180°. Läuft es rückwärts, ist `blickrichtung_drehen` am
  Knoten `Visual` der Schalter.
* Keine Animationen nötig — die kommen getrennt von Mixamo.

## Wenn etwas nicht stimmt

| Beobachtung | Stellschraube |
| --- | --- |
| Figur zu groß oder zu klein | `Visual > zielhoehe` |
| Figur läuft rückwärts | `Visual > blickrichtung_drehen` |
| Figur steht im Boden oder schwebt | Modell muss auf y = 0 stehen, sonst `Visual` verschieben |
| Kapsel bleibt sichtbar | Dateiname prüfen, Godot einmal starten lassen (Import) |
