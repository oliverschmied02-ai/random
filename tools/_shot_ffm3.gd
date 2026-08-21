# Werkzeug: rendert Siegbanner, Sieg-Dialog und Level-Übergang von Kapitel 2.
# Nur für die Entwicklung — kürzester Weg zum Sieg.
extends SceneTree

var _dialog


func _init() -> void:
	# Software-Rendering schafft keine 60 Physik-Ticks je Sekunde — mit
	# weniger Ticks läuft die Spielzeit wieder ungefähr in Echtzeit.
	Engine.physics_ticks_per_second = 30
	Engine.max_physics_steps_per_frame = 12
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
	var szene := (load("res://chapters/frankfurt/frankfurt_chapter.tscn")
		as PackedScene).instantiate()
	szene.test_schnell = true
	root.add_child(szene)
	await physics_frame
	_dialog = szene.get_node("UI/DialogueBox")
	var spieler: Node3D = szene.get_node("Player")
	var krug = szene.get_node("KrugSpiel")
	krug.intro_dauer = 0.1

	var frames := 0
	while not spieler.input_enabled and frames < 9000:
		frames += 1
		if _dialog.is_playing() and frames % 10 == 0:
			_druecke()
		await process_frame

	spieler.global_position = Vector3(300.0, 0.5, 7.7)
	frames = 0
	while krug.zustand != krug.Zustand.ZIELEN and frames < 4000:
		frames += 1
		if _dialog.is_playing() and frames % 10 == 0:
			_druecke()
		await process_frame

	krug.alle_umwerfen_test()
	frames = 0
	while krug.zustand != krug.Zustand.SIEG and frames < 900:
		frames += 1
		await process_frame
	await _warte(0.5)
	await _schuss("ffm_sieg")

	frames = 0
	while not _dialog.is_playing() and frames < 1800:
		frames += 1
		await process_frame
	await _warte(0.5)
	await _schuss("ffm_gewonnen")
	# Ab hier echte Zeiten, damit der Level-Übergang stehen bleibt.
	szene.test_schnell = false
	frames = 0
	while _dialog.is_playing() and frames < 5000:
		frames += 1
		if frames % 10 == 0:
			_druecke()
		await process_frame

	await _warte(2.8)   # Abblende 0,9 s + Titel-Auftritt 1,2 s
	await _schuss("ffm_uebergang")
	quit(0)
