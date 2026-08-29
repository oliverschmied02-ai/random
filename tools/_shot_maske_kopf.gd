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
	var szene := (load("res://chapters/berlin/berlin_chapter.tscn") as PackedScene).instantiate()
	szene.set_script(null)
	root.add_child(szene)
	await physics_frame
	(szene.get_node("Player") as Node3D).set("input_enabled", false)
	var kamera := Camera3D.new()
	szene.add_child(kamera)
	kamera.current = true
	await create_timer(0.8).timeout
	var kulisse := szene.get_node("Kulisse")
	var p: Passant = null
	for kind in kulisse.get_children():
		if kind is Passant:
			p = kind
			break
	var sk := p.skelett_finden()
	var idx := sk.find_bone("Head")
	var kopf: Vector3 = (sk.global_transform * sk.get_bone_global_pose(idx)).origin
	print("kopf welt ", kopf)
	var vorn: Vector3 = p.global_transform.basis * Vector3(0, 0, -1)
	var seite: Vector3 = p.global_transform.basis * Vector3(1, 0, 0)
	kamera.global_position = kopf + vorn * 0.8
	kamera.look_at(kopf)
	await _schuss("kopf_vorn")
	kamera.global_position = kopf + seite * 0.8
	kamera.look_at(kopf)
	await _schuss("kopf_seite")
	quit(0)
