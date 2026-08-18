# Werkzeug: rendert Standbilder des Dart-Minispiels (Einblendung, steckende
# Spritzen). Nur für die Entwicklung — läuft unter Xvfb, nie im Spiel.
extends SceneTree


func _init() -> void:
	call_deferred("_los")


func _los() -> void:
	var szene: Node = load("res://chapters/berlin/berlin_chapter.tscn").instantiate()
	root.add_child(szene)
	for ausloeser in szene.get_node("Triggers").get_children():
		if ausloeser is Area3D:
			ausloeser.monitoring = false
	await process_frame
	var karte := szene.get_node_or_null("UI/ChapterCard")
	var frist := 0
	while karte and karte.visible and frist < 1200:
		await process_frame
		frist += 1
	for name in ["UI", "HUD", "Debug"]:
		var schicht := szene.get_node_or_null(name)
		if schicht:
			schicht.visible = false

	var darts: DartsGame = szene.get_node("DartsGame")
	darts.kamerafahrt = 0.0
	darts.starten()
	for i in 2:
		await process_frame
	_schuss("darts_intro")

	# Drei Würfe, damit Spritzen in der Scheibe stecken.
	for wurf in [Vector2(0, 0), Vector2(0.15, 0.1), Vector2(-0.13, -0.07)]:
		darts._ziel = wurf
		darts._kraft = 0.5
		darts._werfen()
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
	quit(0)


func _schuss(name: String) -> void:
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	var pfad := "user://shots/%s.png" % name
	bild.save_png(pfad)
	print("SHOT: ", pfad)
