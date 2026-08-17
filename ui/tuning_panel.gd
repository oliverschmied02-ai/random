extends CanvasLayer

## In-game tuning panel, toggled with F1.
##
## Stage 1 is about how the movement *feels*, and that can only be judged by
## playing. This panel exposes the values that matter so they can be adjusted
## while running around, without opening the Godot editor. "Werte kopieren"
## puts the current settings on the clipboard so they can be pasted straight
## back into a message.
##
## Adding a slider means adding one line to ROWS — no other changes.

## Each entry is either a section heading (`{"section": "..."}`) or a slider.
## `target` is resolved by `_resolve_target()`.
const ROWS: Array[Dictionary] = [
	{"section": "Bewegung"},
	{"target": "player", "property": "walk_speed",
		"label": "Gehtempo", "min": 1.0, "max": 8.0, "step": 0.1, "unit": " m/s"},
	{"target": "player", "property": "sprint_speed",
		"label": "Sprinttempo", "min": 2.0, "max": 12.0, "step": 0.1, "unit": " m/s"},
	{"target": "player", "property": "acceleration",
		"label": "Beschleunigung", "min": 2.0, "max": 60.0, "step": 0.5, "unit": ""},
	{"target": "player", "property": "braking",
		"label": "Bremskraft", "min": 2.0, "max": 60.0, "step": 0.5, "unit": ""},
	{"target": "player", "property": "speed_change_rate",
		"label": "Tempowechsel", "min": 0.5, "max": 20.0, "step": 0.5, "unit": ""},
	{"target": "player", "property": "turn_responsiveness",
		"label": "Drehfreude", "min": 2.0, "max": 40.0, "step": 0.5, "unit": ""},
	{"target": "player", "property": "max_step_height",
		"label": "Stufenhöhe", "min": 0.0, "max": 0.8, "step": 0.01, "unit": " m"},

	{"section": "Kamera"},
	{"target": "spring_arm", "property": "spring_length",
		"label": "Abstand", "min": 1.5, "max": 10.0, "step": 0.1, "unit": " m"},
	{"target": "camera", "property": "height_offset",
		"label": "Zielhöhe", "min": 0.5, "max": 3.0, "step": 0.05, "unit": " m"},
	{"target": "camera", "property": "follow_damping",
		"label": "Folgen waagerecht", "min": 1.0, "max": 30.0, "step": 0.5, "unit": ""},
	{"target": "camera", "property": "vertical_follow_damping",
		"label": "Folgen senkrecht", "min": 0.5, "max": 30.0, "step": 0.5, "unit": ""},
	{"target": "camera", "property": "mouse_sensitivity",
		"label": "Mausempfindlichkeit", "min": 0.0005, "max": 0.02, "step": 0.0005, "unit": ""},
	{"target": "camera", "property": "base_fov",
		"label": "Blickwinkel", "min": 45.0, "max": 100.0, "step": 1.0, "unit": " Grad"},
	{"target": "camera", "property": "auto_align_rate",
		"label": "Selbstausrichtung", "min": 0.1, "max": 6.0, "step": 0.1, "unit": ""},

	{"section": "Schalter"},
	{"target": "camera", "property": "auto_align_enabled",
		"label": "Kamera richtet sich selbst aus", "toggle": true},
	{"target": "camera", "property": "invert_y",
		"label": "Maus senkrecht umkehren", "toggle": true},
]

@onready var _panel: PanelContainer = $Panel
@onready var _rows: VBoxContainer = $Panel/Margin/VBox/Scroll/RowMargin/Rows
@onready var _status: Label = $Panel/Margin/VBox/Status
@onready var _copy_button: Button = $Panel/Margin/VBox/Buttons/Copy
@onready var _reset_button: Button = $Panel/Margin/VBox/Buttons/Reset

var _player: Player
var _camera: ThirdPersonCamera
var _defaults: Array = []
var _controls: Array[Control] = []


func _ready() -> void:
	_panel.visible = false
	_copy_button.pressed.connect(_on_copy_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	# The actors register themselves in their groups during _ready, which may
	# run after this node's, so build the rows one frame later.
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_camera = get_tree().get_first_node_in_group(&"camera_rig") as ThirdPersonCamera
	_build_rows()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tuning_panel"):
		_set_open(not _panel.visible)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_panel.visible = open
	_status.text = ""
	if _camera == null:
		return
	# Hand the mouse over to the panel while it is open, and make sure the
	# camera does not grab it back on the next click.
	_camera.capture_mouse = not open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _build_rows() -> void:
	for entry in ROWS:
		if entry.has("section"):
			_rows.add_child(_make_section_label(entry["section"]))
			continue

		var target := _resolve_target(entry["target"])
		if target == null:
			continue
		_defaults.append(target.get(entry["property"]))

		if entry.get("toggle", false):
			_rows.add_child(_make_toggle(entry, target))
		else:
			_rows.add_child(_make_slider(entry, target))


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 17)
	label.add_theme_color_override(&"font_color", Color(0.99, 0.78, 0.5))
	return label


func _make_toggle(entry: Dictionary, target: Object) -> Control:
	var button := CheckButton.new()
	button.text = entry["label"]
	button.button_pressed = target.get(entry["property"])
	var property: StringName = entry["property"]
	button.toggled.connect(func(pressed: bool) -> void: target.set(property, pressed))
	_controls.append(button)
	return button


func _make_slider(entry: Dictionary, target: Object) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)

	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = entry["label"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.add_theme_color_override(&"font_color", Color(0.72, 0.84, 1.0))
	header.add_child(name_label)
	header.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = entry["min"]
	slider.max_value = entry["max"]
	slider.step = entry["step"]
	slider.value = target.get(entry["property"])

	var property: StringName = entry["property"]
	var unit: String = entry["unit"]
	var update := func(value: float) -> void:
		target.set(property, value)
		value_label.text = _format_value(value) + unit
	update.call(slider.value)
	slider.value_changed.connect(update)

	box.add_child(header)
	box.add_child(slider)
	_controls.append(slider)
	return box


func _resolve_target(key: String) -> Object:
	match key:
		"player": return _player
		"camera": return _camera
		"spring_arm": return _camera.spring_arm if _camera != null else null
	return null


func _format_value(value: float) -> String:
	if value < 0.1:
		return "%.4f" % value
	if value < 10.0:
		return "%.2f" % value
	return "%.1f" % value


## Collects the current settings as plain text, ready to paste into a message.
func _current_values_as_text() -> String:
	var lines: PackedStringArray = ["Our Story — Einstellungen"]
	for entry in ROWS:
		if entry.has("section"):
			lines.append("")
			lines.append("[%s]" % entry["section"])
			continue
		var target := _resolve_target(entry["target"])
		if target == null:
			continue
		var value: Variant = target.get(entry["property"])
		if value is bool:
			lines.append("%s = %s" % [entry["property"], "true" if value else "false"])
		else:
			lines.append("%s = %s" % [entry["property"], _format_value(value)])
	return "\n".join(lines)


func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_current_values_as_text())
	_status.text = "In die Zwischenablage kopiert — einfach einfügen."


func _on_reset_pressed() -> void:
	var index := 0
	for entry in ROWS:
		if entry.has("section"):
			continue
		var target := _resolve_target(entry["target"])
		if target == null:
			continue
		var value: Variant = _defaults[index]
		target.set(entry["property"], value)

		var control := _controls[index]
		if control is HSlider:
			(control as HSlider).value = value
		elif control is CheckButton:
			(control as CheckButton).button_pressed = value
		index += 1
	_status.text = "Auf die Startwerte zurückgesetzt."
