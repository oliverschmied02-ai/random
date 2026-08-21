# Werkzeug: rendert die Kneipenstube und den Wurftisch, gestellt.
# Nur für die Entwicklung — Szene ohne Kapitelskript, alles von Hand
# aufgebaut, damit kein Ablauf abgewartet werden muss.
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

	var spieler: Node3D = _szene.get_node("Player")
	var oliver: Node3D = _szene.get_node("Oliver")
	if oliver.has_method("hold"):
		oliver.hold()
	spieler.set("input_enabled", false)
	spieler.global_position = Vector3(399.2, 0.3, -98.4)
	spieler.rotation.y = -PI / 2.0
	oliver.global_position = Vector3(401.6, 0.25, -98.4)
	oliver.rotation.y = PI / 2.0

	var krug = _szene.get_node("KrugSpiel")
	krug.intro_dauer = 0.0
	krug.starten()
	await _warte(2.0)

	# 1. Der Wurftisch aus der Spielperspektive (die Spielkamera).
	await _schuss("stube_spiel")

	# 2. Ein Wurf mit Treffer: Staub, Kamerastoß, Zuruf.
	krug._ziel = krug.zielvorschlag()
	krug._kraft = 0.5
	krug._werfen()
	await _warte(0.42)
	await _schuss("stube_treffer")
	await _warte(0.9)
	await _schuss("stube_nach_treffer")

	# 3. Der Schankraum mit Wirt, aus dem Gastraum gesehen.
	var kamera: Camera3D = _szene.get_node("Filmkamera")
	kamera.global_position = Vector3(399.6, 1.65, -99.4)
	kamera.look_at(Vector3(395.6, 1.25, -96.6))
	kamera.current = true
	await _warte(0.6)
	await _schuss("stube_tresen")

	# 4. Weitwinkel-Blick in die ganze Stube.
	kamera.global_position = Vector3(405.4, 2.30, -96.4)
	kamera.look_at(Vector3(398.0, 1.10, -102.0))
	await _warte(0.5)
	await _schuss("stube_gesamt")

	# 5. Nahaufnahme Tisch mit Bembel und Gerippten.
	kamera.global_position = Vector3(398.3, 1.30, -100.9)
	kamera.look_at(Vector3(397.6, 0.90, -101.8))
	await _warte(0.5)
	await _schuss("stube_tisch")
	quit(0)
