# Werkzeug: rendert die geparkten Kenney-Autos in der Berliner Nacht.
extends SceneTree


func _schuss(name: String) -> void:
	await process_frame
	await process_frame
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/%s.png" % name)
	print("Schuss: ", name)


func _init() -> void:
	call_deferred("_los")


func _los() -> void:
	var szene := (load("res://chapters/berlin/berlin_chapter.tscn")
		as PackedScene).instantiate()
	szene.set_script(null)
	root.add_child(szene)
	await physics_frame
	(szene.get_node("Player") as Node3D).set("input_enabled", false)
	var kamera := Camera3D.new()
	szene.add_child(kamera)
	kamera.current = true
	await create_timer(1.0).timeout

	# Die Reihe an der Startstraße: drei Wagen bei x -6.5, z 2 / -14 / -31.
	kamera.global_position = Vector3(-1.0, 1.7, 12.0)
	kamera.look_at(Vector3(-6.5, 0.8, -16.0))
	await _schuss("berlin_autos")

	# Nahaufnahme des Taxis (viertes Auto, x 66.6, z -96).
	kamera.global_position = Vector3(62.0, 1.6, -91.5)
	kamera.look_at(Vector3(66.6, 0.7, -96.0))
	await _schuss("berlin_taxi")
	quit(0)
