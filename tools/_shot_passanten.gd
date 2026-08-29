# Werkzeug: rendert die Passanten in Kapitel 1 — Griffweite und Totale.
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
	# Zwei Sekunden gehen lassen, damit das Gangbild voll ausgeprägt ist.
	await create_timer(2.0).timeout

	var kulisse := szene.get_node("Kulisse")
	var leute: Array = []
	for kind in kulisse.get_children():
		if kind is Passant:
			leute.append(kind)
	print("Passanten: ", leute.size())

	# Nahaufnahme des ersten Passanten (Startstraße, Maske sichtbar).
	if leute.size() > 0:
		var p: Node3D = leute[0]
		var vorn: Vector3 = p.global_transform.basis * Vector3(0, 0, -1)
		kamera.global_position = p.global_position + vorn * 2.4 + Vector3(0.5, 1.62, 0)
		kamera.look_at(p.global_position + Vector3(0, 1.5, 0))
		await _schuss("passant_nah")
		# Noch näher ans Gesicht für den Maskensitz.
		kamera.global_position = p.global_position + vorn * 1.1 + Vector3(0.2, 1.66, 0)
		kamera.look_at(p.global_position + Vector3(0, 1.58, 0))
		await _schuss("passant_maske")
		# Von der Seite: Gangbild.
		var seite: Vector3 = p.global_transform.basis * Vector3(1, 0, 0)
		kamera.global_position = p.global_position + seite * 3.0 + Vector3(0, 1.4, 0)
		kamera.look_at(p.global_position + Vector3(0, 1.0, 0))
		await _schuss("passant_gang")

	# Straßentotale mit zwei Passanten (Startstraße Richtung Süden).
	kamera.global_position = Vector3(0.0, 2.1, 14.0)
	kamera.look_at(Vector3(-2.0, 1.2, -20.0))
	await _schuss("passanten_strasse")

	# Die Passantin am Korridor zum Café.
	if leute.size() > 3:
		var p2: Node3D = leute[3]
		var vorn2: Vector3 = p2.global_transform.basis * Vector3(0, 0, -1)
		kamera.global_position = p2.global_position + vorn2 * 2.6 + Vector3(-0.4, 1.6, 0)
		kamera.look_at(p2.global_position + Vector3(0, 1.4, 0))
		await _schuss("passant_korridor")
	quit(0)
