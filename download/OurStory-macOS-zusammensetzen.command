#!/bin/bash
# Setzt die Teilstücke OurStory-macOS.zip.001, .002, … wieder zu einer
# Zip-Datei zusammen. Doppelklicken (bei der Gatekeeper-Nachfrage:
# Rechtsklick -> Öffnen) oder im Terminal ausführen.
cd "$(dirname "$0")"
if ls OurStory-macOS.zip.0* > /dev/null 2>&1; then
    cat OurStory-macOS.zip.0* > OurStory-macOS.zip
    echo "Fertig: OurStory-macOS.zip — jetzt entpacken und 'Our Story.app' starten."
else
    echo "Keine Teilstücke (OurStory-macOS.zip.0*) in diesem Ordner gefunden."
fi
