class_name BerlinDialogue
extends RefCounted

## Alle Dialogtexte für Kapitel 1 — Berlin.
##
## Diese Datei enthält **nur Inhalt**, keine Logik. Sätze umschreiben, Zeilen
## ergänzen oder entfernen ist gefahrlos: das Dialogsystem liest die jeweilige
## Liste einfach der Reihe nach ab.
##
## Aufbau einer Zeile:
##
##     {"speaker": "OLIVER", "text": "Hey."}
##
## `speaker` steht in der Kopfzeile der Dialogbox. `SIE` ist ein Platzhalter —
## sobald der echte Name feststeht, hier ersetzen, sonst nirgends.
##
## **Alle Texte sind Platzhalter.** Sie treffen die gewünschte Tonlage, damit
## sich Länge und Tempo beurteilen lassen, aber die echten Erinnerungen und
## Insider gehören später genau hierher.

## Vor Olivers Bürotür: das Abholen nach Feierabend.
const ABHOLEN: Array[Dictionary] = [
	{"speaker": "SIE", "text": "Hey. Feierabend?"},
	{"speaker": "OLIVER", "text": "Hey. Endlich."},
	{"speaker": "OLIVER", "text": "Ich sitze seit heute früh da drin und habe mit genau null Menschen geredet."},
	{"speaker": "SIE", "text": "Willkommen in 2020."},
	{"speaker": "OLIVER", "text": "Wollen wir ein Stück laufen?"},
	{"speaker": "SIE", "text": "Klar. Ich hab sowieso nichts vor. Keiner hat was vor."},
]

## Unterwegs, am geschlossenen Café.
const UNTERWEGS_CAFE: Array[Dictionary] = [
	{"speaker": "SIE", "text": "Da wollten wir doch eigentlich hin."},
	{"speaker": "OLIVER", "text": "Da wollten wir seit drei Wochen hin."},
	{"speaker": "SIE", "text": "Zu. Wie alles."},
	{"speaker": "OLIVER", "text": "Dafür kennen wir inzwischen jede Parkbank in Mitte mit Vornamen."},
]

## Unterwegs, am Desinfektionsspender auf dem Platz.
const UNTERWEGS_PLATZ: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Guck mal. Die Dinger standen wirklich an jeder Ecke."},
	{"speaker": "SIE", "text": "Ich hatte den ganzen Frühling Hände wie Schmirgelpapier."},
	{"speaker": "OLIVER", "text": "Zwei Meter Abstand, hieß es."},
	{"speaker": "SIE", "text": "Du läufst gerade seit zwanzig Minuten neben mir."},
	{"speaker": "OLIVER", "text": "Ich weiß."},
]

## Ankunft an der Dönerbude — vorläufiger Abschluss von Kapitel 1.
const ANKUNFT_DOENER: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Da vorne. Siehst du das?"},
	{"speaker": "SIE", "text": "Die Dönerbude?"},
	{"speaker": "OLIVER", "text": "Die Dönerbude."},
	{"speaker": "SIE", "text": "Es ist halb elf."},
	{"speaker": "OLIVER", "text": "Perfekte Uhrzeit. Und die haben hinten eine Dartscheibe."},
	{"speaker": "SIE", "text": "Das wird ja immer besser."},
]
