extends CanvasLayer

## Tuning readout for Stage 1. Toggled with F3.
##
## Numbers beat impressions when adjusting movement: "the brake takes a metre
## too long" is actionable, "feels floaty" is not.

@onready var _label: Label = $Margin/Panel/Margin/Label

var _player: Player
var _camera_rig: ThirdPersonCamera
var _peak_speed: float = 0.0


func _ready() -> void:
	# Nodes register themselves in their groups during their own _ready, which
	# has already run for scene siblings placed above this one — but not
	# necessarily for all of them, so resolve lazily in _process as well.
	_resolve_references()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _player == null or _camera_rig == null:
		_resolve_references()
	_label.text = _build_text()


func _resolve_references() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_camera_rig = get_tree().get_first_node_in_group(&"camera_rig") as ThirdPersonCamera


func _build_text() -> String:
	var lines: PackedStringArray = []
	lines.append("F3  debug overlay")
	lines.append("%d fps" % Engine.get_frames_per_second())

	if _player != null:
		_peak_speed = maxf(_peak_speed, _player.current_speed)
		lines.append("")
		lines.append("speed      %5.2f m/s" % _player.current_speed)
		lines.append("peak       %5.2f m/s" % _peak_speed)
		lines.append("ratio      %5.2f" % _player.speed_ratio)
		lines.append("grounded   %s" % ("yes" if _player.is_on_floor() else "no"))
		lines.append("pos        %.1f, %.1f, %.1f" % [
			_player.global_position.x,
			_player.global_position.y,
			_player.global_position.z,
		])

	if _camera_rig != null:
		lines.append("")
		lines.append("cam dist   %5.2f m" % _camera_rig.current_distance())
		lines.append("cam yaw    %5.0f deg" % rad_to_deg(_camera_rig.rotation.y))

	return "\n".join(lines)
