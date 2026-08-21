extends SceneTree

## Headless check for the optional memories and the closing scene.
##
##   godot --headless --path . --script res://tools/headless_ending_check.gd
##
## The walk itself is covered by `headless_chapter_check.gd`; this one takes the
## two pieces that sit at either end of it:
##
##   1. every memory point along the route can be talked to, plays its lines and
##      hands the controls back afterwards
##   2. winning the mini-game leads into the closing scene — both figures end up
##      on their marks facing each other, the camera on its mark looking at them,
##      and the chapter reports itself finished
##
## Written as one coroutine rather than a state machine: the sequence under test
## *is* a sequence, and reading it top to bottom is the point. `await
## physics_frame` works because a SceneTree script is the tree itself.

const FRAME_BUDGET := 12000
## How close to its mark a figure has to end up (metres).
const PLATZ_TOLERANZ := 0.35
## How exactly two figures have to face each other. 1.0 = perfect.
const BLICK_TOLERANZ := 0.9

var _root: Node3D
var _player: Player
var _oliver: Companion
var _dialogue: DialogueBox
var _darts: DartsGame
var _abspann: CanvasLayer

var _kapitel_fertig: bool = false
var _failures: PackedStringArray = []
var _notes: PackedStringArray = []


func _initialize() -> void:
	_root = load("res://chapters/berlin/berlin_chapter.tscn").instantiate() as Node3D
	root.add_child(_root)
	_player = _root.get_node_or_null("Player") as Player
	_oliver = _root.get_node_or_null("Oliver") as Companion
	_dialogue = _root.get_node_or_null("UI/DialogueBox") as DialogueBox
	_darts = _root.get_node_or_null("DartsGame") as DartsGame
	_abspann = _root.get_node_or_null("UI/ChapterCard") as CanvasLayer
	# Positionen erst ab dem ersten Physikschritt lesen — der Baum steht hier
	# noch nicht. Der Ablauf hängt gleich an seinem ersten `await`.
	_ablauf()


func _physics_process(_delta: float) -> bool:
	return false


func _ablauf() -> void:
	await physics_frame
	if _player == null or _oliver == null or _dialogue == null or _darts == null:
		_fail("chapter scene is missing Player, Oliver, DialogueBox or DartsGame")
		_report()
		return
	if _abspann == null:
		_fail("chapter scene is missing UI/ChapterCard")

	# Das Kapitel beginnt mit der Titeltafel und hält so lange die Steuerung.
	# Vorher anzusprechen führte zu nichts — der Sensor schweigt bewusst.
	var warten := 0
	while not _player.input_enabled and warten < 3000:
		warten += 1
		await physics_frame
	_expect(_player.input_enabled, "the opening hands the controls over")

	await _erinnerungen_pruefen()
	await _abschluss_pruefen()
	_report()


# --- Erinnerungen ----------------------------------------------------------


func _erinnerungen_pruefen() -> void:
	var gruppe := _root.get_node_or_null("Erinnerungen")
	if gruppe == null:
		_fail("no 'Erinnerungen' group in the chapter scene")
		return

	var punkte: Array[Interactable] = []
	for kind in gruppe.get_children():
		var punkt := kind as Interactable
		if punkt != null:
			punkte.append(punkt)

	_expect(punkte.size() >= 3,
		"at least three memories along the route: found %d" % punkte.size())

	for punkt in punkte:
		await _erinnerung_pruefen(punkt)

	_note("%d Erinnerungen angesprochen" % punkte.size())


func _erinnerung_pruefen(punkt: Interactable) -> void:
	# Direkt an das Fundstück stellen. Die Kugel des Interactable reicht weiter
	# als ein Meter, die Spielerin steht damit sicher im Bereich.
	_player.velocity = Vector3.ZERO
	_player.global_position = punkt.global_position + Vector3.UP * 0.3
	for i in 12:
		await physics_frame

	_send_action(&"interact")

	var gewartet := 0
	while not _dialogue.is_playing() and gewartet < 120:
		gewartet += 1
		await physics_frame

	if not _dialogue.is_playing():
		_fail("memory '%s' did not start a conversation" % punkt.get_parent().name
			if punkt.get_parent() != null else punkt.name)
		return

	_expect(not _player.input_enabled,
		"memory '%s' takes the controls while it talks" % punkt.name)

	var frames := 0
	while _dialogue.is_playing() and frames < 900:
		frames += 1
		if frames % 14 == 0:
			_send_action(&"interact")
		await physics_frame

	_expect(not _dialogue.is_playing(), "memory '%s' finished" % punkt.name)

	var zurueck := 0
	while not _player.input_enabled and zurueck < 120:
		zurueck += 1
		await physics_frame
	_expect(_player.input_enabled,
		"memory '%s' hands the controls back" % punkt.name)


# --- Abschluss -------------------------------------------------------------


func _abschluss_pruefen() -> void:
	var chapter := _root
	chapter.kapitel_abgeschlossen.connect(func() -> void: _kapitel_fertig = true)

	# Den Übergang so auslösen, wie ihn die Ankunft an der Dönerbude auslöst,
	# und dann eine Runde gewinnen lassen — ohne Würfe, die prüft der
	# Dart-Check. Interessant ist hier nur, was danach passiert. Der Sprung
	# ins nächste Kapitel bleibt aus, die Messungen brauchen die Szene.
	chapter.weiter_nach_gewinn = false
	chapter._minispiel_starten()
	var gewartet := 0
	while _darts.zustand != DartsGame.Zustand.ZIELEN and gewartet < 900:
		gewartet += 1
		await physics_frame
	_expect(_darts.zustand == DartsGame.Zustand.ZIELEN,
		"the mini-game takes over at the kebab shop")

	_darts.punkte = DartsConfig.ZIELPUNKTZAHL
	_darts._runde_beenden()

	var frames := 0
	while not _kapitel_fertig and frames < FRAME_BUDGET:
		frames += 1
		if _dialogue.is_playing() and frames % 14 == 0:
			_send_action(&"interact")
		await physics_frame

	if not _kapitel_fertig:
		_fail("the closing scene never finished")
		return

	_note("Abschluss dauerte %.0f s" % (frames / 60.0))
	_platz_pruefen("Anne", _player, _root.get_node("Abschluss/Anne") as Marker3D)
	_platz_pruefen("Oliver", _oliver, _root.get_node("Abschluss/Oliver") as Marker3D)
	_blick_pruefen()
	_kamera_pruefen()

	_expect(_darts.zustand == DartsGame.Zustand.INAKTIV,
		"the mini-game has let go by the end")
	if _abspann != null:
		_expect(_abspann.visible, "the chapter title card is on screen")
		var schwarz := _abspann.get_node_or_null("Schwarz") as ColorRect
		_expect(schwarz != null and schwarz.color.a > 0.98,
			"the picture is fully faded out behind the title")


func _platz_pruefen(name: String, figur: Node3D, marke: Marker3D) -> void:
	if marke == null:
		_fail("no closing mark for %s" % name)
		return
	var hier := figur.global_position
	var dort := marke.global_position
	var abstand := Vector2(hier.x - dort.x, hier.z - dort.z).length()
	_expect(abstand < PLATZ_TOLERANZ,
		"%s ends on the closing mark: %.2f m off" % [name, abstand])


func _blick_pruefen() -> void:
	var zu_oliver := _oliver.global_position - _player.global_position
	zu_oliver.y = 0.0
	if zu_oliver.length() < 0.1:
		_fail("Anne and Oliver end up in the same spot")
		return
	zu_oliver = zu_oliver.normalized()

	var anne_blick := -_player.global_transform.basis.z
	anne_blick = Vector3(anne_blick.x, 0.0, anne_blick.z).normalized()
	var oliver_blick := -_oliver.global_transform.basis.z
	oliver_blick = Vector3(oliver_blick.x, 0.0, oliver_blick.z).normalized()

	_expect(anne_blick.dot(zu_oliver) > BLICK_TOLERANZ,
		"Anne looks at Oliver: %.2f" % anne_blick.dot(zu_oliver))
	_expect(oliver_blick.dot(-zu_oliver) > BLICK_TOLERANZ,
		"Oliver looks at Anne: %.2f" % oliver_blick.dot(-zu_oliver))
	_note("Abstand im Schlussbild %.2f m" % _player.global_position.distance_to(
		_oliver.global_position))


func _kamera_pruefen() -> void:
	var marke := _root.get_node_or_null("Abschluss/Kamera") as Marker3D
	if marke == null:
		_fail("no closing camera mark")
		return

	var kamera := _darts.kamera
	_expect(kamera.current, "the closing shot is the one on screen")
	_expect(kamera.global_position.distance_to(marke.global_position) < 0.05,
		"the camera reaches its mark: %.2f m off"
			% kamera.global_position.distance_to(marke.global_position))

	var mitte := (_player.global_position + _oliver.global_position) * 0.5
	mitte.y += 1.0
	var zur_mitte := (mitte - kamera.global_position).normalized()
	var blick := -kamera.global_transform.basis.z
	_expect(blick.dot(zur_mitte) > 0.97,
		"the camera looks at the two of them: %.3f" % blick.dot(zur_mitte))

	# Beide müssen auch wirklich ganz im Bild sein. Eine Kamera kann genau auf
	# die Mitte zielen und trotzdem zwei angeschnittene Oberkörper zeigen, wenn
	# sie zu nah steht — deshalb wird von den Füßen bis über den Kopf geprüft.
	for paar in [["Anne", _player], ["Oliver", _oliver]]:
		var figur := paar[1] as Node3D
		for hoehe: float in [0.0, 0.9, 1.85]:
			var punkt: Vector3 = figur.global_position + Vector3.UP * hoehe
			_expect(
				not kamera.is_position_behind(punkt)
					and kamera.is_position_in_frustum(punkt),
				"%s is fully in the closing shot (at %.2f m)" % [paar[0], hoehe]
			)


# --- Werkzeug --------------------------------------------------------------


func _send_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


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
		print("ending check: OK")
		quit()
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	print("ending check: %d failure(s)" % _failures.size())
	quit(1)
