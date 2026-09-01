# Werkzeug: rendert die sitzenden Hochzeitsgäste auf den Stuhlreihen.
extends SceneTree

var _szene: Node


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
	_szene = (load("res://chapters/hochzeit/hochzeit_chapter.tscn")
		as PackedScene).instantiate()
	_szene.set_script(null)
	root.add_child(_szene)
	await physics_frame
	(_szene.get_node("Player") as Node3D).set("input_enabled", false)
	var oliver: Node3D = _szene.get_node("Oliver")
	if oliver.has_method("hold"):
		oliver.hold()
	var kamera: Camera3D = _szene.get_node("Filmkamera")
	kamera.current = true
	await create_timer(1.2).timeout

	# Von vorn (vom Bogen aus) auf die Reihen.
	kamera.global_position = Vector3(0.0, 1.8, 3.6)
	kamera.look_at(Vector3(0.5, 1.0, 8.4))
	await _schuss("sitzen_vorn")

	# Von der Seite, nah an der ersten Reihe.
	kamera.global_position = Vector3(-9.5, 1.5, 7.6)
	kamera.look_at(Vector3(-3.0, 0.9, 7.6))
	await _schuss("sitzen_seite")

	# Schräg von hinten über die Reihen Richtung Bogen.
	kamera.global_position = Vector3(6.5, 2.6, 12.5)
	kamera.look_at(Vector3(-1.0, 0.9, 6.0))
	await _schuss("sitzen_hinten")
	quit(0)
