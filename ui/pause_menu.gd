extends CanvasLayer

## Pausenmenü auf Escape.
##
## Vorher gab Escape nur die Maus frei — praktisch beim Entwickeln, aber für
## jemanden, der einfach kurz weg muss, kein Verhalten. Das Menü hält das Spiel
## an und gibt dabei die Maus frei; beides gehört zusammen.

@onready var _wurzel: Control = $Wurzel
@onready var _weiter: Button = $Wurzel/Panel/Margin/VBox/Weiter
@onready var _beenden: Button = $Wurzel/Panel/Margin/VBox/Beenden

var _maus_vorher: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	# Muss auch laufen, wenn der Baum angehalten ist — sonst ließe sich die
	# Pause nie wieder beenden.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wurzel.visible = false
	_weiter.pressed.connect(func() -> void: _setze_pause(false))
	_beenden.pressed.connect(func() -> void: get_tree().quit())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_setze_pause(not _wurzel.visible)
		get_viewport().set_input_as_handled()


func _setze_pause(an: bool) -> void:
	_wurzel.visible = an
	get_tree().paused = an
	if an:
		_maus_vorher = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_weiter.grab_focus()
	else:
		Input.mouse_mode = _maus_vorher
