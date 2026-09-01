# Werkzeug: rendert das Truhen-Finale — Pad, Truhe zu, Truhe offen mit Rucksack.
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
	var szene := (load("res://chapters/hochzeit/hochzeit_chapter.tscn")
		as PackedScene).instantiate()
	szene.set_script(null)
	root.add_child(szene)
	await physics_frame
	var spieler: Node3D = szene.get_node("Player")
	spieler.set("input_enabled", false)
	var oliver: Node3D = szene.get_node("Oliver")
	if oliver.has_method("hold"):
		oliver.hold()
	var kamera: Camera3D = szene.get_node("Filmkamera")
	kamera.current = true
	await create_timer(1.0).timeout

	var truhe := TruhenFinale.new()
	truhe.ort = Vector3(0.0, 0.06, 5.2)
	szene.add_child(truhe)
	oliver.global_position = Vector3(2.6, 0.25, 2.2)
	oliver.rotation.y = -0.6
	spieler.global_position = Vector3(0.9, 0.3, 6.9)
	spieler.rotation.y = 2.6
	await create_timer(0.5).timeout

	# Anne läuft auf die Truhe zu (Verfolger-Perspektive nachgestellt).
	kamera.global_position = Vector3(0.0, 1.9, 10.5)
	kamera.look_at(Vector3(0.1, 0.6, 5.2))
	await _schuss("truhe_zu")

	# Das Zahlenpad über der Nahaufnahme.
	kamera.global_position = Vector3(-1.4, 1.35, 7.6)
	kamera.look_at(Vector3(0.2, 0.5, 5.2))
	truhe.pad_zeigen()
	await _schuss("truhe_pad")

	# Falscher Code kurz zeigen (geschüttelt wird live).
	truhe.ziffer_eingeben("1")
	await _schuss("truhe_eingabe")
	truhe.ziffer_eingeben("3")
	await create_timer(1.0).timeout

	# 42: öffnen und den schwebenden Rucksack abwarten.
	truhe.ziffer_eingeben("4")
	truhe.ziffer_eingeben("2")
	await create_timer(1.2).timeout
	await _schuss("truhe_offen")
	await create_timer(2.6).timeout
	kamera.global_position = Vector3(-1.2, 1.5, 7.8)
	kamera.look_at(Vector3(0.0, 1.2, 5.2))
	await _schuss("truhe_rucksack")
	quit(0)
