extends Control

## Die Widmung — der allererste Bildschirm, noch vor dem Titel.
##
## Schwarz, Stille bis auf die ferne Stadt, dann in Ruhe zwei Zeilen:
## „Für Anne." und der Satz, worum es hier geht. Ein Klick (oder kurzes
## Warten) führt zum Titelbildschirm. Die Texte stehen in
## `dialogue_lines.gd` (WIDMUNG_TITEL, WIDMUNG_ZEILE) — dort lassen sie
## sich gefahrlos umschreiben.

const NAECHSTE_SZENE := "res://ui/title_screen.tscn"

## Sekunden, nach denen es auch ohne Klick weitergeht.
@export_range(5.0, 60.0, 0.5) var auto_weiter: float = 18.0

var _bereit := false
var _wechselt := false

@onready var _titel: Label = $Mitte/VBox/Titel
@onready var _zeile: Label = $Mitte/VBox/Zeile
@onready var _hinweis: Label = $Hinweis
@onready var _schwarz: ColorRect = $Schwarz


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_titel.text = BerlinDialogue.WIDMUNG_TITEL
	_zeile.text = BerlinDialogue.WIDMUNG_ZEILE
	_titel.modulate.a = 0.0
	_zeile.modulate.a = 0.0
	_hinweis.modulate.a = 0.0
	_schwarz.color.a = 0.0

	# Ferne Stadt unter dem schwarzen Bild — Berlin wartet schon.
	var stadt := AudioStreamPlayer.new()
	stadt.stream = load("res://audio/stadt_ambiente.mp3")
	stadt.volume_db = -24.0
	add_child(stadt)
	stadt.play()

	var ablauf := create_tween()
	ablauf.tween_interval(1.2)
	ablauf.tween_property(_titel, ^"modulate:a", 1.0, 1.8)
	ablauf.tween_interval(0.9)
	ablauf.tween_property(_zeile, ^"modulate:a", 1.0, 1.8)
	ablauf.tween_callback(func() -> void: _bereit = true)
	ablauf.tween_interval(1.4)
	ablauf.tween_property(_hinweis, ^"modulate:a", 0.45, 1.0)

	get_tree().create_timer(auto_weiter).timeout.connect(weiter)


## Blendet ab und wechselt zum Titel — vom Klick oder der Uhr ausgelöst.
func weiter() -> void:
	if _wechselt:
		return
	_wechselt = true
	var blende := create_tween()
	blende.tween_property(_schwarz, ^"color:a", 1.0, 1.1)
	blende.tween_callback(func() -> void:
		get_tree().change_scene_to_file(NAECHSTE_SZENE))


func _unhandled_input(ereignis: InputEvent) -> void:
	var klick: bool = ereignis is InputEventMouseButton and ereignis.is_pressed()
	var taste: bool = ereignis is InputEventKey and ereignis.is_pressed()
	var knopf: bool = ereignis is InputEventJoypadButton and ereignis.is_pressed()
	if (klick or taste or knopf) and _bereit:
		weiter()
