class_name Companion
extends CharacterBody3D

## A character that walks with the player.
##
## Deliberately not autonomous AI. It exists for storytelling, so it does three
## things well: stay near the player without crowding them, go to a marked spot
## when a scene needs it, and hold still while people are talking.
##
## Following works off a trail of the player's own footsteps rather than a
## straight line towards them. Steering directly at the player looks fine on an
## open square and falls apart the moment there is a corner: the companion
## walks into the wall the player just went around. Retracing the trail costs a
## handful of stored positions and handles every corner the route can contain,
## without a navigation mesh.
##
## A small sideways offset keeps them walking *beside* the trail rather than in
## its exact centre, so they read as a person rather than a shadow.

signal arrived

enum State {
	IDLE,      ## waiting to be activated — a person standing somewhere
	FOLLOWING, ## walking with the player
	SCRIPTED,  ## moving to a specific spot for a scene
	HELD,      ## told to stand still, e.g. during dialogue
}

@export_group("Target")
@export var target_path: NodePath = ^"../Player"

@export_group("Following")
## How far behind the player the companion aims for.
@export_range(0.5, 6.0, 0.1) var follow_distance: float = 2.2
## Sideways offset, so the companion walks beside rather than in the player's
## footsteps. Negative puts them on the other side.
@export_range(-3.0, 3.0, 0.1) var side_offset: float = 0.9
## Spacing of the recorded footsteps. Finer means corners are cut less, at the
## cost of a few more stored points.
@export_range(0.2, 3.0, 0.1) var trail_spacing: float = 0.7
## Upper bound on stored footsteps, so the trail cannot grow without limit.
@export_range(8, 256, 8) var max_trail_points: int = 96
## Closer to its target spot than this and the companion simply stops. Without
## a dead zone it shuffles constantly while the player stands still.
@export_range(0.1, 2.0, 0.05) var arrive_distance: float = 0.45
## Beyond this distance from the player the companion speeds up to catch up.
@export_range(2.0, 20.0, 0.5) var catch_up_distance: float = 5.0

@export_group("Movement")
@export_range(0.5, 10.0, 0.1) var walk_speed: float = 3.4
## Top speed while catching up. Slightly above the player's walk so being left
## behind is recoverable, below their sprint so sprinting still feels fast.
@export_range(0.5, 12.0, 0.1) var catch_up_speed: float = 5.4
@export_range(1.0, 60.0, 0.5) var acceleration: float = 14.0
@export_range(1.0, 60.0, 0.5) var braking: float = 20.0
@export_range(1.0, 40.0, 0.5) var turn_responsiveness: float = 10.0
## Höchste Stufe, die der Begleiter im Gehen nimmt — dieselbe Mechanik wie bei
## der Spielerin, sonst bleibt er an jedem Bordstein stehen.
@export_range(0.0, 0.8, 0.01) var max_step_height: float = 0.4

## Read by the animation layer later, same contract as the player.
var current_speed: float = 0.0
var speed_ratio: float = 0.0
var state: State = State.IDLE

var _target: Node3D
var _trail: PackedVector3Array = PackedVector3Array()
var _scripted_position: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)


func _ready() -> void:
	add_to_group(&"companion")
	_target = get_node_or_null(target_path) as Node3D


## Starts walking with the player. Called by the chapter script once the
## meeting has happened.
func activate() -> void:
	state = State.FOLLOWING
	# Seed the trail with where the player is standing, otherwise the companion
	# has nowhere to walk to until they have moved a step.
	_trail.clear()
	if _target != null:
		_trail.append(_target.global_position)


## Stops in place and keeps facing the player — for dialogue and cutscenes.
func hold() -> void:
	state = State.HELD


## Walks to a specific spot, then emits `arrived` and holds there.
func move_to(target_position: Vector3) -> void:
	_scripted_position = target_position
	state = State.SCRIPTED


func _physics_process(delta: float) -> void:
	if state == State.FOLLOWING:
		_record_trail()
	var desired := _desired_position()
	var move_direction := Vector3.ZERO
	var wanted_speed := walk_speed

	if desired != Vector3.ZERO:
		var to_target := desired - global_position
		to_target.y = 0.0
		if to_target.length() > arrive_distance:
			move_direction = to_target.normalized()
			wanted_speed = _speed_for_distance()
		elif state == State.SCRIPTED:
			state = State.HELD
			arrived.emit()

	_apply_movement(move_direction, wanted_speed, delta)
	_apply_gravity(delta)
	StepClimber.versuche(self, max_step_height, delta)
	move_and_slide()
	_face(move_direction, delta)

	current_speed = Vector3(velocity.x, 0.0, velocity.z).length()
	speed_ratio = clampf(current_speed / maxf(catch_up_speed, 0.001), 0.0, 1.0)


## Where the companion wants to stand. Vector3.ZERO means "stay put".
func _desired_position() -> Vector3:
	match state:
		State.FOLLOWING:
			return _next_trail_point()
		State.SCRIPTED:
			return _scripted_position
	return Vector3.ZERO


## Drops a breadcrumb whenever the player has moved far enough from the last
## one. The trail is the path the companion will retrace.
func _record_trail() -> void:
	if _target == null:
		return
	var position := _target.global_position
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(position) > trail_spacing:
		_trail.append(position)
		if _trail.size() > max_trail_points:
			_trail.remove_at(0)


## The point to walk towards: the oldest footstep still ahead of us, nudged
## sideways. Returns Vector3.ZERO when we are close enough to simply stop.
func _next_trail_point() -> Vector3:
	# Tick footsteps off generously enough to include the sideways offset. With
	# a bare `arrive_distance` the companion parks next to a footstep it can
	# never reach, the trail never advances, and it paces on the spot until the
	# trail overflows — which is exactly what it looked like.
	var reached := arrive_distance + absf(side_offset)
	while _trail.size() > 0 and global_position.distance_to(_trail[0]) < reached:
		_trail.remove_at(0)
	if _trail.is_empty():
		return Vector3.ZERO
	if _trail_length() < follow_distance:
		return Vector3.ZERO  # close enough behind — stand still instead of shuffling

	var point := _trail[0]
	# Offset sideways relative to the *trail's* direction, not to wherever the
	# companion happens to stand. Deriving it from its own bearing flips the
	# side every time it crosses the line, and it zig-zags.
	var along := (_trail[1] if _trail.size() > 1 else _target.global_position) - point
	along.y = 0.0
	if along.length() > 0.01:
		var sideways := Vector3(along.z, 0.0, -along.x).normalized()
		point += sideways * side_offset
	return point


## Walking distance from here, along the remaining footsteps, to the player.
func _trail_length() -> float:
	if _trail.is_empty() or _target == null:
		return 0.0
	var total := global_position.distance_to(_trail[0])
	for i in range(1, _trail.size()):
		total += _trail[i - 1].distance_to(_trail[i])
	return total + _trail[_trail.size() - 1].distance_to(_target.global_position)


func _speed_for_distance() -> float:
	if _target == null or state != State.FOLLOWING:
		return walk_speed
	# Measured along the trail, not as the crow flies: around a corner the
	# straight-line distance understates how far behind the companion is.
	var distance := _trail_length()
	if distance <= follow_distance:
		return walk_speed
	# Blend up to the catch-up speed as the player pulls away.
	var t := clampf(
		(distance - follow_distance) / maxf(catch_up_distance - follow_distance, 0.01),
		0.0, 1.0
	)
	return lerpf(walk_speed, catch_up_speed, t)


func _apply_movement(direction: Vector3, wanted_speed: float, delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var wanted := direction * wanted_speed
	var rate := acceleration if direction != Vector3.ZERO else braking
	planar = planar.move_toward(wanted, rate * delta)
	velocity.x = planar.x
	velocity.z = planar.z


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -2.0
		return
	velocity.y -= _gravity * delta


## Faces the direction of travel while walking, and turns towards the player
## when standing still — a companion staring into space breaks the illusion.
func _face(move_direction: Vector3, delta: float) -> void:
	var look := move_direction
	if look == Vector3.ZERO and _target != null:
		look = _target.global_position - global_position
		look.y = 0.0
		if look.length() < 0.3:
			return
		look = look.normalized()
	if look == Vector3.ZERO:
		return

	var target_angle := atan2(-look.x, -look.z)
	var weight := 1.0 - exp(-turn_responsiveness * delta)
	rotation.y = lerp_angle(rotation.y, target_angle, weight)
