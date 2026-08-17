extends SceneTree

## Headless smoke test for the Chapter 1 meeting sequence.
##
##   godot --headless --path . --script res://tools/headless_chapter_check.gd
##
## Walks the player up to Oliver with simulated input, talks to him, and checks
## that every link in the chain holds: the interactable is detected, controls
## are handed over for the conversation, the dialogue runs to its end, the
## companion activates, and it then actually follows the player around.
##
## Movement uses `Input.action_press` because the controller polls the action
## state. The interaction and dialogue read input events instead, so those need
## a real event pushed through the viewport via `Input.parse_input_event`.

const FRAME_BUDGET := 3000

var _root: Node3D
var _player: Player
var _oliver: Companion
var _dialogue: DialogueBox
var _sensor: InteractionSensor

var _step: int = 0
var _step_frame: int = 0
var _frames: int = 0
var _failures: PackedStringArray = []
var _notes: PackedStringArray = []
var _walk_away_start: float = 0.0
var _oliver_start: Vector3 = Vector3.ZERO


func _initialize() -> void:
	_root = load("res://chapters/berlin/berlin_start.tscn").instantiate() as Node3D
	root.add_child(_root)
	_player = _root.get_node_or_null("Player") as Player
	_oliver = _root.get_node_or_null("Oliver") as Companion
	_dialogue = _root.get_node_or_null("UI/DialogueBox") as DialogueBox
	if _player == null or _oliver == null or _dialogue == null:
		_fail("chapter scene is missing Player, Oliver or DialogueBox")


func _physics_process(_delta: float) -> bool:
	if _player == null:
		_report()
		return true

	_frames += 1
	_step_frame += 1
	if _frames > FRAME_BUDGET:
		_fail("ran out of frames in step %d" % _step)
		_report()
		return true

	match _step:
		0: _step_settle()
		1: _step_walk_to_oliver()
		2: _step_start_conversation()
		3: _step_run_dialogue()
		4: _step_after_dialogue()
		5: _step_walk_away()
		_:
			_report()
			return true
	return false


func _step_settle() -> void:
	if _step_frame < 20:
		return
	_sensor = _player.get_node_or_null("InteractionSensor") as InteractionSensor
	_expect(_sensor != null, "player carries an InteractionSensor")
	_expect(_oliver.state == Companion.State.IDLE, "Oliver waits before being met")
	_expect(_player.input_enabled, "player starts in control")
	Input.action_press(&"move_forward")
	_next_step()


func _step_walk_to_oliver() -> void:
	var distance := _player.global_position.distance_to(_oliver.global_position)
	if distance > 2.6 and _step_frame < 900:
		return
	Input.action_release(&"move_forward")
	_expect(distance <= 2.6, "player reached Oliver, distance %.2f m" % distance)
	_note("walked %.1f m to Oliver in %.1f s" % [26.0 - distance, _step_frame / 60.0])
	_next_step()


func _step_start_conversation() -> void:
	if _step_frame < 40:
		return  # let the player brake and the sensor settle
	if _sensor != null:
		_expect(_sensor.focus != null, "Oliver is detected as interactable")
	_send_action(&"interact")
	_next_step()


func _step_run_dialogue() -> void:
	if _step_frame == 4:
		_expect(_dialogue.is_playing(), "dialogue started")
		_expect(not _player.input_enabled, "player control is handed over")
		_expect(_oliver.state == Companion.State.HELD, "Oliver holds still while talking")
		return
	if not _dialogue.is_playing():
		_note("dialogue finished after %.1f s" % (_step_frame / 60.0))
		_next_step()
		return
	# Press every so often: the first press completes a line, the next advances.
	if _step_frame % 14 == 0:
		_send_action(&"interact")


func _step_after_dialogue() -> void:
	if _step_frame < 5:
		return
	_expect(_player.input_enabled, "player is back in control")
	_expect(_oliver.state == Companion.State.FOLLOWING, "Oliver became the companion")
	_walk_away_start = _player.global_position.distance_to(_oliver.global_position)
	_oliver_start = _oliver.global_position
	Input.action_press(&"move_back")
	_next_step()


func _step_walk_away() -> void:
	if _step_frame < 240:
		return
	Input.action_release(&"move_back")
	var distance := _player.global_position.distance_to(_oliver.global_position)
	var travelled := _oliver_start.distance_to(_oliver.global_position)
	# Distance alone would also pass if Oliver simply never moved, so measure
	# how far he actually came.
	_expect(travelled > 5.0, "Oliver walked along: %.2f m travelled" % travelled)
	_expect(
		distance < _oliver.catch_up_distance,
		"Oliver stays within catch-up range: %.2f m" % distance
	)
	_expect(_oliver.is_on_floor(), "Oliver stays on the ground")
	_note("walked away: Oliver covered %.1f m and ended %.2f m behind (was %.2f m)"
		% [travelled, distance, _walk_away_start])
	_next_step()


func _next_step() -> void:
	_step += 1
	_step_frame = 0


## Pushes a real input event so `_unhandled_input` handlers see it.
## `Input.action_press` alone only changes the polled state.
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
