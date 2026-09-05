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
## **Echte Zeilen von Oliver**, behutsam verfeinert — die letzten Monate
## waren schwer, und genau das darf man hier hören.
const ABSCHIED: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Jetzt ist es also wirklich so weit. Du gehst."},
	{"speaker": "OLIVER", "text": "Ja. Und es fällt mir schwerer, als ich zugeben wollte."},
	{"speaker": "ANNE", "text": "Ich hoffe, wir schaffen das."},
	{"speaker": "OLIVER", "text": "Ich glaube fest daran. Auch wenn es ein ganz neues Kapitel für uns ist."},
	{"speaker": "ANNE", "text": "Die letzten Monate waren nicht einfach. Für mich nicht."},
	{"speaker": "OLIVER", "text": "Für mich auch nicht. Aber ich will weiter an uns arbeiten. Jeden Tag."},
	{"speaker": "ANNE", "text": "Ich hoffe, du kannst das. Ich will dich nämlich nicht verlieren."},
	{"speaker": "OLIVER", "text": "Du verlierst mich nicht. Nicht wegen ein paar hundert Kilometern."},
	{"speaker": "OLIVER", "text": "Ich muss jetzt los. Es ist so schwer — aber ich melde mich bei der ersten Pause."},
	{"speaker": "ANNE", "text": "Fahr bitte vorsichtig."},
	{"speaker": "OLIVER", "text": "Versprochen."},
]

## Das Telefonat über die Freisprechanlage, kurz vor Frankfurt —
## **echte Zeilen von Oliver**, behutsam verfeinert.
const ANRUF: Array[Dictionary] = [
	{"speaker": "ANNE", "text": "Wo bist du?"},
	{"speaker": "OLIVER", "text": "Kurz vor Frankfurt. Ich musste die ganze Fahrt die Tränen zurückhalten."},
	{"speaker": "ANNE", "text": "Ich auch. Ich hoffe, du bist dir sicher mit deiner Entscheidung."},
	{"speaker": "OLIVER", "text": "Ich hoffe es auch. Aber ich muss es versuchen — ich war in Berlin einfach nicht mehr glücklich."},
	{"speaker": "ANNE", "text": "Fahr bitte weiter vorsichtig. Und melde dich, sobald du da bist."},
	{"speaker": "OLIVER", "text": "Mach ich. Versprochen."},
]

## Auf dem Bahnsteig: Annes erster Besuch, Oliver wartet schon.
const ANKUNFT: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Da bist du ja."},
	{"speaker": "ANNE", "text": "Da bin ich ja. Vier Stunden. Der Zug war schneller als dein LKW."},
	{"speaker": "OLIVER", "text": "Der LKW hatte auch unser ganzes Leben geladen."},
	{"speaker": "ANNE", "text": "Na dann. Zeig mir dein Frankfurt."},
	{"speaker": "OLIVER", "text": "Es ist noch nicht meins. Aber ich kenne schon eine Kneipe."},
	{"speaker": "ANNE", "text": "Natürlich kennst du schon eine Kneipe."},
]

## Angekommen in Sachsenhausen, kurz vor dem gemeinsamen Lauf.
const STADT: Array[Dictionary] = [
	{"speaker": "OLIVER", "text": "Sachsenhausen. Hier wohne ich jetzt."},
	{"speaker": "ANNE", "text": "Gar nicht so übel für den Anfang."},
	{"speaker": "OLIVER", "text": "Warte, bis du den Apfelwein probiert hast."},
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
const TITEL_WOCHEN: String = "EINIGE WOCHEN SPÄTER — ANNES ERSTER BESUCH"
const TITEL_ANKUNFT: String = "SACHSENHAUSEN — AM ANDEREN MAINUFER"

## Das Missionsziel während des Laufs zur Kneipe.
const ZIEL_KNEIPE: String = "Zeig mir dein Frankfurt — zur Apfelweinkneipe"
