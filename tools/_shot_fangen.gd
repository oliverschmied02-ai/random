# Werkzeug: rendert das Brautstrauß-Fangen — offene Hände, Griff, Flugkurve.
extends SceneTree

var _szene: Node


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
	_szene = (load("res://chapters/hochzeit/hochzeit_chapter.tscn")
		as PackedScene).instantiate()
	_szene.set_script(null)
	root.add_child(_szene)
	await physics_frame
	(_szene.get_node("Player") as Node3D).set("input_enabled", false)
	var oliver: Node3D = _szene.get_node("Oliver")
	if oliver.has_method("hold"):
		oliver.hold()
	var spiel: StraussSpiel = _szene.get_node("StraussSpiel")
	spiel.intro_dauer = 0.0
	await create_timer(1.0).timeout
	spiel.starten()
	await create_timer(0.8).timeout

	# Offene Hände mit anfliegendem Strauß (mitten im Flug).
	var uhr := 0.0
	while spiel._fliegende.is_empty() and uhr < 6.0:
		uhr += 0.1
		await create_timer(0.1).timeout
	if not spiel._fliegende.is_empty():
		var flug: Dictionary = spiel._fliegende[0]
		while float(flug["uhr"]) / float(flug["dauer"]) < 0.55:
			await process_frame
	await _schuss("fangen_offen")

	# Zugreifende Hände.
	spiel.greifen()
	await _schuss("fangen_griff")
	await create_timer(1.2).timeout
	await _schuss("fangen_weiter")
	quit(0)
