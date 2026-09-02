class_name HochzeitDialogue
extends RefCounted

## Alle Dialogtexte für Kapitel 3 — die Hochzeit an der Spree.
##
## Diese Datei enthält **nur Inhalt**, keine Logik. Sätze umschreiben,
## Zeilen ergänzen oder entfernen ist gefahrlos.
##
## **Alle Texte sind Platzhalter.** Sie treffen die gewünschte Tonlage,
## damit sich Länge und Tempo beurteilen lassen — die echten Sätze von
## damals gehören genau hierher. Dieses Kapitel ist das Finale, hier
## lohnt sich das Umschreiben am meisten.

## Direkt nach der Trauung, vor dem Traubogen, die Gäste ringsum.
const AUFTAKT: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Wir haben es tatsächlich getan."},
	{"speaker": "ANNE", "text": "Du warst kurz davor zu heulen."},
	{"speaker": "OLIVER", "text": "Ich war kurz davor, mich zu freuen. Sieht ähnlich aus."},
	{"speaker": "ANNE", "text": "Sag mal, was machen die Gäste da hinten mit den Sträußen?"},
]

## Die Regeln des Spiels, von Oliver erklärt.
const REGELN: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Neue Tradition. Einen Strauß zu werfen ist langweilig."},
	{"speaker": "OLIVER", "text": "Zehn kommen. Fünf musst du fangen, dann gehört der Tag dir."},
	{"speaker": "ANNE", "text": "Der gehört mir sowieso. Aber gut. Werft."},
]

## Nach dem gewonnenen Fangen.
const GEWONNEN: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Fünf von zehn. Bei irgendwas musstest du ja mal knapp sein."},
	{"speaker": "ANNE", "text": "Ich habe geheiratet, nicht trainiert."},
	{"speaker": "OLIVER", "text": "Du hast jedes Spiel gewonnen, das ich mir ausgedacht habe."},
	{"speaker": "OLIVER", "text": "Berlin, Frankfurt, und jetzt hier. Alle drei."},
	{"speaker": "ANNE", "text": "Dann sag schon. Was war der Preis?"},
]

## Die Kapitelkarte.
const KARTE_TITEL: String = "KAPITEL 3"
const KARTE_ZEILE: String = "BERLIN — 2023"

## Das Missionsziel, während Anne zum Traubogen geht.
const ZIEL_BOGEN: String = "Zu den Gästen an den Traubogen"

## Das Truhen-Finale nach dem Sieg.
const ZIEL_TRUHE: String = "Da steht noch etwas für dich — sieh nach"
## Der Hinweis überm Zahlenpad — bewusst vage: der Code ist das
## Hochzeitsdatum (22.09.2023), aber das soll Anne selbst erraten.
## Die Trennpunkte im Pad verraten immerhin das Datumsformat.
const TRUHE_HINWEIS: String = "Eine Kombination, die uns viel bedeutet."

## --- Das Finale --------------------------------------------------------------
##
## Hier wird eingelöst, was der Widmungsbildschirm am Anfang verspricht:
## „Um dein Geschenk zu bekommen, musst du zuerst das Spiel unseres Lebens
## gewinnen."
##
## **Diese beiden Zeilen sind der wichtigste Platzhalter im ganzen Spiel.**
## Was hier steht, ist das eigentliche Geschenk — eine Reise, eine Karte,
## ein Satz, was auch immer. Bitte ersetzen, bevor Anne es spielt.
const GESCHENK_TITEL: String = "Du hast gewonnen."
const GESCHENK_ZEILEN: Array[String] = [
	"Alle drei Spiele. Alles, was danach kam.",
	"[Hier steht dein Geschenk — der Text ist noch ein Platzhalter.]",
]
const GESCHENK_FUSS: String = "Alles Liebe zum Geburtstag."

## Der Abspann des Spiels.
const ABSPANN_TITEL: String = "Our Story"
const ABSPANN_ZEILE: String = "Berlin · Frankfurt · Berlin"
