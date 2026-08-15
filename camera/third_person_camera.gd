class_name ThirdPersonCamera
extends Node3D

## Damped third-person follow camera.
##
## The rig is deliberately *not* parented to the player. It chases a point above
## the target with independent horizontal and vertical damping, which is what
## keeps the image calm while the character accelerates, turns or climbs stairs.
##
## Node layout:
##   ThirdPersonCamera (this node — carries the yaw)
##   └── SpringArm3D    (carries the pitch and resolves obstacles)
##       └── Camera3D
##
## Everything runs in `_physics_process` so the rig samples the player's
## transform in the same tick it was written — mixing the two loops is the
## classic source of third-person camera jitter.

@export_group("Target")
## The node to follow. Usually the player.
@export var target_path: NodePath = ^"../Player"
## How far above the target's origin the camera aims. Roughly chest height
## keeps the character low in frame with the world visible above.
@export_range(0.0, 3.0, 0.05) var height_offset: float = 1.35

@export_group("Follow")
## Horizontal chase rate. Higher = tighter, lower = more floaty.
@export_range(1.0, 30.0, 0.5) var follow_damping: float = 9.0
## Vertical chase rate. Kept below the horizontal value on purpose: a softer
## vertical response smooths out stairs and slopes.
@export_range(0.5, 30.0, 0.5) var vertical_follow_damping: float = 5.0

@export_group("Look")
@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity: float = 0.0035
@export_range(0.5, 8.0, 0.1) var gamepad_sensitivity: float = 2.6
@export var invert_y: bool = false
## Lowest pitch — negative means the camera sits high and looks down.
@export_range(-85.0, 0.0, 1.0) var pitch_min_degrees: float = -55.0
## Highest pitch — positive means the camera drops and looks up.
@export_range(0.0, 60.0, 1.0) var pitch_max_degrees: float = 22.0
## Capture the mouse on start. Escape releases it, clicking recaptures.
@export var capture_mouse: bool = true

@export_group("Auto Align")
## Slowly swings the camera behind the character while walking, so the player
## rarely has to steer it manually. Manual input always takes priority.
@export var auto_align_enabled: bool = true
## Seconds of no look input before auto-align kicks in.
@export_range(0.0, 5.0, 0.1) var auto_align_delay: float = 1.4
## How firmly it swings around. Deliberately gentle — fast auto-align is the
## fastest route to motion sickness.
@export_range(0.1, 6.0, 0.1) var auto_align_rate: float = 1.1
## Auto-align only while the character is at least this fast (m/s).
@export_range(0.0, 5.0, 0.1) var auto_align_min_speed: float = 1.0

@export_group("Feel")
## Base field of view.
@export_range(40.0, 110.0, 1.0) var base_fov: float = 68.0
## Added to the FOV at full sprint. A few degrees is enough to read as speed.
@export_range(0.0, 25.0, 0.5) var sprint_fov_boost: float = 6.0
## How quickly the FOV reacts.
@export_range(0.5, 12.0, 0.1) var fov_damping: float = 3.5

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _target: Node3D
var _yaw: float = 0.0
var _pitch: float = -14.0
var _mouse_delta: Vector2 = Vector2.ZERO
var _time_since_look_input: float = 0.0


func _ready() -> void:
	add_to_group(&"camera_rig")
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_warning("ThirdPersonCamera: no target at '%s'." % target_path)
	else:
		# Start directly behind the character instead of swinging into place.
		_yaw = _target.global_rotation.y
		global_position = _follow_point()

	rotation.y = _yaw
	spring_arm.rotation.x = deg_to_rad(_pitch)
	camera.fov = base_fov

	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += (event as InputEventMouseMotion).relative
	elif event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if capture_mouse:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_update_rotation(delta)
	_update_position(delta)
	_update_fov(delta)


func _update_rotation(delta: float) -> void:
	var yaw_change := -_mouse_delta.x * mouse_sensitivity
	var pitch_change := -_mouse_delta.y * mouse_sensitivity
	_mouse_delta = Vector2.ZERO

	var stick := Vector2(
		Input.get_axis(&"look_left", &"look_right"),
		Input.get_axis(&"look_down", &"look_up")
	)
	yaw_change -= stick.x * gamepad_sensitivity * delta
	pitch_change += stick.y * gamepad_sensitivity * delta

	if invert_y:
		pitch_change = -pitch_change

	var had_input := not is_zero_approx(yaw_change) or not is_zero_approx(pitch_change)
	_time_since_look_input = 0.0 if had_input else _time_since_look_input + delta

	_yaw += yaw_change
	_pitch = clampf(
		_pitch + rad_to_deg(pitch_change),
		pitch_min_degrees,
		pitch_max_degrees
	)

	if not had_input:
		_apply_auto_align(delta)

	rotation.y = _yaw
	spring_arm.rotation.x = deg_to_rad(_pitch)


## Gently swings the rig behind the character once the player has stopped
## steering the camera and is actually walking somewhere.
func _apply_auto_align(delta: float) -> void:
	if not auto_align_enabled or _target == null:
		return
	if _time_since_look_input < auto_align_delay:
		return
	if _target_speed() < auto_align_min_speed:
		return

	var weight := 1.0 - exp(-auto_align_rate * delta)
	_yaw = lerp_angle(_yaw, _target.global_rotation.y, weight)


func _update_position(delta: float) -> void:
	if _target == null:
		return
	var wanted := _follow_point()
	var horizontal_weight := 1.0 - exp(-follow_damping * delta)
	var vertical_weight := 1.0 - exp(-vertical_follow_damping * delta)

	global_position = Vector3(
		lerpf(global_position.x, wanted.x, horizontal_weight),
		lerpf(global_position.y, wanted.y, vertical_weight),
		lerpf(global_position.z, wanted.z, horizontal_weight)
	)


func _update_fov(delta: float) -> void:
	var wanted := base_fov + sprint_fov_boost * _target_speed_ratio()
	camera.fov = lerpf(camera.fov, wanted, 1.0 - exp(-fov_damping * delta))


func _follow_point() -> Vector3:
	return _target.global_position + Vector3.UP * height_offset


func _target_speed() -> float:
	var player := _target as Player
	return player.current_speed if player != null else 0.0


func _target_speed_ratio() -> float:
	var player := _target as Player
	return player.speed_ratio if player != null else 0.0


## Distance between camera and rig origin — the spring arm shortens this when
## something is in the way. Used by the debug overlay.
func current_distance() -> float:
	return camera.global_position.distance_to(global_position)
