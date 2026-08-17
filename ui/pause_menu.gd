extends CanvasLayer

## Pausenmenü auf Escape.
##
## Vorher gab Escape nur die Maus frei — praktisch beim Entwickeln, aber für
## jemanden, der einfach kurz weg muss, kein Verhalten. Das Menü hält das Spiel
## an und gibt dabei die Maus frei; beides gehört zusammen.
##
## Hier sitzen auch die Lautstärkeregler. Nicht in einem eigenen Einstellungs-
## menü: es sind zwei Regler, und die will man genau dann bewegen, wenn einem
## gerade etwas zu laut ist — also hier.

@export_file("*.tscn") var titelbildschirm: String = "res://ui/title_screen.tscn"

@onready var _wurzel: Control = $Wurzel
@onready var _weiter: Button = $Wurzel/Panel/Margin/VBox/Weiter
@onready var _zum_titel: Button = $Wurzel/Panel/Margin/VBox/ZumTitel
@onready var _beenden: Button = $Wurzel/Panel/Margin/VBox/Beenden
@onready var _musik: HSlider = $Wurzel/Panel/Margin/VBox/MusikZeile/Regler
@onready var _klang: HSlider = $Wurzel/Panel/Margin/VBox/KlangZeile/Regler
@onready var _klick: AudioStreamPlayer = $Klick

var _maus_vorher: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	# Muss auch laufen, wenn der Baum angehalten ist — sonst ließe sich die
	# Pause nie wieder beenden.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wurzel.visible = false

	_weiter.pressed.connect(func() -> void: _klick.play(); _setze_pause(false))
	_zum_titel.pressed.connect(_auf_zum_titel)
	_beenden.pressed.connect(func() -> void: _klick.play(); get_tree().quit())

	_musik.value = Ton.lautstaerke("musik")
	_klang.value = Ton.lautstaerke("klang")
	_musik.value_changed.connect(func(wert: float) -> void: Ton.setze_lautstaerke("musik", wert))
	_klang.value_changed.connect(func(wert: float) -> void: Ton.setze_lautstaerke("klang", wert))


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


## Zurück zum Titel. Die Pause muss vorher weg: eine neue Szene in einem
## angehaltenen Baum würde sich nicht rühren.
func _auf_zum_titel() -> void:
	_klick.play()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(titelbildschirm)
