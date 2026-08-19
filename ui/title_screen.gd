extends Control

## Titelbildschirm — das Erste, was jemand sieht.
##
## Vorher fiel das Spiel mit der Tür ins Haus: Doppelklick, und man stand
## mitten in Berlin, mit gefangener Maus und ohne zu wissen, was das hier ist.
## Der Titel gibt dem Ganzen einen Anfang: einen Moment Ruhe, einen Namen und
## eine Taste, die man selbst drückt.
##
## Der Übergang ins Kapitel blendet ab und wechselt erst dann die Szene. Ein
## harter Schnitt mitten aus der Musik heraus wirkt wie ein Absturz.

## Szene, die *Anfangen* startet — erst die Tinder-Intro, die wechselt
## danach selbst ins Berlin-Kapitel.
@export_file("*.tscn") var kapitel: String = "res://chapters/intro/tinder_intro.tscn"
@export_range(0.2, 3.0, 0.1) var abblenden_dauer: float = 1.1
@export_range(0.2, 4.0, 0.1) var aufblenden_dauer: float = 1.6

@onready var _schwarz: ColorRect = $Schwarz
@onready var _anfangen: Button = $Mitte/VBox/Anfangen
@onready var _beenden: Button = $Mitte/VBox/Beenden
@onready var _musik: AudioStreamPlayer = $Musik
@onready var _klick: AudioStreamPlayer = $Klick

var _wechselt: bool = false


func _ready() -> void:
	# Die Kamera im Kapitel fängt die Maus ein; hier soll man klicken können.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_anfangen.pressed.connect(_auf_anfangen)
	_beenden.pressed.connect(_auf_beenden)
	_anfangen.grab_focus()

	_schwarz.color.a = 1.0
	create_tween().tween_property(_schwarz, ^"color:a", 0.0, aufblenden_dauer)


func _auf_anfangen() -> void:
	if _wechselt:
		return
	_wechselt = true
	_anfangen.disabled = true
	_beenden.disabled = true
	_klick.play()

	var ablauf := create_tween().set_parallel(true)
	ablauf.tween_property(_schwarz, ^"color:a", 1.0, abblenden_dauer)
	ablauf.tween_property(_musik, ^"volume_db", -40.0, abblenden_dauer)
	await ablauf.finished

	get_tree().change_scene_to_file(kapitel)


func _auf_beenden() -> void:
	_klick.play()
	# Kurz warten, sonst schließt das Fenster, bevor der Klick zu hören ist.
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()
