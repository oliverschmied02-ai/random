# Werkzeug: beobachtet die Kapitelkarte nach dem Laden unter Xvfb.
extends SceneTree


func _init() -> void:
	call_deferred("_los")


func _los() -> void:
	var szene: Node = load("res://chapters/berlin/berlin_chapter.tscn").instantiate()
	root.add_child(szene)
	await process_frame
	var karte := szene.get_node_or_null("UI/ChapterCard")
	print("TAKT karte gefunden: ", karte != null)
	for i in 8:
		var t := Time.get_ticks_msec()
		await process_frame
		print("TAKT bild %d: %d ms" % [i, Time.get_ticks_msec() - t])
	quit(0)
