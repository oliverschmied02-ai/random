class_name InteractionSensor
extends Area3D

## Sits on the player and keeps track of what is currently interactable.
##
## When several things are in range it picks the one the player is most
## plausibly looking at: distance matters, but so does whether the thing is in
## front of the character. Purely nearest-wins feels wrong when walking past a
## row of props.

signal focus_changed(interactable: Interactable)

## How much being in front counts relative to being close. 0 = nearest wins.
@export_range(0.0, 5.0, 0.1) var facing_weight: float = 1.5
## The body whose facing is used for the scoring. Defaults to the parent.
@export var body_path: NodePath = ^".."

var focus: Interactable

var _candidates: Array[Interactable] = []
var _body: Node3D


func _ready() -> void:
	add_to_group(&"interaction_sensor")
	_body = get_node_or_null(body_path) as Node3D
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _process(_delta: float) -> void:
	# While a scripted sequence has the controls, nothing is interactable —
	# this keeps the prompt hidden and stops a second press during dialogue
	# from re-triggering whatever started it.
	var best: Interactable = null
	if _accepts_input():
		best = _best_candidate()
	if best != focus:
		focus = best
		focus_changed.emit(focus)


func _unhandled_input(event: InputEvent) -> void:
	if focus == null or not _accepts_input():
		return
	if not event.is_action_pressed(&"interact"):
		return
	var interactor: Node3D = _body if _body != null else self
	focus.interact(interactor)
	get_viewport().set_input_as_handled()


## False while a cutscene holds the player's controls.
func _accepts_input() -> bool:
	var player := _body as Player
	return player == null or player.input_enabled


func _on_area_entered(area: Area3D) -> void:
	var interactable := area as Interactable
	if interactable != null and not _candidates.has(interactable):
		_candidates.append(interactable)


func _on_area_exited(area: Area3D) -> void:
	var interactable := area as Interactable
	if interactable != null:
		_candidates.erase(interactable)


func _best_candidate() -> Interactable:
	var best: Interactable = null
	var best_score := -INF
	var origin := global_position
	var forward := -global_transform.basis.z
	if _body != null:
		origin = _body.global_position
		forward = -_body.global_transform.basis.z

	for candidate in _candidates:
		if not is_instance_valid(candidate) or not candidate.enabled:
			continue
		var to_candidate := candidate.global_position - origin
		var distance := to_candidate.length()
		# Higher is better: close scores high, and being in front adds to it.
		var score := -distance
		if distance > 0.01:
			score += forward.dot(to_candidate / distance) * facing_weight
		if score > best_score:
			best_score = score
			best = candidate

	return best
