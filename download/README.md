# Fertige App

Das Spiel für den Mac liegt hier **in Teilstücken**: GitHub erlaubt höchstens
100 MiB pro Datei, die App ist inzwischen größer. Der Zusammenbau ist ein
Handgriff.

**Herunterladen und zusammensetzen:**

1. Alle Dateien `OurStory-macOS.zip.001`, `.002`, … herunterladen (jeweils
   anklicken, dann *Download* — das Symbol mit dem Pfeil nach unten), dazu
   `OurStory-macOS-zusammensetzen.command`. Alles in denselben Ordner legen.
2. `OurStory-macOS-zusammensetzen.command` per **Rechtsklick → Öffnen**
   starten (Doppelklick blockt macOS bei heruntergeladenen Skripten).
   Alternativ im Terminal: `cat OurStory-macOS.zip.0* > OurStory-macOS.zip`
3. `OurStory-macOS.zip` entpacken, `Our Story.app` doppelklicken.

Beim ersten Start meldet macOS einen unbekannten Entwickler — die App ist
ad-hoc signiert, aber nicht von Apple beglaubigt. Freigabe über
*Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen*.

## Warum liegt eine gebaute App im Repository?

Seit die echten Figurenmodelle dabei sind, ist die App größer als 30 MB und
passt nicht mehr durch den Chat. Deshalb der Umweg über das Repository — und
seit Musik und volle Texturauflösung dabei sind, eben in Teilstücken.

Das hat einen Preis: jede neue Fassung legt ihre volle Größe in der
Git-Historie ab, auch wenn die alte überschrieben wird. Wenn das Repository
dadurch unangenehm schwer wird, gehören die Builds auf einen eigenen Zweig,
der bei jedem Mal neu geschrieben wird — dann bleibt nur die jeweils letzte
Fassung übrig.

## Selbst bauen

```bash
godot --headless --path . --export-release "macOS" "build/Our Story.zip"
```

Braucht die Export-Vorlagen der passenden Godot-Version; Einzelheiten in der
`README.md` im Hauptverzeichnis.
