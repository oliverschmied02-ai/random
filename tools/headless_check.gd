extends SceneTree

## Headless smoke test for the movement and camera rig.
##
##   godot --headless --path . --script res://tools/headless_check.gd
##
## It drives the player with simulated input and asserts that the numbers behave
## the way the tuning values promise: reaching walk and sprint speed, braking
## within a sane distance, climbing the stairs and the ramp, staying grounded,
## and keeping the camera behind the character. It cannot judge how the game
## *feels* — that still needs a human at the keyboard — but it catches
## regressions without opening the editor.

var _player: Player
var _camera: ThirdPersonCamera
var _phase: int = 0
var _phase_frame: int = 0
var _failures: PackedStringArray = []
var _notes: PackedStringArray = []
var _phase_start_position: Vector3 = Vector3.ZERO
var _phase_start_speed: float = 0.0


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/test_playground.tscn")
	root.add_child(packed.instantiate())
	_player = root.get_node_or_null("TestPlayground/Player") as Player
	_camera = root.get_node_or_null("TestPlayground/ThirdPersonCamera") as ThirdPersonCamera
	if _player == null or _camera == null:
		_fail("scene did not provide a Player and a ThirdPersonCamera")


func _physics_process(_delta: float) -> bool:
	if _player == null:
		_report()
		return true

	_phase_frame += 1
	var duration := _phase_duration(_phase)

	if _phase_frame == 1:
		_enter_phase(_phase)
	elif _phase_frame >= duration:
		_leave_phase(_phase)
		_phase += 1
		_phase_frame = 0
		if _phase >= 6:
			_report()
			return true

	_expect(_player.global_position.y > -1.0, "player did not fall through the ground")
	return false


func _phase_duration(phase: int) -> int:
	match phase:
		0: return 90    # accelerate to walking speed
		1: return 45    # release input and brake
		2: return 120   # sprint
		3: return 30    # settle after teleporting to the stairs
		4: return 160   # climb the stairs
		5: return 170   # climb the 30 degree ramp
	return 1


func _enter_phase(phase: int) -> void:
	match phase:
		0:
			Input.action_press(&"move_forward")
		1:
			Input.action_release(&"move_forward")
		2:
			Input.action_press(&"move_forward")
			Input.action_press(&"sprint")
		3:
			Input.action_release(&"move_forward")
			Input.action_release(&"sprint")
			_teleport(Vector3(-14.0, 0.15, 0.0))
		4:
			Input.action_press(&"move_forward")
		5:
			Input.action_release(&"move_forward")
			_teleport(Vector3(20.0, 0.15, 1.0))
			Input.action_press(&"move_forward")
	_phase_start_position = _player.global_position
	_phase_start_speed = _player.current_speed


func _leave_phase(phase: int) -> void:
	match phase:
		0:
			_expect_near(
				_player.current_speed, _player.walk_speed, 0.15, "walk speed"
			)
			_expect(_player.is_on_floor(), "grounded while walking")
			_expect(
				_player.global_position.z < -1.5,
				"moved forward (-Z), z=%.2f" % _player.global_position.z
			)
			_expect_camera_behind()
		1:
			var distance := _phase_start_position.distance_to(_player.global_position)
			_expect(
				_player.current_speed < 0.1,
				"came to rest, speed=%.3f m/s" % _player.current_speed
			)
			_expect(distance < 1.0, "stopping distance %.2f m" % distance)
			_note("stopping distance %.2f m from %.2f m/s"
				% [distance, _phase_start_speed])
		2:
			_expect_near(
				_player.current_speed, _player.sprint_speed, 0.2, "sprint speed"
			)
			_expect_near(_player.speed_ratio, 1.0, 0.05, "speed ratio at full sprint")
			_expect(_player.is_on_floor(), "grounded while sprinting")
			_expect_camera_behind()
			_note("walk %.2f m/s, sprint %.2f m/s"
				% [_player.walk_speed, _player.current_speed])
		4:
			_expect(
				_player.global_position.y > 1.3,
				"climbed the stairs, y=%.2f" % _player.global_position.y
			)
			_expect(_player.is_on_floor(), "grounded on the landing")
			_note("stairs: reached y=%.2f" % _player.global_position.y)
		5:
			_expect(
				_player.global_position.y > 1.5,
				"climbed the 30 degree ramp, y=%.2f" % _player.global_position.y
			)
			_note("ramp 30: reached y=%.2f" % _player.global_position.y)


func _teleport(target: Vector3) -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = target
	_camera.global_position = target + Vector3.UP * _camera.height_offset


func _expect_camera_behind() -> void:
	var to_camera := _camera.camera.global_position - _player.global_position
	var forward := -_player.global_transform.basis.z
	_expect(to_camera.normalized().dot(forward) < 0.0, "camera sits behind the player")
	var distance := _camera.current_distance()
	_expect(
		distance > 1.0 and distance <= _camera.spring_arm.spring_length + 0.01,
		"camera distance within spring arm range: %.2f m" % distance
	)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_fail(description)


func _expect_near(value: float, expected: float, tolerance: float, description: String) -> void:
	if absf(value - expected) > tolerance:
		_fail("%s — got %.3f, expected %.3f +/- %.3f"
			% [description, value, expected, tolerance])


func _fail(description: String) -> void:
	_failures.append(description)


func _note(text: String) -> void:
	_notes.append(text)


func _report() -> void:
	for note in _notes:
		print("note: ", note)
	if _failures.is_empty():
		print("headless check: OK")
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	print("headless check: %d failure(s)" % _failures.size())
	quit(1)
