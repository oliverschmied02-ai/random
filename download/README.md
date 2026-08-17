# Fertige App

`OurStory-macOS.zip` — Kapitel 1, gebaut für Mac mit Apple Silicon.

**Herunterladen:** auf die Datei oben klicken, dann auf *Download* (das Symbol
mit dem Pfeil nach unten). Entpacken, `Our Story.app` doppelklicken.

Beim ersten Start meldet macOS einen unbekannten Entwickler — die App ist
ad-hoc signiert, aber nicht von Apple beglaubigt. Freigabe über
*Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen*.

## Warum liegt eine gebaute App im Repository?

Seit die echten Figurenmodelle dabei sind, ist die App größer als 30 MB und
passt nicht mehr durch den Chat. Deshalb der Umweg über das Repository.

Das hat einen Preis: jede neue Fassung legt rund 47 MB in der Git-Historie ab,
auch wenn die alte überschrieben wird. Wenn das Repository dadurch unangenehm
schwer wird, gehören die Builds auf einen eigenen Zweig, der bei jedem Mal neu
geschrieben wird — dann bleibt nur die jeweils letzte Fassung übrig.

## Selbst bauen

```bash
godot --headless --path . --export-release "macOS" "build/Our Story.zip"
```

Braucht die Export-Vorlagen der passenden Godot-Version; Einzelheiten in der
`README.md` im Hauptverzeichnis.
