# Werkzeug: rendert Standbilder der Gasse in Sachsenhausen, gestellt.
# Nur für die Entwicklung — lädt die Szene ohne Kapitelskript.
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


func _los() -> void:
	_szene = (load("res://chapters/frankfurt/frankfurt_chapter.tscn")
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

	# Vier Blicke: Gasse von Westen, Fachwerk nah, Kneipenfront mit
	# Bestuhlung, und ein Passant am Gehweg.
	var bilder: Array = [
		["gasse_west", Vector3(232.0, 1.8, -4.0), Vector3(258.0, 1.6, 1.5),
			Vector3(248.0, 0.3, 0.6), -PI / 2.0, Vector3(246.2, 0.25, -0.6)],
		["gasse_fachwerk", Vector3(268.0, 2.2, 1.0), Vector3(258.0, 4.0, 8.2),
			Vector3(264.0, 0.3, 2.0), PI, Vector3(263.0, 0.25, 1.0)],
		["gasse_kneipe", Vector3(292.0, 1.7, -1.0), Vector3(301.0, 2.4, 8.2),
			Vector3(298.4, 0.3, 3.2), 0.0, Vector3(296.8, 0.25, 2.2)],
		["gasse_passant", Vector3(238.0, 1.7, 2.0), Vector3(245.0, 1.5, 7.2),
			Vector3(240.0, 0.3, 1.0), 0.6, Vector3(239.0, 0.25, 0.2)],
	]
	for bild: Array in bilder:
		spieler.global_position = bild[3]
		spieler.rotation.y = bild[4]
		oliver.global_position = bild[5]
		oliver.rotation.y = bild[4]
		kamera.global_position = bild[1]
		kamera.look_at(bild[2])
		var uhr := create_timer(0.7)
		while uhr.time_left > 0.0:
			await process_frame
		await _schuss(bild[0])
	quit(0)
