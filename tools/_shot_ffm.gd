# Werkzeug: rendert Standbilder aller Sequenzen von Kapitel 2 (Frankfurt).
# Nur für die Entwicklung — spielt das Kapitel in Echtzeit durch und
# drückt sich selbst durch die Dialoge.
extends SceneTree

var _szene: Node3D
var _dialog


func _init() -> void:
	call_deferred("_los")


func _schuss(name: String) -> void:
	await process_frame
	await process_frame
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/%s.png" % name)
	print("Schuss: ", name)


func _druecke() -> void:
	var druck := InputEventAction.new()
	druck.action = &"interact"
	druck.pressed = true
	Input.parse_input_event(druck)
	var los := InputEventAction.new()
	los.action = &"interact"
	los.pressed = false
	Input.parse_input_event(los)


func _warte(sekunden: float) -> void:
	var uhr := create_timer(sekunden)
	while uhr.time_left > 0.0:
		await process_frame


## Wartet, bis ein Dialog läuft, knipst optional, klickt ihn dann durch.
func _dialog_durch(schuss: String = "", vorlauf := 0.9) -> void:
	var frames := 0
	while not _dialog.is_playing() and frames < 3600:
		frames += 1
		await process_frame
	await _warte(vorlauf)
	if schuss != "":
		await _schuss(schuss)
	frames = 0
	while _dialog.is_playing() and frames < 3600:
		frames += 1
		if frames % 30 == 0:
			_druecke()
		await process_frame


func _los() -> void:
	_szene = (load("res://chapters/frankfurt/frankfurt_chapter.tscn")
		as PackedScene).instantiate()
	_szene.test_schnell = false
	root.add_child(_szene)
	await physics_frame
	_dialog = _szene.get_node("UI/DialogueBox")
	var spieler: Node3D = _szene.get_node("Player")
	var oliver = _szene.get_node("Oliver")
	var krug = _szene.get_node("KrugSpiel")

	# 1. Kapitelkarte und Abschied.
	await _warte(1.6)
	await _schuss("ffm_karte")
	await _dialog_durch("ffm_abschied", 1.2)

	# 2. Autobahn: Mitfahrt-Einstellung, dann das feste Schild.
	var frames := 0
	while not _szene._fahrt_laeuft and frames < 3600:
		frames += 1
		await process_frame
	await _warte(3.2)
	await _schuss("ffm_autobahn")
	await _dialog_durch()   # das Telefonat
	await _warte(2.2)       # Einstellung 2: der LKW zieht am Schild vorbei
	await _schuss("ffm_autobahn_schild")

	# 3. Ankunft in Sachsenhausen.
	await _dialog_durch("ffm_ankunft", 1.2)
	frames = 0
	while not spieler.input_enabled and frames < 1200:
		frames += 1
		await process_frame

	# 4. Zwei gestellte Straßenbilder: Gasse und Kneipenfront.
	oliver.hold()
	spieler.global_position = Vector3(248.0, 0.3, 0.6)
	spieler.rotation.y = -PI / 2.0
	oliver.global_position = Vector3(246.2, 0.25, -0.6)
	oliver.rotation.y = -PI / 2.0
	_szene._film(Vector3(236.0, 1.8, -4.2), Vector3(252.0, 1.4, 2.0))
	await _warte(0.6)
	await _schuss("ffm_sachsenhausen")
	spieler.global_position = Vector3(298.4, 0.3, 3.2)
	spieler.rotation.y = 0.0
	oliver.global_position = Vector3(296.8, 0.25, 2.2)
	oliver.rotation.y = 0.0
	_szene._film(Vector3(293.0, 1.7, -1.6), Vector3(300.0, 2.6, 8.2))
	await _warte(0.6)
	await _schuss("ffm_kneipe_front")

	quit(0)
