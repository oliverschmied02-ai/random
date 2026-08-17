class_name Companion
extends CharacterBody3D

## A character that walks with the player.
##
## Deliberately not autonomous AI. It exists for storytelling, so it does three
## things well: stay near the player without crowding them, go to a marked spot
## when a scene needs it, and hold still while people are talking.
##
## The follow target is a point *beside and behind* the player rather than the
## player themselves. Steering towards the player directly is what makes
## companions bump into you and shove you off course; aiming past their
## shoulder keeps them in frame and out of the way.

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
@export_range(-3.0, 3.0, 0.1) var side_offset: float = 1.0
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

## Read by the animation layer later, same contract as the player.
var current_speed: float = 0.0
var speed_ratio: float = 0.0
var state: State = State.IDLE

var _target: Node3D
var _scripted_position: Vector3 = Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)


func _ready() -> void:
	add_to_group(&"companion")
	_target = get_node_or_null(target_path) as Node3D


## Starts walking with the player. Called by the chapter script once the
## meeting has happened.
func activate() -> void:
	state = State.FOLLOWING


## Stops in place and keeps facing the player — for dialogue and cutscenes.
func hold() -> void:
	state = State.HELD


## Walks to a specific spot, then emits `arrived` and holds there.
func move_to(target_position: Vector3) -> void:
	_scripted_position = target_position
	state = State.SCRIPTED


func _physics_process(delta: float) -> void:
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
	move_and_slide()
	_face(move_direction, delta)

	current_speed = Vector3(velocity.x, 0.0, velocity.z).length()
	speed_ratio = clampf(current_speed / maxf(catch_up_speed, 0.001), 0.0, 1.0)


## Where the companion wants to stand. Vector3.ZERO means "stay put".
func _desired_position() -> Vector3:
	match state:
		State.FOLLOWING:
			if _target == null:
				return Vector3.ZERO
			var basis := _target.global_transform.basis
			var back := Vector3(basis.z.x, 0.0, basis.z.z).normalized()
			var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
			return _target.global_position + back * follow_distance + right * side_offset
		State.SCRIPTED:
			return _scripted_position
	return Vector3.ZERO


func _speed_for_distance() -> float:
	if _target == null or state != State.FOLLOWING:
		return walk_speed
	var distance := global_position.distance_to(_target.global_position)
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
