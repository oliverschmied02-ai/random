extends SceneTree

## Headless playthrough of Chapter 1.
##
##   godot --headless --path . --script res://tools/headless_chapter_check.gd
##
## Walks the whole route with simulated input — no teleporting — so the numbers
## it reports are the ones a player would experience: how long the walk takes,
## whether every station fires, and whether Oliver keeps up around the corners.
##
## Steering: the character moves relative to the camera, so the check points the
## camera rig along the direction of the next waypoint (`snap_to_yaw`) and holds
## "forward". Movement is polled from the action state, which `Input.action_press`
## sets; the dialogue and interaction read input *events*, which need a real
## event via `Input.parse_input_event`.

const FRAME_BUDGET := 30000
const WAYPOINT_REACHED := 3.0

## The route a player would take. The first entry is Oliver's office door.
const WAYPOINTS: Array[Vector3] = [
	Vector3(10, 0, -9),     # vor der Bürotür
	Vector3(0, 0, -50),     # Bürostraße nach Norden
	Vector3(60, 0, -55),    # Ecke zur Querstraße
	Vector3(60, 0, -100),   # geschlossenes Café
	Vector3(60, 0, -135),   # weiter nach Norden
	Vector3(128, 0, -135),  # zweite Querstraße
	Vector3(130, 0, -190),  # Platz mit Spender
	Vector3(128, 0, -231),  # Dönerbude
]

var _root: Node3D
var _player: Player
var _oliver: Companion
var _dialogue: DialogueBox
var _camera: ThirdPersonCamera
var _darts: DartsGame

var _frames: int = 0
var _walking_frames: int = 0
var _dialogue_frames: int = 0
var _waypoint: int = 0
var _dialogues_seen: int = 0
var _was_playing: bool = false
var _picked_up: bool = false
var _pickup_frame: int = 0
var _oliver_travelled: float = 0.0
var _oliver_last: Vector3 = Vector3.ZERO
var _tracking_started: bool = false
var _max_gap: float = 0.0
var _failures: PackedStringArray = []
var _notes: PackedStringArray = []


func _initialize() -> void:
	_root = load("res://chapters/berlin/berlin_chapter.tscn").instantiate() as Node3D
	root.add_child(_root)
	_player = _root.get_node_or_null("Player") as Player
	_oliver = _root.get_node_or_null("Oliver") as Companion
	_dialogue = _root.get_node_or_null("UI/DialogueBox") as DialogueBox
	_camera = _root.get_node_or_null("ThirdPersonCamera") as ThirdPersonCamera
	_darts = _root.get_node_or_null("DartsGame") as DartsGame
	if _player == null or _oliver == null or _dialogue == null or _camera == null:
		_fail("chapter scene is missing Player, Oliver, DialogueBox or camera")
	# Positionen werden erst im ersten Physikschritt gelesen: in _initialize
	# steht der Szenenbaum noch nicht, `global_position` liefert dort die
	# Einheitsmatrix — Olivers Wegstrecke wäre um seinen Startabstand zu groß.


func _physics_process(_delta: float) -> bool:
	if _player == null:
		_report()
		return true

	_frames += 1
	if _frames > FRAME_BUDGET:
		_fail("ran out of frames at waypoint %d" % _waypoint)
		_report()
		return true

	_track_oliver()
	_count_dialogues()

	if _dialogue.is_playing():
		_dialogue_frames += 1
		Input.action_release(&"move_forward")
		# First press completes the line, the next advances it.
		if _frames % 14 == 0:
			_send_action(&"interact")
		return false

	# Das Kapitel mündet in das Minispiel; sobald das übernimmt, ist der
	# Spaziergang gelaufen und die Steuerung bleibt planmäßig abgegeben.
	if _darts != null and _darts.zustand != DartsGame.Zustand.INAKTIV:
		_finish()
		return true

	if _picked_up and _dialogues_seen == 0 and _frames - _pickup_frame > 180:
		_fail("talking to Oliver did not start the conversation")
		_report()
		return true

	if not _player.input_enabled:
		return false  # a scene is setting itself up

	if _waypoint >= WAYPOINTS.size():
		_finish()
		return true

	_walking_frames += 1
	_steer_to_waypoint()
	return false


func _steer_to_waypoint() -> void:
	var target: Vector3 = WAYPOINTS[_waypoint]
	var reach := WAYPOINT_REACHED
	if _waypoint == 0 and not _picked_up:
		# Walk right up to Oliver, not just to the waypoint: the interaction
		# only reaches a couple of metres.
		target = _oliver.global_position
		reach = 2.2

	var to_target := target - _player.global_position
	to_target.y = 0.0

	if to_target.length() < reach:
		if _waypoint == 0 and not _picked_up:
			Input.action_release(&"move_forward")
			_send_action(&"interact")
			_picked_up = true
			_pickup_frame = _frames
			return
		_waypoint += 1
		return

	# Point the rig along the direction of travel, then simply hold forward.
	_camera.snap_to_yaw(atan2(-to_target.x, -to_target.z))
	Input.action_press(&"move_forward")


func _track_oliver() -> void:
	var here := _oliver.global_position
	if not _tracking_started:
		_tracking_started = true
		_oliver_last = here
		return
	_oliver_travelled += _oliver_last.distance_to(here)
	_oliver_last = here
	if _picked_up and _oliver.state == Companion.State.FOLLOWING:
		_max_gap = maxf(_max_gap, here.distance_to(_player.global_position))


func _count_dialogues() -> void:
	var playing := _dialogue.is_playing()
	if playing and not _was_playing:
		_dialogues_seen += 1
	_was_playing = playing


func _finish() -> void:
	Input.action_release(&"move_forward")

	var erwartet: int = 1 + _root._STATIONEN.size()  # Abholen + Stationen
	_expect(_dialogues_seen == erwartet,
		"all conversations played (pickup + stations): saw %d of %d"
			% [_dialogues_seen, erwartet])
	_expect(_oliver.state != Companion.State.IDLE, "Oliver joined the walk")
	_expect(_darts != null and _darts.zustand != DartsGame.Zustand.INAKTIV,
		"arriving at the kebab shop hands over to the dart mini-game")
	_expect(_oliver_travelled > 250.0,
		"Oliver walked the route himself: %.0f m" % _oliver_travelled)
	_expect(_max_gap < 25.0,
		"Oliver never fell far behind: worst gap %.1f m" % _max_gap)
	_expect(_oliver.is_on_floor(), "Oliver ends on the ground, not stuck in geometry")
	_expect(_player.global_position.y > -1.0, "player never fell through the world")

	var total := _frames / 60.0
	var walking := _walking_frames / 60.0
	_expect(total > 90.0 and total < 260.0,
		"playthrough lands in the intended 2–3 minutes: %.0f s" % total)

	_note("Gesamtdauer %.0f s (%.1f min)" % [total, total / 60.0])
	_note("davon Laufen %.0f s, Dialoge %.0f s" % [walking, _dialogue_frames / 60.0])
	_note("Oliver lief %.0f m mit, größter Abstand %.1f m" % [_oliver_travelled, _max_gap])
	_report()


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
		print("chapter check: OK")
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	print("chapter check: %d failure(s)" % _failures.size())
	quit(1)
