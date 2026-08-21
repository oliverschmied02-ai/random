# Werkzeug: rendert die Kneipen- und Krug-Spiel-Standbilder von Kapitel 2.
# Nur für die Entwicklung — rafft die Sequenzen davor mit `test_schnell`.
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


func _los() -> void:
	_szene = (load("res://chapters/frankfurt/frankfurt_chapter.tscn")
		as PackedScene).instantiate()
	_szene.test_schnell = true
	root.add_child(_szene)
	await physics_frame
	_dialog = _szene.get_node("UI/DialogueBox")
	var spieler: Node3D = _szene.get_node("Player")
	var krug = _szene.get_node("KrugSpiel")

	# Durch die Sequenzen bis zur Steuerungs-Übergabe klicken.
	var frames := 0
	while not spieler.input_enabled and frames < 9000:
		frames += 1
		if _dialog.is_playing() and frames % 10 == 0:
			_druecke()
		await process_frame

	# Durch die Tür — Blende, Teleport, das Spiel übernimmt.
	spieler.global_position = Vector3(300.0, 0.5, 7.7)
	frames = 0
	while krug.zustand != krug.Zustand.ZIELEN and frames < 4000:
		frames += 1
		if _dialog.is_playing() and frames % 10 == 0:
			_druecke()
		await process_frame

	# Das Intro-Banner steht noch (intro_dauer 2,4 s) — erst Banner-Bild,
	# dann eines mit freiem Fadenkreuz.
	await _schuss("ffm_krugspiel_intro")
	await _warte(2.8)
	await _schuss("ffm_krugspiel")

	# Ein Wurf: Ball im Flug, dann der Einschlag.
	krug._ziel = Vector2(0.0, -0.1)
	krug._kraft = 0.5
	krug._werfen()
	await _warte(0.28)
	await _schuss("ffm_krugspiel_wurf")
	await _warte(1.4)
	await _schuss("ffm_krugspiel_treffer")

	quit(0)
