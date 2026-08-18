# Werkzeug: rendert die Figur mit Mocap-Bewegung — mitten im Schritt von der
# Seite und von vorn, dazu die Stehpose. Nur für die Entwicklung (Xvfb).
extends SceneTree

var _log: FileAccess


func _init() -> void:
	call_deferred("_los")


func _merke(text: String) -> void:
	if _log == null:
		DirAccess.make_dir_recursive_absolute("user://shots")
		_log = FileAccess.open("user://shots/_fortschritt_figur.txt", FileAccess.WRITE)
	_log.store_line(text)
	_log.flush()


func _los() -> void:
	_merke("start")
	var welt := Node3D.new()
	root.add_child(welt)

	var licht := DirectionalLight3D.new()
	licht.rotation = Vector3(-0.7, 0.4, 0)
	licht.light_energy = 1.2
	welt.add_child(licht)
	var umgebung := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.58)
	env.ambient_light_energy = 1.0
	umgebung.environment = env
	welt.add_child(umgebung)

	var boden := MeshInstance3D.new()
	var platte := PlaneMesh.new()
	platte.size = Vector2(40, 40)
	boden.mesh = platte
	welt.add_child(boden)

	var traeger := Node3D.new()
	welt.add_child(traeger)
	var platzhalter := Node3D.new()
	platzhalter.name = "Platzhalter"
	var figur := Node3D.new()
	figur.set_script(load("res://systems/figur/figur.gd"))
	figur.set("modell_pfad", "res://actors/models/oliver.glb")
	figur.set("zielhoehe", 1.82)
	figur.add_child(platzhalter)
	traeger.add_child(figur)

	var kam := Camera3D.new()
	kam.fov = 45.0
	root.add_child(kam)
	kam.make_current()
	await process_frame
	_merke("aufbau fertig, treiber: " + str(figur.get("gangwerk")))

	# Gehen lassen: Physik läuft, der Träger fährt mit 3,4 m/s nach -Z.
	# Zwei Posen einfangen: einmal im vollen Ausfallschritt (Phase ~ 0,25),
	# einmal beim Überholen der Beine.
	for i in 70:
		traeger.global_position.z -= 3.4 / 60.0
		await physics_frame
	for name_phase in [["schritt_a", 12], ["schritt_b", 24]]:
		for i in int(name_phase[1]):
			traeger.global_position.z -= 3.4 / 60.0
			await physics_frame
		var stelle: Vector3 = traeger.global_position
		kam.global_position = stelle + Vector3(2.6, 1.2, -0.9)
		kam.look_at(stelle + Vector3(0, 0.95, 0))
		await process_frame
		_schuss(str(name_phase[0]) + "_seite")
		kam.global_position = stelle + Vector3(0.4, 1.3, -3.0)
		kam.look_at(stelle + Vector3(0, 1.0, 0))
		await process_frame
		_schuss(str(name_phase[0]) + "_vorn")

	# Stehen: nach dem Anhalten die Mocap-Stehpose zeigen.
	for i in 100:
		await physics_frame
	var stand: Vector3 = traeger.global_position
	kam.global_position = stand + Vector3(1.6, 1.35, -2.4)
	kam.look_at(stand + Vector3(0, 1.0, 0))
	await process_frame
	_schuss("stehen")
	_merke("fertig")
	quit(0)


func _schuss(name: String) -> void:
	var bild := root.get_viewport().get_texture().get_image()
	bild.save_png("user://shots/mocap_%s.png" % name)
	_merke("SHOT " + name)
