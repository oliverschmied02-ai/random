# Werkzeug: rendert Oliver mit der Wachsjacken-Textur. Nur für die Entwicklung.
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
	env.background_color = Color(0.45, 0.5, 0.56)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.87, 0.9)
	env.ambient_light_energy = 0.8
	umgebung.environment = env
	buehne.add_child(umgebung)
	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-40, 30, 0)
	sonne.light_energy = 1.1
	buehne.add_child(sonne)

	var figur := Figur.new()
	figur.modell_pfad = "res://actors/models/oliver.glb"
	figur.zielhoehe = 1.83
	buehne.add_child(figur)
	await create_timer(0.6).timeout

	# Jacke anziehen — derselbe Weg wie im Kapitel.
	var jacke := load("res://assets/kleidung/oliver_barbour.png") as Texture2D
	for kind in figur.modell.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		if teil == null or teil.mesh == null:
			continue
		for s in teil.mesh.get_surface_count():
			var material := teil.get_active_material(s) as BaseMaterial3D
			if material == null or material.resource_name != "outfit":
				continue
			var kopie := material.duplicate() as BaseMaterial3D
			kopie.albedo_texture = jacke
			kopie.roughness = 0.72
			teil.set_surface_override_material(s, kopie)

	var kamera := Camera3D.new()
	buehne.add_child(kamera)
	kamera.current = true
	kamera.global_position = Vector3(0.0, 1.15, -2.6)
	kamera.look_at(Vector3(0.0, 1.0, 0.0))
	await _schuss("jacke_vorn")
	kamera.global_position = Vector3(1.6, 1.3, -1.6)
	kamera.look_at(Vector3(0.0, 1.1, 0.0))
	await _schuss("jacke_seite")
	quit(0)
