extends Node3D

## Kapitel 1 — Berlin. Ablaufsteuerung für den Startbereich.
##
## Die Sequenz steht bewusst als gerade heruntergeschriebene Abfolge da: wer
## sie liest, sieht die Szene vor sich. Ein Zustandsautomat oder ein visuelles
## Skriptsystem wäre für so wenige Schritte mehr Gerüst als Inhalt.
##
## Signal `meeting_finished` gibt es, damit Stage 3 hier andocken kann, ohne
## dieses Skript zu verändern.

signal meeting_finished

## Wie weit die Kamera fürs Gespräch zur Seite schwenkt. Genau hinter der
## Spielerin verdeckt sie Oliver komplett; seitlich stehen beide im Bild.
@export_range(0.0, 90.0, 5.0) var gespraechswinkel_grad: float = 48.0

@onready var _player: Player = $Player
@onready var _camera: ThirdPersonCamera = $ThirdPersonCamera
@onready var _oliver: Companion = $Oliver
@onready var _dialogue: DialogueBox = $UI/DialogueBox
@onready var _objective = $UI/ObjectiveLabel


func _ready() -> void:
	var meeting_trigger := _oliver.get_node("Interactable") as Interactable
	meeting_trigger.interacted.connect(_on_oliver_met)
	_objective.show_objective("Oliver treffen")


func _on_oliver_met(_interactor: Node3D) -> void:
	# Steuerung abgeben: die Figur bremst normal aus, statt einzufrieren.
	_player.input_enabled = false
	_oliver.hold()
	_camera.aim_at_yaw(_conversation_yaw())

	await _dialogue.play(BerlinDialogue.MEETING)

	_camera.release_aim()
	_oliver.activate()
	_player.input_enabled = true
	_objective.show_objective("Gemeinsam weitergehen")
	meeting_finished.emit()


## Blickrichtung entlang der Achse zwischen beiden Figuren, seitlich versetzt.
func _conversation_yaw() -> float:
	var to_oliver := _oliver.global_position - _player.global_position
	to_oliver.y = 0.0
	if to_oliver.length() < 0.1:
		return _camera.rotation.y
	to_oliver = to_oliver.normalized()
	return atan2(-to_oliver.x, -to_oliver.z) + deg_to_rad(gespraechswinkel_grad)
