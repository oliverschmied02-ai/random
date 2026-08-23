# Werkzeug: rendert die Hochzeit an der Spree. Nur für die Entwicklung.
extends SceneTree

var _szene: Node3D


func _init() -> void:
	call_deferred("_los")


func _schuss(name: String) -> void:
	await process_frame
	await process_frame
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/%s.png" % name)
	print("Schuss: ", name)


func _warte(sekunden: float) -> void:
	var uhr := create_timer(sekunden)
	while uhr.time_left > 0.0:
		await process_frame


func _los() -> void:
	_szene = (load("res://chapters/hochzeit/hochzeit_chapter.tscn")
		as PackedScene).instantiate()
	_szene.set_script(null)
	root.add_child(_szene)
	await physics_frame

	var spieler: Node3D = _szene.get_node("Player")
	var oliver: Node3D = _szene.get_node("Oliver")
	if oliver.has_method("hold"):
		oliver.hold()
	spieler.set("input_enabled", false)
	var kamera: Camera3D = _szene.get_node("Filmkamera")
	kamera.current = true
	await _warte(1.2)

	# 1. Das Postkartenbild: über das Wasser auf die Brücke.
	spieler.global_position = Vector3(-1.0, 0.3, 1.6)
	spieler.rotation.y = PI * 0.95
	oliver.global_position = Vector3(0.9, 0.25, 1.6)
	oliver.rotation.y = -PI * 0.95
	kamera.global_position = Vector3(0.0, 1.90, 6.4)
	kamera.look_at(Vector3(0.0, 1.62, 1.5))
	await _warte(0.6)
	await _schuss("hz_schlussbild")

	# 2. Weit weg vom Ufer: die ganze Brücke mit Weide und Wasser.
	kamera.global_position = Vector3(21.0, 3.4, 16.0)
	kamera.look_at(Vector3(-2.0, 8.0, -95.0))
	await _warte(0.5)
	await _schuss("hz_bruecke")

	# 3. Der Hochzeitsaufbau von hinten: Stühle, Bogen, Gäste, Wasser.
	kamera.global_position = Vector3(-2.0, 4.6, 22.0)
	kamera.look_at(Vector3(0.0, 1.2, 2.0))
	await _warte(0.5)
	await _schuss("hz_fest")

	# 4. Die Gäste von vorn.
	kamera.global_position = Vector3(0.6, 1.70, 3.4)
	kamera.look_at(Vector3(-1.0, 1.45, 9.0))
	await _warte(0.5)
	await _schuss("hz_gaeste")

	# 5. Das Spiel: Hände, Ring, ein Strauß im Flug.
	var spiel: StraussSpiel = _szene.get_node("StraussSpiel")
	spiel.intro_dauer = 0.0
	spieler.global_position = StraussSpiel.BRAUT
	spieler.rotation.y = PI
	oliver.global_position = Vector3(3.6, 0.25, 2.6)
	oliver.rotation.y = 0.35
	spiel.starten()
	await _warte(1.9)
	await _schuss("hz_spiel")
	await _warte(1.2)
	spiel.greifen()
	await _warte(0.12)
	await _schuss("hz_greifen")

	# 6. Nahaufnahme eines Straußes.
	var strauss := (load("res://assets/props/strauss.glb")
		as PackedScene).instantiate() as Node3D
	_szene.add_child(strauss)
	strauss.global_position = Vector3(0.0, 1.4, 6.0)
	strauss.rotation = Vector3(0.4, 0.9, 0.2)
	spiel.kamera.global_position = Vector3(0.0, 1.45, 6.6)
	spiel.kamera.look_at(Vector3(0.0, 1.4, 6.0))
	await _warte(0.4)
	await _schuss("hz_strauss")
	quit(0)
