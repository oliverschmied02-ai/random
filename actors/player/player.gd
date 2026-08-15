class_name Player
extends CharacterBody3D

## Third-person player controller for "Our Story".
##
## Movement is camera-relative: the stick/WASD direction is interpreted in the
## camera's frame, so "forward" always means "away from the camera".
##
## Every value that affects how the character *feels* is exported. Tune them in
## the inspector while the game is running — no code changes needed.

signal started_moving
signal stopped_moving

@export_group("Speed")
## Normal walking speed in metres per second. A relaxed human walk is ~1.4 m/s;
## games usually exaggerate this to keep exploration from dragging.
@export_range(0.5, 12.0, 0.1) var walk_speed: float = 3.4
## Speed while the sprint input is held.
@export_range(0.5, 16.0, 0.1) var sprint_speed: float = 6.2
## How quickly the character blends between walk and sprint speed (per second).
@export_range(0.5, 20.0, 0.1) var speed_change_rate: float = 6.0

@export_group("Acceleration")
## How hard the character accelerates, in m/s². Higher = more immediate.
@export_range(1.0, 80.0, 0.5) var acceleration: float = 18.0
## How hard the character brakes when input is released, in m/s².
## Keeping this clearly above `acceleration` makes stopping feel crisp
## instead of slippery.
@export_range(1.0, 80.0, 0.5) var braking: float = 26.0
## Acceleration while airborne. Low values give a natural "committed" arc.
@export_range(0.0, 40.0, 0.5) var air_acceleration: float = 5.0

@export_group("Turning")
## Base turn responsiveness. Higher = snappier rotation towards the input
## direction. This is a smoothing rate, not degrees per second.
@export_range(1.0, 40.0, 0.5) var turn_responsiveness: float = 14.0
## Turning gets slightly lazier at speed, which reads as weight rather than
## sluggishness. 1.0 = no change, 0.5 = half as responsive at full sprint.
@export_range(0.2, 1.0, 0.05) var turn_responsiveness_at_speed: float = 0.65
## Stick deflections smaller than this do not change the facing, so the
## character never spins on a tiny nudge.
@export_range(0.0, 1.0, 0.05) var turn_min_input: float = 0.15

@export_group("Ground")
## Extra downward pull applied on top of the project gravity while falling.
## Values above 1.0 shorten floaty drops.
@export_range(0.5, 3.0, 0.05) var fall_gravity_multiplier: float = 1.35
## Tallest obstacle the character steps over without breaking stride — kerbs,
## stair treads, thresholds. Godot's CharacterBody3D has no built-in step
## climbing, so anything above zero here is done by `_try_step_up()`.
## Set to 0.0 to disable step climbing entirely.
@export_range(0.0, 0.8, 0.01) var max_step_height: float = 0.4
## Speed below which the character counts as standing still (m/s).
@export_range(0.01, 1.0, 0.01) var idle_threshold: float = 0.12

## Current planar speed in m/s. Read by the debug overlay and, later, by the
## animation layer.
var current_speed: float = 0.0
## Normalised speed (0 = standing, 1 = full sprint). Useful for blending.
var speed_ratio: float = 0.0
## Last non-zero movement direction on the XZ plane, in world space.
var facing_direction: Vector3 = Vector3.FORWARD

var _target_speed: float = 0.0
var _was_moving: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)


func _ready() -> void:
	add_to_group(&"player")
	facing_direction = -global_transform.basis.z


func _physics_process(delta: float) -> void:
	var input_direction := _read_move_input()
	_update_target_speed(input_direction, delta)
	_apply_horizontal_movement(input_direction, delta)
	_apply_gravity(delta)
	_try_step_up(delta)
	move_and_slide()
	_update_facing(input_direction, delta)
	_update_state()


## Reads the movement input and rotates it into the active camera's frame,
## so pushing "up" always moves away from the camera.
func _read_move_input() -> Vector3:
	var raw := Input.get_vector(
		&"move_left", &"move_right", &"move_forward", &"move_back"
	)
	if raw == Vector2.ZERO:
		return Vector3.ZERO

	var camera := get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if camera != null:
		var basis := camera.global_transform.basis
		# Flatten onto the XZ plane so looking up or down never tilts movement.
		forward = -Vector3(basis.z.x, 0.0, basis.z.z).normalized()
		right = Vector3(basis.x.x, 0.0, basis.x.z).normalized()

	var direction := (right * raw.x + forward * -raw.y)
	# `raw` is already deadzone-filtered, but its length encodes how far the
	# stick is pushed — keep that for analogue walking, clamp for keyboard.
	return direction.limit_length(1.0)


func _update_target_speed(input_direction: Vector3, delta: float) -> void:
	var wanted := sprint_speed if Input.is_action_pressed(&"sprint") else walk_speed
	# Partial stick deflection means partial speed.
	wanted *= input_direction.length()
	_target_speed = move_toward(
		_target_speed, wanted, speed_change_rate * maxf(wanted, 1.0) * delta
	)


func _apply_horizontal_movement(input_direction: Vector3, delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var wanted := Vector3.ZERO
	if input_direction != Vector3.ZERO:
		wanted = input_direction.normalized() * _target_speed

	var rate := acceleration
	if not is_on_floor():
		rate = air_acceleration
	elif input_direction == Vector3.ZERO:
		rate = braking

	planar = planar.move_toward(wanted, rate * delta)
	velocity.x = planar.x
	velocity.z = planar.z


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		# A small downward bias keeps the body glued to slopes and stairs.
		velocity.y = -2.0
		return
	var pull := _gravity
	if velocity.y < 0.0:
		pull *= fall_gravity_multiplier
	velocity.y -= pull * delta


## Lifts the character onto low obstacles that would otherwise stop it dead.
##
## Godot's `move_and_slide()` treats a stair tread as a wall: the capsule's
## rounded bottom only clears a few centimetres, so an ordinary 18 cm step
## blocks the character completely. This probes ahead — is the path blocked at
## foot level but free one step higher, and is there something level to stand
## on up there? — and if so raises the body by exactly the step height. The
## horizontal movement itself is still left to `move_and_slide()`.
func _try_step_up(delta: float) -> void:
	if max_step_height <= 0.0 or not _is_grounded_for_stepping():
		return

	var direction := Vector3(velocity.x, 0.0, velocity.z)
	if direction.length_squared() < 0.000001:
		return
	# Probe a fixed minimum distance ahead. One frame of movement can be a few
	# millimetres — less than the physics safe margin — so probing by the raw
	# per-frame motion would never register the obstacle we are standing against.
	var motion := direction.normalized() * maxf(direction.length() * delta, 0.1)
	if not test_move(global_transform, motion):
		return  # nothing in the way

	var lift := Vector3.UP * max_step_height
	if test_move(global_transform, lift):
		return  # no headroom to step up into
	var lifted := global_transform.translated(lift)
	if test_move(lifted, motion):
		return  # still blocked one step higher — a real wall, not a step

	var landing := KinematicCollision3D.new()
	var probe_depth := max_step_height + 0.05
	if not test_move(lifted.translated(motion), Vector3.DOWN * probe_depth, landing):
		return  # nothing to land on — a gap, not a step
	if landing.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return  # the surface up there is too steep to stand on

	var rise := max_step_height + landing.get_travel().y
	if rise > 0.001:
		# A hair of extra height so the horizontal move clears the edge cleanly.
		global_position.y += rise + 0.005


## Whether the character may step up right now.
##
## `is_on_floor()` alone is not enough: a capsule that has ridden partway up a
## step edge rests on a corner, and Godot classifies that steep contact as a
## wall. The character would then be denied the very step-up that frees it and
## would hang on the edge forever. Ground within a short reach below counts too.
func _is_grounded_for_stepping() -> bool:
	if is_on_floor():
		return true
	if velocity.y > 0.1:
		return false  # rising — not a stuck-on-an-edge situation
	return test_move(global_transform, Vector3.DOWN * (max_step_height * 0.5))


func _update_facing(input_direction: Vector3, delta: float) -> void:
	if input_direction.length() < turn_min_input:
		return

	facing_direction = input_direction.normalized()
	# A node's forward axis in Godot is -Z, hence the negated components.
	var target_angle := atan2(-facing_direction.x, -facing_direction.z)
	var responsiveness := lerpf(
		turn_responsiveness,
		turn_responsiveness * turn_responsiveness_at_speed,
		speed_ratio
	)
	# Frame-rate independent smoothing: the fraction covered per second stays
	# constant regardless of how often this runs.
	var weight := 1.0 - exp(-responsiveness * delta)
	rotation.y = lerp_angle(rotation.y, target_angle, weight)


func _update_state() -> void:
	current_speed = Vector3(velocity.x, 0.0, velocity.z).length()
	speed_ratio = clampf(current_speed / maxf(sprint_speed, 0.001), 0.0, 1.0)

	var moving := current_speed > idle_threshold
	if moving != _was_moving:
		_was_moving = moving
		if moving:
			started_moving.emit()
		else:
			stopped_moving.emit()
