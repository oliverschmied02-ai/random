# Werkzeug: stellt alle gebackenen Requisiten in eine Reihe und rendert sie —
# einmal hell (Formkontrolle), einmal im Nachtlicht. Nur für die Entwicklung.
extends SceneTree

const PROPS := ["laterne", "auto", "bank", "ampel", "muelleimer", "poller", "litfass"]
const ABSTAND := [0.0, 3.4, 7.4, 9.6, 11.2, 12.4, 14.4]


func _init() -> void:
	call_deferred("_los")


func _los() -> void:
	var welt := Node3D.new()
	root.add_child(welt)
	var licht := DirectionalLight3D.new()
	licht.rotation = Vector3(-0.9, 0.5, 0)
	licht.light_energy = 1.4
	welt.add_child(licht)
	var umgebung := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 1.0
	umgebung.environment = env
	welt.add_child(umgebung)
	var boden := MeshInstance3D.new()
	var platte := PlaneMesh.new()
	platte.size = Vector2(60, 20)
	platte.material = StandardMaterial3D.new()
	boden.mesh = platte
	boden.position.x = 8
	welt.add_child(boden)

	for i in PROPS.size():
		var szene := load("res://assets/props/%s.glb" % PROPS[i]) as PackedScene
		if szene == null:
			print("FEHLT: ", PROPS[i])
			continue
		var teil := szene.instantiate() as Node3D
		teil.position = Vector3(ABSTAND[i], 0, 0)
		welt.add_child(teil)

	var kam := Camera3D.new()
	kam.fov = 50.0
	root.add_child(kam)
	kam.make_current()
	DirAccess.make_dir_recursive_absolute("user://shots")

	kam.global_position = Vector3(7.2, 2.6, 10.5)
	kam.look_at(Vector3(7.2, 1.6, 0))
	for i in 4:
		await process_frame
	var bild := root.get_viewport().get_texture().get_image()
	bild.save_png("user://shots/props_reihe.png")

	kam.global_position = Vector3(1.6, 1.4, 4.4)
	kam.look_at(Vector3(1.8, 1.0, 0))
	for i in 3:
		await process_frame
	bild = root.get_viewport().get_texture().get_image()
	bild.save_png("user://shots/props_nah.png")
	print("SHOTS fertig")
	quit(0)
