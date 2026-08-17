class_name BerlinDialogue
extends RefCounted

## Alle Dialogtexte für Kapitel 1 — Berlin.
##
## Diese Datei enthält **nur Inhalt**, keine Logik. Sätze umschreiben, Zeilen
## ergänzen oder entfernen ist gefahrlos: das Dialogsystem liest die Liste
## einfach der Reihe nach ab.
##
## Aufbau einer Zeile:
##
##     {"speaker": "OLIVER", "text": "Hey."}
##
## `speaker` steht in der Kopfzeile der Dialogbox. `SIE` ist ein Platzhalter —
## sobald der echte Name feststeht, hier ersetzen, sonst nirgends.
##
## Die Texte sind bewusst noch Platzhalter. Echte Erinnerungen und Insider
## kommen später an genau diese Stelle.

## Das erste Treffen am Alexanderplatz.
const MEETING: Array[Dictionary] = [
	{"speaker": "SIE", "text": "Hey."},
	{"speaker": "OLIVER", "text": "Hey."},
	{"speaker": "OLIVER", "text": "Verrückt, wie leer hier alles ist."},
	{"speaker": "SIE", "text": "Als hätte jemand die Stadt auf Pause gestellt."},
	{"speaker": "OLIVER", "text": "Wollen wir ein Stück laufen?"},
	{"speaker": "SIE", "text": "Klar."},
]
