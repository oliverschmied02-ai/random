# Werkzeug: rendert einen aufbereiteten Mixamo-Gast als Figur.
# Aufruf mit GAST=<n> in der Umgebung, sonst Gast 1. Nur für die Entwicklung.
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
	var nummer := OS.get_environment("GAST")
	if nummer.is_empty():
		nummer = "1"
	var buehne := Node3D.new()
	root.add_child(buehne)

	var umgebung := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.87, 0.9)
	env.ambient_light_energy = 0.8
	umgebung.environment = env
	buehne.add_child(umgebung)

	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-40, 30, 0)
	sonne.light_energy = 1.1
	buehne.add_child(sonne)

	var gast := Figur.new()
	gast.modell_pfad = "res://actors/models/gast_%s.glb" % nummer
	gast.zielhoehe = 1.78
	gast.mocap_aktiv = false
	gast.gangwerk_aktiv = false
	buehne.add_child(gast)

	var kamera := Camera3D.new()
	buehne.add_child(kamera)
	kamera.current = true
	await create_timer(0.8).timeout

	# Ganzkörper von vorn (Figur dreht das Modell selbst um 180°).
	kamera.global_position = Vector3(0.0, 1.05, -2.9)
	kamera.look_at(Vector3(0.0, 0.95, 0.0))
	await _schuss("gast_%s_ganz" % nummer)

	# Kopf nah — Haare, Wimpern, Gesicht.
	kamera.global_position = Vector3(0.35, 1.66, -0.75)
	kamera.look_at(Vector3(0.0, 1.60, 0.0))
	await _schuss("gast_%s_kopf" % nummer)
	quit(0)
