# Werkzeug: rendert die Kenney-Fahrzeuge als Parade. Nur Entwicklung.
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
	var buehne := Node3D.new()
	root.add_child(buehne)
	var umgebung := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.6, 0.66)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.87, 0.9)
	env.ambient_light_energy = 0.85
	umgebung.environment = env
	buehne.add_child(umgebung)
	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-45, 35, 0)
	sonne.light_energy = 1.2
	sonne.shadow_enabled = true
	buehne.add_child(sonne)
	var boden := MeshInstance3D.new()
	var platte := BoxMesh.new()
	platte.size = Vector3(60, 0.1, 30)
	var grau := StandardMaterial3D.new()
	grau.albedo_color = Color(0.4, 0.41, 0.43)
	platte.material = grau
	boden.mesh = platte
	buehne.add_child(boden)
	boden.position.y = -0.05

	var namen := ["sedan", "sedanSports", "suv", "suvLuxury",
		"hatchbackSports", "van", "delivery", "truck"]
	for i in namen.size():
		var wagen := (load("res://assets/props/kenney/%s.glb" % namen[i])
			as PackedScene).instantiate() as Node3D
		buehne.add_child(wagen)
		wagen.scale = Vector3.ONE * 1.75
		wagen.position = Vector3((i - 3.5) * 4.0, 0, 0)
		wagen.rotation.y = 0.5

	var kamera := Camera3D.new()
	buehne.add_child(kamera)
	kamera.current = true
	kamera.global_position = Vector3(-6.0, 4.0, -14.0)
	kamera.look_at(Vector3(0, 0.8, 0.5))
	await _schuss("kenney_parade")
	quit(0)
