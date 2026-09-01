# Werkzeug: rendert die Zug-Zwischenszene — Feldfahrt, Einfahrt, Begrüßung.
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
	var szene := (load("res://chapters/frankfurt/frankfurt_chapter.tscn")
		as PackedScene).instantiate()
	szene.set_script(null)
	root.add_child(szene)
	await physics_frame
	(szene.get_node("Player") as Node3D).set("input_enabled", false)
	var kamera := Camera3D.new()
	szene.add_child(kamera)
	kamera.current = true
	await create_timer(1.0).timeout

	var kulisse := szene.get_node("Kulisse")
	var zug: Node3D = kulisse.zug

	# Einstellung 1: die Fahrt durch die Felder (Zug bei x 130).
	zug.position.x = 130.0
	kamera.global_position = Vector3(160.0, 3.4, 538.0)
	kamera.look_at(zug.global_position + Vector3(10.0, 2.4, 0.0))
	await _schuss("zug_felder")

	# Einstellung 2: die Einfahrt vom Bahnsteig aus (Zug kurz vor Halt).
	zug.position.x = 262.0
	kamera.global_position = Vector3(263.0, 2.5, 505.8)
	kamera.look_at(Vector3(292.0, 1.4, 500.8))
	await _schuss("zug_einfahrt")

	# Einstellung 3: die Begrüßung — Anne und Oliver auf dem Bahnsteig.
	zug.position.x = 285.0
	var anne: Node3D = szene.get_node("Player")
	var oliver: Node3D = szene.get_node("Oliver")
	if oliver.has_method("hold"):
		oliver.hold()
	anne.global_position = Vector3(272.0, 1.45, 503.2)
	anne.rotation.y = -PI / 2.0
	oliver.global_position = Vector3(274.6, 1.4, 503.9)
	oliver.rotation.y = PI / 2.0
	for i in 20:
		await physics_frame
	kamera.global_position = Vector3(268.2, 2.15, 507.6)
	kamera.look_at(Vector3(273.2, 1.55, 502.9))
	await _schuss("zug_begruessung")

	# Einstellung 4: Totale des Bahnsteigs mit Schild und Uhr.
	kamera.global_position = Vector3(296.0, 3.2, 511.0)
	kamera.look_at(Vector3(272.0, 2.2, 502.0))
	await _schuss("zug_bahnsteig")
	quit(0)
