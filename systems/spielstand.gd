extends Node

## Der Spielstand — was schon geschafft ist, über Neustarts hinweg.
##
## Bislang kannte das Spiel nur den einen Weg von der Widmung bis zum
## Geschenk; wer das Fenster schloss, fing von vorn an. Jetzt merkt es
## sich nach jedem gewonnenen Minispiel die höchste erreichte Stufe in
## `user://spielstand.cfg`, und der Titelbildschirm bietet die schon
## erreichten Kapitel direkt an.
##
## Die Stufen:
##   0 — nichts geschafft (nur „Anfangen")
##   1 — Berlin gewonnen  → Kapitel 2 wählbar
##   2 — Frankfurt gewonnen → Kapitel 3 wählbar
##   3 — Hochzeit gewonnen → alles offen
##
## **Auf Olivers Wunsch sind alle Kapitel von Anfang an offen** —
## `erreicht` startet auf 3 statt 0. Das Spiel bleibt eine Reise, aber
## niemand muss sich den Zugang erst erspielen. Wer die Sperre zurück
## will: den Startwert unten wieder auf 0 setzen (F9 auf dem Titel
## schaltet dann weiterhin alles frei).

const PFAD := "user://spielstand.cfg"

## Höchste freigeschaltete Stufe (siehe oben). Start: alles offen.
var erreicht: int = 3


func _ready() -> void:
	laden()


func laden() -> void:
	var ablage := ConfigFile.new()
	if ablage.load(PFAD) != OK:
		return
	# maxi statt Zuweisung: ein alter Spielstand mit niedrigerer Stufe
	# darf die Alles-offen-Voreinstellung nicht wieder zusperren.
	erreicht = maxi(erreicht, int(ablage.get_value("fortschritt", "erreicht", 0)))


## Nach einem Kapitelsieg aufrufen — hebt die Stufe an und speichert.
## Ein niedrigerer Wert setzt nie zurück: wer Kapitel 1 noch einmal
## spielt, verliert nicht den Zugang zu Kapitel 3.
func freischalten(stufe: int) -> void:
	if stufe <= erreicht:
		return
	erreicht = stufe
	var ablage := ConfigFile.new()
	ablage.set_value("fortschritt", "erreicht", erreicht)
	ablage.save(PFAD)
