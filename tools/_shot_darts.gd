# Werkzeug: rendert Standbilder des Dart-Minispiels (Einblendung, steckende
# Spritzen). Nur für die Entwicklung — läuft unter Xvfb, nie im Spiel.
extends SceneTree

var _log: FileAccess


func _init() -> void:
	call_deferred("_los")


func _merke(text: String) -> void:
	if _log == null:
		DirAccess.make_dir_recursive_absolute("user://shots")
		_log = FileAccess.open("user://shots/_fortschritt.txt", FileAccess.WRITE)
	_log.store_line("%d ms  %s" % [Time.get_ticks_msec(), text])
	_log.flush()


func _los() -> void:
	_merke("start")
	var szene: Node = load("res://chapters/berlin/berlin_chapter.tscn").instantiate()
	root.add_child(szene)
	_merke("szene steht")
	for ausloeser in szene.get_node("Triggers").get_children():
		if ausloeser is Area3D:
			ausloeser.monitoring = false
	await process_frame
	var karte := szene.get_node_or_null("UI/ChapterCard")
	var frist := 0
	while karte and karte.visible and frist < 200:
		await process_frame
		frist += 1
		if frist % 10 == 0:
			_merke("warte auf karte, bild %d" % frist)
	_merke("karte weg nach %d bildern" % frist)
	# „UI" ist ein schlichter Node ohne `visible` — die Kinder ausblenden.
	for name in ["UI", "HUD", "Debug"]:
		var schicht := szene.get_node_or_null(name)
		if schicht == null:
			continue
		if "visible" in schicht:
			schicht.visible = false
			continue
		for kind in schicht.get_children():
			if "visible" in kind:
				kind.visible = false
	_merke("oberflaeche versteckt")

	# Zwei Blicke in den Verkaufsraum: Verkäufer, Spieß, Tresen.
	var frei := Camera3D.new()
	frei.fov = 55.0
	root.add_child(frei)
	frei.make_current()
	frei.global_position = Vector3(124.6, 1.7, -234.6)
	frei.look_at(Vector3(121.7, 1.35, -238.2))
	for i in 2:
		await process_frame
	_schuss("bude_innen")
	frei.global_position = Vector3(123.6, 1.6, -236.4)
	frei.look_at(Vector3(121.2, 1.5, -238.4))
	for i in 2:
		await process_frame
	_schuss("bude_nah")
	frei.queue_free()

	var darts: DartsGame = szene.get_node("DartsGame")
	_merke("darts gefunden")
	darts.kamerafahrt = 0.0
	darts.starten()
	_merke("darts gestartet")
	for i in 2:
		await process_frame
	_schuss("darts_intro")

	# Drei Würfe, damit Spritzen in der Scheibe stecken.
	for wurf in [Vector2(0, 0), Vector2(0.15, 0.1), Vector2(-0.13, -0.07)]:
		darts._ziel = wurf
		darts._kraft = 0.5
		darts._werfen()
		_merke("wurf %s" % wurf)
		for i in 6:
			await process_frame

	darts._hud.visible = false
	var kam := darts.kamera
	kam.global_position = Vector3(131.7, 1.75, -241.6)
	kam.look_at(Vector3(132, 1.7, -243.95))
	kam.fov = 45.0
	for i in 3:
		await process_frame
	_schuss("darts_scheibe")
	_merke("fertig")
	quit(0)


func _schuss(name: String) -> void:
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	var pfad := "user://shots/%s.png" % name
	bild.save_png(pfad)
	_merke("SHOT " + pfad)
