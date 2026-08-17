class_name StepClimber
extends RefCounted

## Hebt eine Figur über niedrige Hindernisse — Bordsteine, Treppenstufen,
## Schwellen.
##
## Godots `CharacterBody3D` bringt das nicht mit: `move_and_slide()` behandelt
## eine Treppenstufe wie eine Wand, und die gerundete Kapselunterseite
## überwindet nur wenige Zentimeter. Eine normale 18-cm-Stufe stoppt eine Figur
## vollständig.
##
## Der Ablauf ist ein Vorausfühlen: unten blockiert, eine Stufenhöhe weiter oben
## frei, und oben etwas Begehbares? Dann wird der Körper um genau die
## Stufenhöhe angehoben. Die waagerechte Bewegung bleibt `move_and_slide()`
## überlassen.
##
## Als eigener Baustein, weil Spielerin und Begleiter beide darauf angewiesen
## sind und GDScript keine Mehrfachvererbung kennt.

## Wie weit mindestens vorausgetastet wird. Eine Frame-Bewegung ist oft nur
## Millimeter — weniger als die Sicherheitsmarge der Physik — und würde das
## Hindernis, an dem die Figur bereits steht, gar nicht bemerken.
const MINDEST_TASTWEITE: float = 0.1

## Zusätzliche Höhe beim Absetzen, damit die waagerechte Bewegung die Kante
## sauber freikommt.
const KANTEN_ZUGABE: float = 0.005


## Versucht, `koerper` auf ein Hindernis vor ihm zu heben. Vor `move_and_slide()`
## aufrufen.
static func versuche(koerper: CharacterBody3D, max_stufenhoehe: float, delta: float) -> void:
	if max_stufenhoehe <= 0.0 or not ist_am_boden(koerper, max_stufenhoehe):
		return

	var richtung := Vector3(koerper.velocity.x, 0.0, koerper.velocity.z)
	if richtung.length_squared() < 0.000001:
		return
	var tastweite := richtung.normalized() * maxf(richtung.length() * delta, MINDEST_TASTWEITE)

	if not koerper.test_move(koerper.global_transform, tastweite):
		return  # nichts im Weg

	var anheben := Vector3.UP * max_stufenhoehe
	if koerper.test_move(koerper.global_transform, anheben):
		return  # kein Platz nach oben
	var angehoben := koerper.global_transform.translated(anheben)
	if koerper.test_move(angehoben, tastweite):
		return  # eine Stufe höher immer noch blockiert — das ist eine Wand

	var aufsetzen := KinematicCollision3D.new()
	var suchtiefe := max_stufenhoehe + 0.05
	if not koerper.test_move(angehoben.translated(tastweite), Vector3.DOWN * suchtiefe, aufsetzen):
		return  # nichts zum Draufstellen — eine Lücke, keine Stufe
	if aufsetzen.get_normal().angle_to(Vector3.UP) > koerper.floor_max_angle:
		return  # zu steil zum Stehen

	var hub := max_stufenhoehe + aufsetzen.get_travel().y
	if hub > 0.001:
		koerper.global_position.y += hub + KANTEN_ZUGABE


## Ob die Figur gerade angehoben werden darf.
##
## `is_on_floor()` allein genügt nicht: eine Kapsel, die halb auf eine
## Stufenkante geraten ist, liegt auf einer Ecke auf, und diesen steilen Kontakt
## meldet Godot als Wand. Genau dann bräuchte sie die Hilfe am dringendsten und
## bekäme sie nicht — sie hinge für immer auf der Kante.
static func ist_am_boden(koerper: CharacterBody3D, max_stufenhoehe: float) -> bool:
	if koerper.is_on_floor():
		return true
	if koerper.velocity.y > 0.1:
		return false  # im Steigen, keine verkeilte Kante
	return koerper.test_move(koerper.global_transform, Vector3.DOWN * (max_stufenhoehe * 0.5))
