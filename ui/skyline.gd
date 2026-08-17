extends Control

## Gezeichnete Dachlinie für den Titelbildschirm.
##
## Als `_draw()` und nicht als Bild: die Silhouette besteht aus zwei Dutzend
## Rechtecken und einem Kreis, das ist als Code kürzer als jede Bilddatei und
## passt sich jeder Fenstergröße an. Der Fernsehturm steht rechts der Mitte,
## damit die Schrift links Platz hat.
##
## Die Häuser sind fest verdrahtet, nicht zufällig: eine Silhouette, die bei
## jedem Start anders aussieht, wirkt beliebig statt wie ein Ort.

## Dachhöhen als Anteil der Steuerelementhöhe, von links nach rechts.
const HAEUSER: Array[float] = [
	0.42, 0.55, 0.34, 0.62, 0.48, 0.30, 0.58, 0.44,
	0.66, 0.38, 0.52, 0.28, 0.60, 0.46, 0.36, 0.50,
]
## Wo der Turm steht, als Anteil der Breite.
const TURM_X: float = 0.72

@export var farbe: Color = Color(0.129, 0.141, 0.192, 1.0)
@export var turm_farbe: Color = Color(0.161, 0.176, 0.235, 1.0)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var breite := size.x
	var hoehe := size.y
	var teilung := breite / float(HAEUSER.size())

	for i in HAEUSER.size():
		var dach := hoehe * (1.0 - HAEUSER[i])
		# Ein Hauch Überlappung, sonst blitzt zwischen zwei Häusern der Himmel
		# durch, wenn die Breite nicht glatt aufgeht.
		draw_rect(Rect2(i * teilung - 1.0, dach, teilung + 2.0, hoehe - dach), farbe)
		_fenster(i * teilung, dach, teilung, hoehe)

	_fernsehturm(breite * TURM_X, hoehe)


## Ein paar erleuchtete Fenster. Feste Muster pro Haus, damit sie beim
## Neuzeichnen nicht flackern.
func _fenster(links: float, dach: float, spalte: float, hoehe: float) -> void:
	var licht := Color(0.98, 0.86, 0.62, 0.5)
	var breite := spalte * 0.13
	var zeilen := int((hoehe - dach) / (hoehe * 0.09))
	for zeile in zeilen:
		for spaltenzahl in 3:
			if (zeile * 7 + spaltenzahl * 3 + int(links)) % 5 != 0:
				continue
			var x := links + spalte * (0.18 + 0.3 * spaltenzahl)
			var y := dach + hoehe * 0.05 + zeile * hoehe * 0.09
			draw_rect(Rect2(x, y, breite, hoehe * 0.035), licht)


func _fernsehturm(x: float, hoehe: float) -> void:
	var schaft := hoehe * 0.11
	var spitze := hoehe * 0.02
	draw_rect(Rect2(x - schaft * 0.13, hoehe * 0.30, schaft * 0.26, hoehe * 0.70), turm_farbe)
	draw_circle(Vector2(x, hoehe * 0.34), hoehe * 0.075, turm_farbe)
	draw_rect(Rect2(x - spitze * 0.12, hoehe * 0.12, spitze * 0.24, hoehe * 0.19), turm_farbe)
