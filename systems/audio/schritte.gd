class_name Schritte
extends AudioStreamPlayer3D

## Schrittgeräusche für eine Figur, die keine Laufanimation hat.
##
## Ohne Animation gibt es keinen Zeitpunkt, an dem ein Fuß aufsetzt — also
## zählt dieser Knoten den **zurückgelegten Weg** und tritt alle `schrittlaenge`
## Meter auf. Das koppelt den Klang an das Tempo statt an eine feste Rate: wer
## rennt, tritt öfter auf, und beim Stehenbleiben hört es von selbst auf. Sobald
## echte Animationen da sind, ersetzt ein Animationsereignis diese Zählerei.
##
## Vier Aufnahmen mit leicht zufälliger Tonhöhe, damit aus dem Gehen kein
## Metronom wird — dieselbe Datei zweimal hintereinander hört man sofort.
## Die Aufnahmen sind echte Kenney-Schritte (CC0, audio/kenney/) — die
## alte Ferse-Ballen-Synthese klang metallisch.

signal aufgetreten

## Meter zwischen zwei Schritten.
##
## Nicht die anatomisch richtige Schrittlänge: das Spieltempo von 3,4 m/s ist
## bereits überzeichnet, und mit einer echten Schrittlänge von 0,8 m ergäbe das
## über vier Schritte pro Sekunde — ein Trommelwirbel. Der Wert ist so gewählt,
## dass beim Gehen eine ruhige Kadenz herauskommt.
@export_range(0.3, 3.0, 0.05) var schrittlaenge: float = 1.5
## Kürzester Abstand zwischen zwei Schritten in Sekunden. Verhindert Trommeln,
## falls eine Figur einmal geschoben wird statt zu gehen.
@export_range(0.05, 1.0, 0.01) var mindestpause: float = 0.22
## Spanne der zufälligen Tonhöhe.
@export_range(0.0, 0.5, 0.01) var tonhoehen_streuung: float = 0.12
## Unterhalb dieses Tempos wird nicht mitgezählt (m/s).
@export_range(0.0, 2.0, 0.05) var mindesttempo: float = 0.4
## Die Figur, deren Bewegung gezählt wird. Voreinstellung: der Elternknoten.
@export var koerper_pfad: NodePath = ^".."

var _koerper: CharacterBody3D
var _aufnahmen: Array[AudioStream] = []
var _weg: float = 0.0
var _seit_letztem: float = 0.0
var _letzte: int = -1


func _ready() -> void:
	_koerper = get_node_or_null(koerper_pfad) as CharacterBody3D
	if _koerper == null:
		push_warning("Schritte: keine Figur unter '%s'." % koerper_pfad)
		set_process(false)
		return

	for nummer in range(1, 5):
		var pfad := "res://audio/kenney/schritt_%d.ogg" % nummer
		if not ResourceLoader.exists(pfad):
			# Rückfall auf die synthetischen Tritte, falls die Aufnahmen fehlen.
			pfad = "res://audio/schritt_%d.wav" % nummer
		if ResourceLoader.exists(pfad):
			_aufnahmen.append(load(pfad))
	if _aufnahmen.is_empty():
		push_warning("Schritte: keine Aufnahmen unter res://audio/.")
		set_process(false)


func _process(delta: float) -> void:
	_seit_letztem += delta

	var tempo := Vector3(_koerper.velocity.x, 0.0, _koerper.velocity.z).length()
	if tempo < mindesttempo or not _koerper.is_on_floor():
		# Beim Stehenbleiben den halben Schritt behalten: so tritt die Figur
		# beim Weitergehen sofort auf, statt erst nach einem vollen Meter.
		return

	_weg += tempo * delta
	if _weg < schrittlaenge or _seit_letztem < mindestpause:
		return

	_weg = 0.0
	_seit_letztem = 0.0
	_auftreten()


func _auftreten() -> void:
	var wahl := randi() % _aufnahmen.size()
	if _aufnahmen.size() > 1 and wahl == _letzte:
		wahl = (wahl + 1) % _aufnahmen.size()
	_letzte = wahl

	stream = _aufnahmen[wahl]
	pitch_scale = 1.0 + randf_range(-tonhoehen_streuung, tonhoehen_streuung)
	play()
	aufgetreten.emit()
