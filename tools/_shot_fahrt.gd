# Werkzeug: rendert das LKW-Fahrspiel (Kabine, Verkehr, Spurwechsel).
# Nur für die Entwicklung.
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
	_szene = (load("res://chapters/frankfurt/frankfurt_chapter.tscn")
		as PackedScene).instantiate()
	_szene.set_script(null)
	root.add_child(_szene)
	await physics_frame
	(_szene.get_node("Player") as Node3D).set("input_enabled", false)

	var kulisse: Node = _szene.get_node("Kulisse")
	var lkw: Node3D = kulisse.lkw_fahrt
	lkw.position.x = -120.0
	var kamera: Camera3D = _szene.get_node("Filmkamera")
	kamera.current = true

	var spiel := LkwSpiel.new()
	_szene.add_child(spiel)
	spiel.starten(lkw, kamera, kulisse, null)
	await _warte(1.6)

	# 1. Kabinenblick mit Banner und Verkehr voraus.
	await _schuss("fahrt_kabine")

	# 2. Spurwechsel nach links — Kamera neigt sich mit.
	Input.action_press(&"move_left")
	await _warte(1.1)
	await _schuss("fahrt_spurwechsel")
	Input.action_release(&"move_left")

	# 3. Von außen: LKW zwischen den Schleichern, Gegenverkehr drüben.
	await _warte(1.0)
	spiel.set_process(false)
	kamera.global_position = lkw.global_position + Vector3(6.0, 3.4, 11.0)
	kamera.look_at(lkw.global_position + Vector3(10.0, 1.2, 0.0))
	await _schuss("fahrt_aussen")
	quit(0)
