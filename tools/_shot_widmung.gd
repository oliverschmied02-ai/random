# Werkzeug: rendert die Widmung. Nur für die Entwicklung — läuft unter Xvfb.
extends SceneTree
func _init() -> void:
	call_deferred("_los")
func _los() -> void:
	var szene: Control = (load("res://ui/widmung.tscn") as PackedScene).instantiate()
	root.add_child(szene)
	await create_timer(7.5).timeout
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/widmung.png")
	quit(0)
