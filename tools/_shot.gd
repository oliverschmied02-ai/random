# Werkzeug: rendert Standbilder der Berliner Kulisse aus mehreren Blickwinkeln.
# Nur für die Entwicklung — läuft unter Xvfb, nie im Spiel.
extends SceneTree

const ORTE := [
	{"name": "start", "pos": Vector3(0, 1.6, 10), "gier": 0.0, "neig": 0.02},
	{"name": "tramstrasse", "pos": Vector3(16, 1.7, -55), "gier": -PI / 2, "neig": 0.03},
	{"name": "leg3", "pos": Vector3(60, 1.7, -88), "gier": PI, "neig": 0.02},
	{"name": "ampel", "pos": Vector3(70.8, 1.7, -124), "gier": 0.0, "neig": 0.02},
	{"name": "platz", "pos": Vector3(126, 2.0, -181), "gier": 0.43, "neig": 0.02},
	{"name": "bude", "pos": Vector3(127, 1.7, -230), "gier": 0.71, "neig": 0.0},
]


func _init() -> void:
	call_deferred("_los")


func _los() -> void:
	var szene: Node = load("res://chapters/berlin/berlin_chapter.tscn").instantiate()
	root.add_child(szene)
	# Auslöser stilllegen, bevor die Kamera durch die Welt springt.
	for ausloeser in szene.get_node("Triggers").get_children():
		if ausloeser is Area3D:
			ausloeser.monitoring = false
	await process_frame
	# Warten, bis die Kapitelkarte weg ist.
	var karte := szene.get_node_or_null("UI/ChapterCard")
	var frist := 0
	while karte and karte.visible and frist < 1200:
		await process_frame
		frist += 1
		if frist % 5 == 0:
			print("WARTE: Karte, Bild %d, %.1f s" % [frist, Time.get_ticks_msec() / 1000.0])
	print("KARTE WEG nach %d Bildern, %.1f s" % [frist, Time.get_ticks_msec() / 1000.0])
	# Oberfläche ausblenden — die Bilder sollen nur die Kulisse zeigen.
	for name in ["UI", "HUD", "Debug"]:
		var schicht := szene.get_node_or_null(name)
		if schicht:
			schicht.visible = false
	var kam := Camera3D.new()
	kam.fov = 65.0
	root.add_child(kam)
	kam.make_current()
	await process_frame
	for ort in ORTE:
		kam.position = ort["pos"]
		kam.rotation = Vector3(ort["neig"], ort["gier"], 0.0)
		# Ein paar Bilder verstreichen lassen, damit Licht und Nebel stehen.
		for i in 2:
			await process_frame
		var bild := root.get_viewport().get_texture().get_image()
		var pfad := "user://shots/%s.png" % ort["name"]
		DirAccess.make_dir_recursive_absolute("user://shots")
		bild.save_png(pfad)
		print("SHOT: ", pfad)
	quit(0)
