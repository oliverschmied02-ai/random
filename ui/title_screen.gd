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

	_kapitelwahl_bauen()


## Die Kapitel, die man direkt anspringen kann — jede Stufe wird erst
## nach dem Sieg im Kapitel davor frei (Spielstand). Gesperrte Einträge
## zeigen keine Namen: das dritte Kapitel soll keine Überraschung
## verraten, bevor man dort ankommt.
const _KAPITEL: Array = [
	["Kapitel 1 — Berlin", "res://chapters/berlin/berlin_chapter.tscn", 0],
	["Kapitel 2 — Frankfurt", "res://chapters/frankfurt/frankfurt_chapter.tscn", 1],
	["Kapitel 3 — Hochzeit", "res://chapters/hochzeit/hochzeit_chapter.tscn", 2],
]

var _kapitel_knoepfe: Array = []


func _kapitelwahl_bauen() -> void:
	for alt in _kapitel_knoepfe:
		(alt as Node).queue_free()
	_kapitel_knoepfe.clear()
	var kiste := _anfangen.get_parent()
	var vor_beenden := _beenden.get_index()
	for eintrag: Array in _KAPITEL:
		var frei: bool = Spielstand.erreicht >= int(eintrag[2])
		var knopf := Button.new()
		knopf.text = eintrag[0] if frei \
			else "Kapitel %d — ✻ ✻ ✻" % (int(eintrag[2]) + 1)
		knopf.disabled = not frei
		knopf.add_theme_font_size_override("font_size", 19)
		kiste.add_child(knopf)
		kiste.move_child(knopf, vor_beenden)
		vor_beenden += 1
		if frei:
			knopf.pressed.connect(_wechsel_zu.bind(String(eintrag[1])))
		_kapitel_knoepfe.append(knopf)


func _unhandled_key_input(event: InputEvent) -> void:
	# F9: alles freischalten — der Werkstattschlüssel, damit Oliver zum
	# Testen nicht jedes Mal alle Kapitel durchspielen muss.
	var taste := event as InputEventKey
	if taste != null and taste.pressed and taste.keycode == KEY_F9:
		Spielstand.freischalten(3)
		_kapitelwahl_bauen()


func _auf_anfangen() -> void:
	_wechsel_zu(kapitel)


func _wechsel_zu(szene: String) -> void:
	if _wechselt:
		return
	_wechselt = true
	_anfangen.disabled = true
	_beenden.disabled = true
	for knopf in _kapitel_knoepfe:
		(knopf as Button).disabled = true
	_klick.play()

	var ablauf := create_tween().set_parallel(true)
	ablauf.tween_property(_schwarz, ^"color:a", 1.0, abblenden_dauer)
	ablauf.tween_property(_musik, ^"volume_db", -40.0, abblenden_dauer)
	await ablauf.finished

	get_tree().change_scene_to_file(szene)


func _auf_beenden() -> void:
	_klick.play()
	# Kurz warten, sonst schließt das Fenster, bevor der Klick zu hören ist.
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()
