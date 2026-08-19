# Werkzeug: rendert die Rohbilder für Olivers Tinder-Profil (und Annes
# Match-Avatar) direkt in der Kapitelszene — drei völlig verschiedene
# Lichtstimmungen, damit er „auf jedem Bild anders aussieht".
# Nachbearbeitung: tools/make_tinder_fotos.py veredeln.
# Nur für die Entwicklung — läuft unter Xvfb, nie im Spiel.
extends SceneTree

var _log: FileAccess
var _lampen: Array[Node] = []


func _init() -> void:
	call_deferred("_los")


func _merke(text: String) -> void:
	if _log == null:
		DirAccess.make_dir_recursive_absolute("user://shots")
		_log = FileAccess.open("user://shots/_fortschritt_fotos.txt", FileAccess.WRITE)
	_log.store_line("%d ms  %s" % [Time.get_ticks_msec(), text])
	_log.flush()


func _licht(ort: Vector3, farbe: Color, staerke: float, weite: float) -> void:
	var lampe := OmniLight3D.new()
	lampe.light_color = farbe
	lampe.light_energy = staerke
	lampe.omni_range = weite
	root.add_child(lampe)
	lampe.global_position = ort
	_lampen.append(lampe)


func _licht_aus() -> void:
	for lampe in _lampen:
		lampe.queue_free()
	_lampen.clear()


func _los() -> void:
	_merke("start")
	var szene: Node = load("res://chapters/berlin/berlin_chapter.tscn").instantiate()
	root.add_child(szene)
	for ausloeser in szene.get_node("Triggers").get_children():
		if ausloeser is Area3D:
			ausloeser.monitoring = false
	await process_frame
	var karte := szene.get_node_or_null("UI/ChapterCard")
	var frist := 0
	while karte and karte.visible and frist < 200:
		await process_frame
		frist += 1
	_merke("karte weg nach %d bildern" % frist)
	for name in ["UI", "HUD", "Debug"]:
		var schicht := szene.get_node_or_null(name)
		if schicht == null:
			continue
		for kind in schicht.get_children():
			if "visible" in kind:
				kind.visible = false

	var frei := Camera3D.new()
	root.add_child(frei)
	frei.make_current()
	# Ein paar Bilder warten, bis die Mocap-Haltung sitzt.
	for i in 14:
		await process_frame

	# Oliver steht vor seiner Bürotür bei (13.6, 0.25, -9) und schaut nach -X.
	# Die Mocap-Ruhehaltung senkt den Kopf — deshalb kommen die Kameras von
	# leicht unten, dann blickt er ins Bild.
	# Foto 1 — das ordentliche: frontal, warmes Seitenlicht.
	frei.fov = 40.0
	frei.global_position = Vector3(12.7, 1.4, -9.0)
	frei.look_at(Vector3(13.6, 1.66, -9.0))
	_licht(Vector3(12.9, 1.95, -8.55), Color(1.0, 0.85, 0.65), 3.0, 3.0)
	await _schuss("oliver_roh_1")

	# Foto 2 — der Party-Schnappschuss: schräg von oben, Magenta und Blau.
	frei.fov = 55.0
	frei.global_position = Vector3(12.9, 1.9, -8.35)
	frei.look_at(Vector3(13.6, 1.6, -9.05))
	_licht(Vector3(13.0, 1.55, -9.6), Color(0.9, 0.3, 0.8), 4.0, 4.0)
	_licht(Vector3(13.3, 2.2, -8.4), Color(0.3, 0.4, 1.0), 2.5, 4.0)
	await _schuss("oliver_roh_2")

	# Foto 3 — der Blitz von unten: nah, weit, hart.
	frei.fov = 85.0
	frei.global_position = Vector3(13.05, 1.35, -9.1)
	frei.look_at(Vector3(13.6, 1.82, -8.95))
	_licht(Vector3(13.05, 1.35, -9.1), Color(1.0, 1.0, 1.0), 2.2, 2.5)
	await _schuss("oliver_roh_3")

	# Anne am Startpunkt (0, 0.2, 12), Blick nach -Z: freundlich und warm.
	frei.fov = 42.0
	frei.global_position = Vector3(0.1, 1.42, 11.05)
	frei.look_at(Vector3(0.0, 1.64, 12.0))
	_licht(Vector3(0.35, 1.95, 11.4), Color(1.0, 0.88, 0.7), 2.5, 3.0)
	_licht(Vector3(-0.5, 1.6, 11.6), Color(0.6, 0.7, 1.0), 1.2, 3.0)
	await _schuss("anne_roh")

	_merke("fertig")
	quit(0)


func _schuss(name: String) -> void:
	for i in 4:
		await process_frame
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/%s.png" % name)
	_merke("SHOT " + name)
	_licht_aus()
