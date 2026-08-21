# Werkzeug: rendert die Autobahn-Einstellungen von Kapitel 2 — Mitfahrt,
# Kabine, Brücke. Nur für die Entwicklung.
extends SceneTree

var _szene: Node3D
var _kulisse: Node3D
var _lkw: Node3D


func _init() -> void:
	call_deferred("_los")


func _schuss(name: String) -> void:
	await process_frame
	await process_frame
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/%s.png" % name)
	print("Schuss: ", name)


## Fährt den LKW eine Strecke weit, mit drehenden Rädern und Federung.
func _fahren(sekunden: float, tempo: float) -> void:
	_kulisse.lkw_tempo = tempo
	var uhr := 0.0
	while uhr < sekunden:
		var d: float = root.get_process_delta_time()
		uhr += d
		_lkw.position.x += tempo * d
		await process_frame


func _los() -> void:
	_szene = (load("res://chapters/frankfurt/frankfurt_chapter.tscn")
		as PackedScene).instantiate()
	_szene.set_script(null)
	root.add_child(_szene)
	await physics_frame
	_kulisse = _szene.get_node("Kulisse")
	_lkw = _kulisse.lkw_fahrt
	var kamera: Camera3D = _szene.get_node("Filmkamera")
	kamera.current = true
	var spieler: Node3D = _szene.get_node("Player")
	spieler.set("input_enabled", false)
	spieler.global_position = Vector3(0, 0.3, -4.0)

	# 1. Mitfahrt von der Seite — Räder drehen, Karosserie wippt.
	_lkw.position.x = 20.0
	await _fahren(0.8, 21.0)
	kamera.global_position = _lkw.global_position + Vector3(-5.0, 2.6, 8.5)
	kamera.look_at(_lkw.global_position + Vector3(2.0, 1.4, 0.0))
	await _schuss("bahn_mitfahrt")

	# 2. Aus der Kabine, hinter dem Lenkrad.
	kamera.global_position = _lkw.to_global(Vector3(-0.52, 2.16, 3.05))
	kamera.look_at(_lkw.to_global(Vector3(-0.15, 0.60, 45.0)))
	await _schuss("bahn_kabine")

	# 3. Kurz vor der Brücke (x = 78) aus der Kabine.
	_lkw.position.x = 58.0
	await _fahren(0.4, 21.0)
	kamera.global_position = _lkw.to_global(Vector3(-0.52, 2.16, 3.05))
	kamera.look_at(_lkw.to_global(Vector3(-0.15, 1.10, 45.0)))
	await _schuss("bahn_bruecke_kabine")

	# 4. Feste Einstellung: der LKW zieht unter der Brücke durch.
	_lkw.position.x = 62.0
	await _fahren(0.4, 21.0)
	kamera.global_position = Vector3(96.0, 2.2, 308.0)
	kamera.look_at(Vector3(70.0, 3.4, 300.0))
	await _schuss("bahn_bruecke")

	# 5. Nahaufnahme der Räder in Fahrt.
	kamera.global_position = _lkw.global_position + Vector3(2.6, 1.1, 4.2)
	kamera.look_at(_lkw.global_position + Vector3(1.0, 0.5, 0.4))
	await _schuss("bahn_raeder")
	quit(0)
