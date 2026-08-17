extends SceneTree

## Headless check for the frame around the game: title screen, chapter opening,
## audio buses and footsteps.
##
##   godot --headless --path . --script res://tools/headless_rahmen_check.gd
##
## None of this can be heard here — headless has no audio device. What it *can*
## establish is that everything is wired: the buses exist, the volume settings
## reach them, every player has a stream, and the footsteps fire at a sane rate
## for the walking speed. Whether the sounds are any good is a question for
## headphones.

const FRAME_BUDGET := 3000
## How long the walking cadence is measured, in seconds.
const MESSDAUER := 5.0

## Lambdas fangen lokale Variablen als Kopie ein — der Zähler muss deshalb
## ein Feld sein, sonst zählt das Signal ins Leere.
var _schritte_gezaehlt: int = 0
var _failures: PackedStringArray = []
var _notes: PackedStringArray = []


func _initialize() -> void:
	_ablauf()


func _physics_process(_delta: float) -> bool:
	return false


func _ablauf() -> void:
	await physics_frame
	_ton_pruefen()
	await _titel_pruefen()
	await _kapitel_pruefen()
	_report()


# --- Ton -------------------------------------------------------------------


func _ton_pruefen() -> void:
	for name in ["Musik", "Klang"]:
		_expect(AudioServer.get_bus_index(name) >= 0, "audio bus '%s' exists" % name)

	var vorher := Ton.lautstaerke("musik")
	Ton.setze_lautstaerke("musik", 0.25)
	var bus := AudioServer.get_bus_index(&"Musik")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.25)),
		"the music slider reaches the bus: %.1f dB" % AudioServer.get_bus_volume_db(bus))

	Ton.setze_lautstaerke("musik", 0.0)
	_expect(AudioServer.is_bus_mute(bus), "a slider at zero means silence, not 'very quiet'")

	Ton.setze_lautstaerke("musik", vorher)
	_expect(not AudioServer.is_bus_mute(bus), "and it comes back")


# --- Titelbildschirm -------------------------------------------------------


func _titel_pruefen() -> void:
	var titel := load("res://ui/title_screen.tscn").instantiate() as Control
	root.add_child(titel)
	await physics_frame

	for pfad in ["Mitte/VBox/Anfangen", "Mitte/VBox/Beenden"]:
		_expect(titel.get_node_or_null(pfad) is Button, "title screen has %s" % pfad)

	var musik := titel.get_node_or_null("Musik") as AudioStreamPlayer
	_expect(musik != null and musik.stream != null, "the title has music")
	if musik != null:
		_expect(musik.bus == &"Musik", "title music runs on the music bus")
		var welle := musik.stream as AudioStreamWAV
		_expect(welle != null and welle.loop_mode != AudioStreamWAV.LOOP_DISABLED,
			"title music loops instead of falling silent after one pass")

	var ziel: String = titel.kapitel
	_expect(ResourceLoader.exists(ziel), "'Anfangen' points at a scene that exists: %s" % ziel)
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"the title screen shows the mouse pointer")

	titel.queue_free()
	await physics_frame


# --- Kapitelauftakt und Schritte -------------------------------------------


func _kapitel_pruefen() -> void:
	var kapitel := load("res://chapters/berlin/berlin_chapter.tscn").instantiate() as Node3D
	root.add_child(kapitel)
	await physics_frame

	var spielerin := kapitel.get_node("Player") as Player
	var karte := kapitel.get_node_or_null("UI/ChapterCard") as CanvasLayer
	_expect(karte != null, "the chapter has its title card")
	_expect(not spielerin.input_enabled,
		"the chapter opens with the controls held — the title card is still up")

	var frames := 0
	while not spielerin.input_enabled and frames < FRAME_BUDGET:
		frames += 1
		await physics_frame
	_expect(spielerin.input_enabled, "the opening hands the controls over")
	_note("Auftakt dauert %.1f s" % (frames / 60.0))
	if karte != null:
		_expect(not karte.visible, "the title card is out of the way afterwards")

	var stadt := kapitel.get_node_or_null("Klang/Stadt") as AudioStreamPlayer
	_expect(stadt != null and stadt.playing, "the city is audible from the first second")

	await _schritte_pruefen(kapitel, spielerin)
	kapitel.queue_free()
	await physics_frame


func _schritte_pruefen(kapitel: Node3D, spielerin: Player) -> void:
	var schritte := spielerin.get_node_or_null("Schritte") as Schritte
	if schritte == null:
		_fail("the player has no footsteps")
		return

	_schritte_gezaehlt = 0
	schritte.aufgetreten.connect(func() -> void: _schritte_gezaehlt += 1)

	var start := spielerin.global_position
	var kamera := kapitel.get_node("ThirdPersonCamera") as ThirdPersonCamera
	kamera.snap_to_yaw(spielerin.rotation.y)

	Input.action_press(&"move_forward")
	for i in int(MESSDAUER * 60):
		await physics_frame
	Input.action_release(&"move_forward")

	var strecke := start.distance_to(spielerin.global_position)
	_expect(_schritte_gezaehlt > 0, "walking makes a sound at all")
	if _schritte_gezaehlt == 0:
		return

	var pro_sekunde := _schritte_gezaehlt / MESSDAUER
	var pro_schritt := strecke / _schritte_gezaehlt
	_note("Gehen: %d Schritte in %.0f s (%.1f/s, %.2f m je Schritt)"
		% [_schritte_gezaehlt, MESSDAUER, pro_sekunde, pro_schritt])

	# Eine ruhige Gehkadenz liegt bei rund zwei Schritten je Sekunde. Deutlich
	# darüber trommelt es, deutlich darunter schleicht die Figur.
	_expect(pro_sekunde > 1.5 and pro_sekunde < 3.2,
		"the walking cadence is calm: %.1f steps/s" % pro_sekunde)
	_expect(absf(pro_schritt - schritte.schrittlaenge) < 0.35,
		"steps land every %.2f m as configured (%.2f m)"
			% [pro_schritt, schritte.schrittlaenge])


# --- Werkzeug --------------------------------------------------------------


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)


func _note(text: String) -> void:
	_notes.append(text)


func _report() -> void:
	for note in _notes:
		print("note: ", note)
	if _failures.is_empty():
		print("rahmen check: OK")
		quit()
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	print("rahmen check: %d failure(s)" % _failures.size())
	quit(1)
