class_name FrankfurtDialogue
extends RefCounted

## Alle Dialogtexte für Kapitel 2 — Frankfurt.
##
## Diese Datei enthält **nur Inhalt**, keine Logik. Sätze umschreiben,
## Zeilen ergänzen oder entfernen ist gefahrlos.
##
## **Alle Texte sind Platzhalter.** Sie treffen die gewünschte Tonlage,
## damit sich Länge und Tempo beurteilen lassen — die echten Sätze von
## damals gehören genau hierher.

## Der Abschied vor der Berliner Wohnung, der LKW ist beladen.
const ABSCHIED: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Das ist dann wohl alles."},
	{"speaker": "ANNE", "text": "Du hast den Wasserkocher vergessen. Absichtlich?"},
	{"speaker": "OLIVER", "text": "Der bleibt hier. Dann habe ich einen Grund wiederzukommen."},
	{"speaker": "ANNE", "text": "Du brauchst keinen Grund."},
	{"speaker": "OLIVER", "text": "Frankfurt ist nur vier Stunden. Ich rufe an, sobald ich da bin."},
	{"speaker": "ANNE", "text": "Fahr vorsichtig. Und schreib mir bei jeder Raststätte."},
]

## Das Telefonat über die Freisprechanlage, mitten auf der A5.
const ANRUF: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Wo bist du?"},
	{"speaker": "OLIVER", "text": "Kurz hinter der Raststätte mit dem furchtbaren Kaffee."},
	{"speaker": "ANNE", "text": "Das hilft mir nicht. Das sind alle."},
]

## Anne kommt in Frankfurt an, Oliver wartet schon.
const ANKUNFT: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Da bist du ja."},
	{"speaker": "ANNE", "text": "Da bin ich ja. Zeig mir dein Frankfurt."},
	{"speaker": "OLIVER", "text": "Es ist noch nicht meins. Aber ich kenne schon eine Kneipe."},
	{"speaker": "ANNE", "text": "Natürlich kennst du schon eine Kneipe."},
]

## An der Kneipentür.
const KNEIPE_TUER: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Hier gibt es Apfelwein. Und hinten kann man Krüge abwerfen."},
	{"speaker": "ANNE", "text": "Erst das Spiel, dann das Getränk. Ich kenne dich."},
]

## Nach dem gewonnenen Krug-Werfen.
const GEWONNEN: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Alle Türme. Schon wieder."},
	{"speaker": "ANNE", "text": "Du solltest aufhören, gegen mich zu wetten."},
	{"speaker": "OLIVER", "text": "Nie. Das ist inzwischen Tradition."},
	{"speaker": "ANNE", "text": "Dann verlierst du eben traditionell."},
]

## --- Erinnerungen am Weg -----------------------------------------------------
##
## Drei Fundstücke in der Gasse, die niemand sehen muss. Wie in Kapitel 1
## halten sie den Weg nicht an, sie warten darauf, angesprochen zu werden.
## Hier gehören Insider hin — Orte, an denen ihr wirklich wart.

## Das Umzugsrad, das mit nach Frankfurt kam.
const ERINNERUNG_FAHRRAD: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Dein Rad hat den Umzug überlebt."},
	{"speaker": "OLIVER", "text": "Das Rad überlebt alles. Nur der Sattel nicht."},
]

## Der Bembel im Kneipenfenster.
const ERINNERUNG_BEMBEL: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Der Krug im Fenster ist größer als unser erster Küchentisch."},
	{"speaker": "OLIVER", "text": "Der Krug war auch teurer."},
]

## Die Tische auf dem Gehweg.
const ERINNERUNG_TISCHE: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Zwei Stühle. Immer genau zwei."},
	{"speaker": "OLIVER", "text": "Mehr haben wir bis jetzt nie gebraucht."},
]

## Die Kapitelkarte. Das Jahr ist ein Platzhalter — bitte korrigieren,
## falls der Umzug in einem anderen Jahr war.
const KARTE_TITEL: String = "KAPITEL 2"
const KARTE_ZEILE: String = "FRANKFURT — 2021"

## Der Level-Übergang nach dem Sieg.
const LEVEL_TITEL: String = "Glückwunsch."
const LEVEL_ZEILE: String = "Du hast es ins dritte Level geschafft."

## Zwischentitel der Sequenzen.
const TITEL_AUTOBAHN: String = "A5 — RICHTUNG SÜDEN"
const TITEL_ANKUNFT: String = "FRANKFURT AM MAIN"

## Das Missionsziel während des Laufs zur Kneipe.
const ZIEL_KNEIPE: String = "Zeig mir dein Frankfurt — zur Apfelweinkneipe"
