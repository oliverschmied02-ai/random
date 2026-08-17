extends CanvasLayer

## Subtle prompt shown when something is interactable.
##
## Deliberately small and low-contrast: the brief asks for environmental
## composition over intrusive markers, so this is a hint, not a signpost.

@onready var _panel: PanelContainer = $Center/Panel
@onready var _key_label: Label = $Center/Panel/Margin/Row/Key
@onready var _text_label: Label = $Center/Panel/Margin/Row/Text

var _tween: Tween


func _ready() -> void:
	_panel.modulate.a = 0.0
	_key_label.text = _key_hint()
	await get_tree().process_frame
	var sensor := get_tree().get_first_node_in_group(&"interaction_sensor") as InteractionSensor
	if sensor != null:
		sensor.focus_changed.connect(_on_focus_changed)


func _on_focus_changed(interactable: Interactable) -> void:
	if interactable == null:
		_fade_to(0.0)
		return
	_text_label.text = interactable.prompt
	_fade_to(1.0)


func _fade_to(alpha: float) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, ^"modulate:a", alpha, 0.18)


## Reads the key from the input map instead of hard-coding "E", so rebinding
## the action keeps the prompt honest.
func _key_hint() -> String:
	for event in InputMap.action_get_events(&"interact"):
		if event is InputEventKey:
			var key := event as InputEventKey
			return OS.get_keycode_string(key.physical_keycode)
	return ""
