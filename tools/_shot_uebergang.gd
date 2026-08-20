# Werkzeug: rendert den Level-Übergangsbildschirm. Nur für die Entwicklung.
extends SceneTree
func _init() -> void:
	call_deferred("_los")
func _los() -> void:
	var szene: Node = load("res://chapters/berlin/berlin_chapter.tscn").instantiate()
	root.add_child(szene)
	for ausloeser in szene.get_node("Triggers").get_children():
		if ausloeser is Area3D:
			ausloeser.monitoring = false
	await create_timer(1.0).timeout
	szene._level_uebergang()
	await create_timer(6.0).timeout
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/uebergang.png")
	quit(0)
