# Werkzeug: Nahaufnahmen des Berliner Kleinzeugs — Fahrrad an der Wand,
# Pfütze auf dem Gehweg. Nur für die Entwicklung.
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
	var szene: Node = load("res://chapters/berlin/berlin_chapter.tscn").instantiate()
	szene.set_script(null)
	root.add_child(szene)
	await physics_frame
	var spieler: Node3D = szene.get_node("Player")
	spieler.set("input_enabled", false)
	spieler.global_position = Vector3(0, 0.3, 30)
	var kamera := Camera3D.new()
	root.add_child(kamera)
	kamera.current = true
	await create_timer(1.2).timeout

	# Fahrrad an der Westwand.
	kamera.global_position = Vector3(-8.2, 1.3, 4.6)
	kamera.look_at(Vector3(-11.3, 0.7, 8.0))
	await _schuss("kleinzeug_fahrrad")

	# Pfütze auf dem Gehweg, flacher Winkel — da müssen die Fenster drin liegen.
	kamera.global_position = Vector3(-9.6, 0.9, -3.4)
	kamera.look_at(Vector3(-10.2, 0.1, 12.5))
	await _schuss("kleinzeug_pfuetze")

	# Straßenblick mit beidem.
	kamera.global_position = Vector3(-6.0, 1.7, -14.0)
	kamera.look_at(Vector3(-10.8, 0.6, 8.0))
	await _schuss("kleinzeug_gehweg")
	quit(0)
