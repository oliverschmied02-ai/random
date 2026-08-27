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
## **Treffen, True Crime, Dönerbude und die Tinder-Sprüche sind Olivers
## echte Texte.** Der Rest (UNTERWEGS_PLATZ, ABSCHLUSS, Erinnerungen) ist
## noch Platzhalter in der richtigen Tonlage.

## Das erste Treffen am Alexanderplatz — Olivers echter Text.
const ABHOLEN: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Oh, du siehst ja in echt viel besser aus als auf den Fotos."},
	{"speaker": "OLIVER", "text": "Na, das ist ja mal ein Kompliment."},
	{"speaker": "ANNE", "text": "Ja, du sahst auf jedem Foto auf Zünder anders aus."},
	{"speaker": "OLIVER", "text": "Ich bin einfach ein sehr variabler Typ... Wirst du schon noch sehen."},
	{"speaker": "ANNE", "text": "Na, da bin ich mal gespannt."},
	{"speaker": "OLIVER", "text": "Wollen wir spazieren gehen?"},
	{"speaker": "ANNE", "text": "Ja, ich habe aber nicht viel Zeit. Ich muss später noch nach Leipzig fahren und brauche auch noch ein Ladegerät für mein Handy. Deshalb müssen wir noch zu Tedi."},
	{"speaker": "OLIVER", "text": "Das klingt doch nach einem super Date. Dann gehen wir mal los, oder?"},
	{"speaker": "ANNE", "text": "Ja."},
]

## Unterwegs, erster Halt — True Crime, Olivers echter Text.
const UNTERWEGS_CAFE: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Ich bin ein großer True-Crime-Podcast-Fan."},
	{"speaker": "OLIVER", "text": "Und was waren die krassesten Kriminalfälle, die du in letzter Zeit gehört hast?"},
	{"speaker": "ANNE", "text": "Es gab diesen einen Fall nach einem Tinder-Date, bei dem jemand in eine Wohnung gekommen ist, in der alles mit Plastik ausgelegt war. Dann ist die Frau schnell wieder verschwunden, weil sie Angst hatte, dass sie umgebracht wird."},
	{"speaker": "OLIVER", "text": "Aha. Willst du mir damit irgendetwas sagen?"},
	{"speaker": "ANNE", "text": "Nein, ich habe keine Angst. Ich habe immer ein Messer neben meinem Bett im Schlafzimmer."},
	{"speaker": "OLIVER", "text": "Das lässt mich in der ersten Nacht neben dir sicher beruhigt schlafen."},
	{"speaker": "ANNE", "text": "Schauen wir mal, ob du es so weit schaffst."},
]

## Unterwegs, am Desinfektionsspender auf dem Platz.
const UNTERWEGS_PLATZ: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Guck mal. Die Dinger standen wirklich an jeder Ecke."},
	{"speaker": "ANNE", "text": "Ich hatte den ganzen Frühling Hände wie Schmirgelpapier."},
	{"speaker": "OLIVER", "text": "Zwei Meter Abstand, hieß es."},
	{"speaker": "ANNE", "text": "Du läufst gerade seit zwanzig Minuten neben mir."},
	{"speaker": "OLIVER", "text": "Ich weiß."},
]

## Ankunft an der Dönerbude — Olivers echter Text. Die letzte Zeile
## kündigt das Minispiel an, das direkt danach startet.
const ANKUNFT_DOENER: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Was hältst du denn von Döner?"},
	{"speaker": "ANNE", "text": "Etwas Hunger hätte ich schon."},
	{"speaker": "OLIVER", "text": "Na dann lass uns doch zur Dönerbude gehen. Ist eh das Einzige, was auf hat."},
	{"speaker": "ANNE", "text": "Ein super Dinner für ein erstes Date."},
	{"speaker": "OLIVER", "text": "Ich nehme einmal Döner mit allem und extra Zwiebeln und Knoblauch."},
	{"speaker": "ANNE", "text": "Den ersten Kuss gibt's damit aber nicht."},
	{"speaker": "OLIVER", "text": "Das war auch die Absicht der Bestellung."},
	{"speaker": "ANNE", "text": "Haha, als ob... Dann lass uns doch danach Spritzenwerfen auf FFP2-Masken spielen. Das Spiel ist direkt hinter der Dönerbude."},
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

## Vier echte Fotos, vier Sprüche von Oliver — die Reihenfolge ist sein
## Drehbuch. Die Namen sind erfunden; die Sprüche tragen den Witz.
const INTRO_PROFILE: Array[Dictionary] = [
	{
		"name": "Cosimo", "alter": 34,
		"bild": "res://assets/intro/profil_checker.png",
		"bio": "Ey, hier ist der Checker vom Neckar, alles klar bei dir?",
		"abwink": "Bei mir ja. Beim Checker checke ich aus.",
	},
	{
		"name": "Karl", "alter": 32,
		"bild": "res://assets/intro/profil_gym.png",
		"bio": "Erst das Gym, dann das Business, dann die Frau",
		"abwink": "Ich bin also Punkt drei auf der Liste. Nein.",
	},
	{
		"name": "Maurice", "alter": 30,
		"bild": "res://assets/intro/profil_maurice.png",
		"bio": "Der Löwe gefällt jeder Schwiegermama",
		"abwink": "Meine Mama hätte da Fragen.",
	},
	{
		"name": "Calvin", "alter": 27,
		"bild": "res://assets/intro/profil_kappe.png",
		"bio": "Hey du, ich bin zwar kein Zahnarzt, aber ich kann dir trotzdem eine Füllung verpassen.",
		"abwink": "Autsch. Einfach: autsch.",
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
	"bio": "Suche jemanden für lange Spaziergänge mit ausreichend Abstand",
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
