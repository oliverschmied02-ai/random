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
## `speaker` steht in der Kopfzeile der Dialogbox.
##
## **Alle Texte sind Platzhalter.** Sie treffen die gewünschte Tonlage, damit
## sich Länge und Tempo beurteilen lassen, aber die echten Erinnerungen und
## Insider gehören später genau hierher.

## Vor Olivers Bürotür: das Abholen nach Feierabend.
const ABHOLEN: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Hey. Feierabend?"},
	{"speaker": "OLIVER", "text": "Hey. Endlich."},
	{"speaker": "OLIVER", "text": "Ich sitze seit heute früh da drin und habe mit genau null Menschen geredet."},
	{"speaker": "ANNE", "text": "Willkommen in 2020."},
	{"speaker": "OLIVER", "text": "Wollen wir ein Stück laufen?"},
	{"speaker": "ANNE", "text": "Klar. Ich hab sowieso nichts vor. Keiner hat was vor."},
]

## Unterwegs, am geschlossenen Café.
const UNTERWEGS_CAFE: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Da wollten wir doch eigentlich hin."},
	{"speaker": "OLIVER", "text": "Da wollten wir seit drei Wochen hin."},
	{"speaker": "ANNE", "text": "Zu. Wie alles."},
	{"speaker": "OLIVER", "text": "Dafür kennen wir inzwischen jede Parkbank in Mitte mit Vornamen."},
]

## Unterwegs, am Desinfektionsspender auf dem Platz.
const UNTERWEGS_PLATZ: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Guck mal. Die Dinger standen wirklich an jeder Ecke."},
	{"speaker": "ANNE", "text": "Ich hatte den ganzen Frühling Hände wie Schmirgelpapier."},
	{"speaker": "OLIVER", "text": "Zwei Meter Abstand, hieß es."},
	{"speaker": "ANNE", "text": "Du läufst gerade seit zwanzig Minuten neben mir."},
	{"speaker": "OLIVER", "text": "Ich weiß."},
]

## Ankunft an der Dönerbude — vorläufiger Abschluss von Kapitel 1.
const ANKUNFT_DOENER: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Da vorne. Siehst du das?"},
	{"speaker": "ANNE", "text": "Die Dönerbude?"},
	{"speaker": "OLIVER", "text": "Die Dönerbude."},
	{"speaker": "ANNE", "text": "Es ist halb elf."},
	{"speaker": "OLIVER", "text": "Perfekte Uhrzeit. Und die haben hinten eine Dartscheibe."},
	{"speaker": "ANNE", "text": "Das wird ja immer besser."},
]

## Abschluss nach dem gewonnenen Minispiel. Hier stehen später die echten Sätze.
const ABSCHLUSS: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Fünf von fünf. Das war Anfängerglück."},
	{"speaker": "ANNE", "text": "Das war Können."},
	{"speaker": "OLIVER", "text": "Das war Anfängerglück, das aussah wie Können."},
	{"speaker": "ANNE", "text": "Es ist kurz vor Mitternacht und wir stehen an einer Dönerbude."},
	{"speaker": "OLIVER", "text": "Ich weiß."},
	{"speaker": "ANNE", "text": "Ich auch."},
]


# --- Optionale Erinnerungen am Weg ----------------------------------------
#
# Kurze Fundstücke, die niemand sehen muss. Genau hierhin gehören später eure
# Insider — je knapper, desto besser.

const ERINNERUNG_SCHILD: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Anderthalb Meter. Das Schild hing damals an jeder zweiten Wand."},
]

const ERINNERUNG_FAHRRAD: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Ein Fahrrad ohne Sattel, angeschlossen mit zwei Schlössern."},
	{"speaker": "ANNE", "text": "Berlin."},
]

const ERINNERUNG_BANK: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Auf so einer haben wir mal zwei Stunden gesessen."},
	{"speaker": "ANNE", "text": "Es war viel zu kalt dafür."},
]


# --- Tinder-Intro (vor Kapitel 1) ------------------------------------------
#
# Die Profile, die Anne wegwischt, bevor Oliver auftaucht. `abwink` sagt sie,
# wenn man versehentlich doch nach rechts wischt — die Karte federt zurück.
# Namen, Alter und Sprüche sind Platzhalter mit der richtigen Tonlage.

const INTRO_PROFILE: Array[Dictionary] = [
	{
		"name": "Kevin", "alter": 29,
		"bild": "res://assets/intro/profil_kevin.png",
		"bio": "Der Fisch ist nicht immer dabei. Meistens schon.",
		"abwink": "Nee. Nicht schon wieder ein Fisch.",
	},
	{
		"name": "Marcel", "alter": 31,
		"bild": "res://assets/intro/profil_marcel.png",
		"bio": "Frag mich nach meinem Auto.",
		"abwink": "Ich will nichts über sein Auto wissen.",
	},
	{
		"name": "Justin", "alter": 26,
		"bild": "res://assets/intro/profil_justin.png",
		"bio": "Erst das Gym. Dann das Gym.",
		"abwink": "Ich habe nicht mal sein Gesicht gesehen.",
	},
]

## Olivers Profil — kommt als vierte Karte. Echte Fotos: einmal Selfie mit
## Sonnenbrille, einmal von hinten im Gegenlicht am Strand — auf jedem sieht
## er anders aus, und genau darüber denkt Anne dann laut nach.
const INTRO_OLIVER: Dictionary = {
	"name": "Oliver", "alter": 28,
	"bilder": [
		"res://assets/intro/oliver_foto_1.png",
		"res://assets/intro/oliver_foto_2.png",
	],
	"bio": "Sucht jemanden für Spaziergänge, solange alles andere zu hat.",
	"abwink": "Hm. Vielleicht doch noch mal gucken.",
}

## Annes Gedanken, sobald Olivers Karte liegt — Zeile für Zeile, per Klick.
const INTRO_GEDANKEN: Array[String] = [
	"Oh. Der könnte was sein.",
	"Aber er sieht auf jedem Bild anders aus…",
	"Na ja. Bei der Auswahl hier hab ich ja nichts zu verlieren.",
]


# --- Widmung (allererster Bildschirm) ---------------------------------------

const WIDMUNG_TITEL: String = "Für Anne."
const WIDMUNG_ZEILE: String = "Um dein Geschenk zu bekommen, musst du zuerst das Spiel unseres Lebens gewinnen."


# --- Level-Übergang nach dem gewonnenen Minispiel ---------------------------

const LEVEL_TITEL: String = "Glückwunsch."
const LEVEL_ZEILE: String = "Du hast es ins zweite Level geschafft."
