# Werkzeug: rendert Anne im Hochzeitskleid — vorn, Seite, Totale.
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
	var szene := (load("res://chapters/hochzeit/hochzeit_chapter.tscn")
		as PackedScene).instantiate()
	szene.set_script(null)
	root.add_child(szene)
	await physics_frame
	var spieler: Node3D = szene.get_node("Player")
	spieler.set("input_enabled", false)
	var oliver: Node3D = szene.get_node("Oliver")
	if oliver.has_method("hold"):
		oliver.hold()
	var kamera: Camera3D = szene.get_node("Filmkamera")
	kamera.current = true
	await create_timer(1.0).timeout

	# Kleid anziehen — wie chapter_hochzeit._kleid_anziehen.
	var figur: Figur = spieler.get_node("Visual")
	var skelett := figur.skelett_finden()
	var kleid := (load("res://assets/hochzeit/kleid.glb") as PackedScene).instantiate()
	for kind in kleid.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		teil.get_parent().remove_child(teil)
		skelett.add_child(teil)
	kleid.queue_free()

	spieler.global_position = Vector3(0.0, 0.3, 5.5)
	spieler.rotation.y = 0.0
	oliver.global_position = Vector3(1.4, 0.25, 3.2)
	oliver.rotation.y = -0.5
	await create_timer(0.5).timeout

	kamera.global_position = Vector3(0.0, 1.35, 8.6)
	kamera.look_at(Vector3(0.0, 0.95, 5.5))
	await _schuss("kleid_vorn")

	kamera.global_position = Vector3(2.6, 1.3, 6.2)
	kamera.look_at(Vector3(0.0, 0.9, 5.5))
	await _schuss("kleid_seite")

	kamera.global_position = Vector3(-2.2, 1.8, 9.2)
	kamera.look_at(Vector3(0.3, 0.9, 5.0))
	await _schuss("kleid_totale")
	quit(0)
