class_name DialogueBox
extends CanvasLayer

## Plays a sequence of dialogue lines and waits for the player to advance.
##
## The box knows nothing about *which* conversation is running — it takes an
## array of lines and reports when it is done:
##
##     await dialogue_box.play(BerlinDialogue.MEETING)
##
## A line is a dictionary with "speaker" and "text". Keeping it to plain
## dictionaries means the writing lives in one editable file and never touches
## gameplay code.

signal finished
## Meldet den Sprecher jeder neu angezeigten Zeile — die Szene lässt die
## passende Figur dazu nicken.
signal zeile_begonnen(sprecher: String)

## Characters revealed per second. Slow enough to read along, fast enough not
## to feel like waiting.
@export_range(10.0, 200.0, 5.0) var characters_per_second: float = 55.0
## Ignore advance presses for this long after a line appears, so the button
## press that started the conversation does not skip the first line.
@export_range(0.0, 1.0, 0.05) var advance_lockout: float = 0.25
## Sims-Gebrabbel zu den Sprechzeilen. Auf Olivers Wunsch abgeschaltet —
## die Silben liegen weiter unter audio/gebrabbel/, ein `true` holt sie
## zurück.
@export var gebrabbel_aktiv: bool = false

@onready var _root: Control = $Root
@onready var _speaker_label: Label = $Root/Panel/Margin/VBox/Speaker
@onready var _text_label: RichTextLabel = $Root/Panel/Margin/VBox/Text
@onready var _hint: Label = $Root/Panel/Margin/VBox/Hint

var _lines: Array = []
var _index: int = 0
var _revealed: float = 0.0
var _line_time: float = 0.0
var _running: bool = false

# --- Gebrabbel: Sims-artige Fantasiesilben, solange die Zeile tippt. ------
# Je Sprecher ein Silbenvorrat (synthetisiert in tools/make_gebrabbel.py);
# die Silben werden zufällig aneinandergereiht, mit kleinen Atempausen und
# leicht streuender Tonhöhe. Unbekannte Sprecher brabbeln mit Olivers
# Silben, einen Halbton verschoben — so hat jede Nebenfigur eine Stimme.
var _stimmen: Dictionary = {}
var _brabbler: AudioStreamPlayer
var _silben: Array = []
var _brabbel_tonlage := 1.0
var _brabbel_pause := 0.0


func _ready() -> void:
	_root.visible = false
	_brabbler = AudioStreamPlayer.new()
	_brabbler.volume_db = -10.0
	add_child(_brabbler)
	for stimme in ["anne", "oliver"]:
		var vorrat: Array = []
		for i in range(1, 13):
			var pfad := "res://audio/gebrabbel/%s_%02d.ogg" % [stimme, i]
			if ResourceLoader.exists(pfad):
				vorrat.append(load(pfad))
		_stimmen[stimme] = vorrat


## Shows the given lines. Await this call to continue once the player has read
## them all.
func play(lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_running = true
	_root.visible = true
	_show_line()
	await finished


## True while a conversation is on screen.
func is_playing() -> bool:
	return _running


func _process(delta: float) -> void:
	if not _running:
		return
	_line_time += delta
	if _revealed < _text_label.get_total_character_count():
		_revealed += characters_per_second * delta
		_text_label.visible_characters = int(_revealed)
		_hint.visible = false
		_brabbeln(delta)
	else:
		_hint.visible = true


## Reiht Silben aneinander, solange die Zeile noch tippt. Zwischen den
## Silben liegen kurze Lücken, ab und zu eine längere „Wortpause".
func _brabbeln(delta: float) -> void:
	if not gebrabbel_aktiv or _silben.is_empty() or _brabbler.playing:
		return
	_brabbel_pause -= delta
	if _brabbel_pause > 0.0:
		return
	_brabbler.stream = _silben[randi() % _silben.size()]
	_brabbler.pitch_scale = _brabbel_tonlage * randf_range(0.94, 1.07)
	_brabbler.play()
	_brabbel_pause = 0.28 if randf() < 0.22 else randf_range(0.01, 0.09)


func _unhandled_input(event: InputEvent) -> void:
	if not _running or _line_time < advance_lockout:
		return
	if not (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		return
	get_viewport().set_input_as_handled()

	# First press completes the line, second press advances. Impatient players
	# never have to wait for the typewriter.
	if _revealed < _text_label.get_total_character_count():
		_revealed = _text_label.get_total_character_count()
		_text_label.visible_characters = -1
		return
	_advance()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_running = false
		_root.visible = false
		finished.emit()
		return
	_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	_speaker_label.text = str(line.get("speaker", ""))
	zeile_begonnen.emit(_speaker_label.text)
	_text_label.text = str(line.get("text", ""))
	_text_label.visible_characters = 0
	_revealed = 0.0
	_line_time = 0.0
	_hint.visible = false
	_stimme_waehlen(_speaker_label.text)


func _stimme_waehlen(sprecher: String) -> void:
	var kennung := sprecher.to_lower()
	_brabbel_tonlage = 1.0
	if _stimmen.has(kennung):
		_silben = _stimmen[kennung]
	else:
		# Nebenfiguren: Olivers Vorrat, pro Name eine eigene feste Tonlage.
		_silben = _stimmen.get("oliver", [])
		_brabbel_tonlage = 1.06 + 0.12 * float(hash(kennung) % 5) / 4.0
	_brabbel_pause = 0.0
