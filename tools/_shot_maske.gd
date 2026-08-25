# Werkzeug: rendert die neue FFP2-Maske nah aus drei Blickwinkeln.
# Nur für die Entwicklung.
extends SceneTree


func _init() -> void:
	call_deferred("_los")


func _schuss(name: String) -> void:
	await process_frame
	await process_frame
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/%s.png" % name)
	print("Schuss: ", name)


func _los() -> void:
	var buehne := Node3D.new()
	root.add_child(buehne)

	var umgebung := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.88)
	env.ambient_light_energy = 0.7
	umgebung.environment = env
	buehne.add_child(umgebung)

	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-42, 32, 0)
	sonne.light_energy = 1.2
	buehne.add_child(sonne)

	var maske := (load("res://assets/props/atemmaske.glb")
		as PackedScene).instantiate() as Node3D
	maske.scale = Vector3.ONE * 3.6
	buehne.add_child(maske)

	var kamera := Camera3D.new()
	buehne.add_child(kamera)
	kamera.current = true

	# 1. Frontal, leicht von oben — wie im Spiel beim Fallen.
	kamera.global_position = Vector3(0.0, 0.25, 1.15)
	kamera.look_at(Vector3.ZERO)
	await _schuss("maske_front")

	# 2. Dreiviertel — Naht, Tiefe und Ohrschlaufe.
	kamera.global_position = Vector3(0.85, 0.35, 0.85)
	kamera.look_at(Vector3.ZERO)
	await _schuss("maske_seite")

	# 3. Taumelnd wie im Fall.
	maske.rotation = Vector3(0.5, 2.4, 0.3)
	kamera.global_position = Vector3(-0.6, -0.3, 1.0)
	kamera.look_at(Vector3.ZERO)
	await _schuss("maske_taumel")
	quit(0)
