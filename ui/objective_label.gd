extends CanvasLayer

## Shows the current objective as a quiet line of text near the top of the
## screen. It fades in, sits for a while, then fades to a low opacity rather
## than disappearing entirely — present enough to glance at, quiet enough not
## to feel like a checklist.

@export_range(0.0, 1.0, 0.05) var resting_alpha: float = 0.35
@export_range(0.5, 12.0, 0.5) var full_visibility_seconds: float = 5.0

@onready var _label: Label = $Root/Label

var _tween: Tween


func _ready() -> void:
	_label.modulate.a = 0.0
	_label.text = ""


func show_objective(text: String) -> void:
	_label.text = text
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, ^"modulate:a", 1.0, 0.5)
	_tween.tween_interval(full_visibility_seconds)
	_tween.tween_property(_label, ^"modulate:a", resting_alpha, 1.2)


func clear() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, ^"modulate:a", 0.0, 0.6)
