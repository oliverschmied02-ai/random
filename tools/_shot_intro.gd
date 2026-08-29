# Werkzeug: rendert Standbilder der Tinder-Intro (Hand, Karten, Gedanken,
# Match). Nur für die Entwicklung — läuft unter Xvfb, nie im Spiel.
extends SceneTree

var _log: FileAccess


func _init() -> void:
	call_deferred("_los")


func _merke(text: String) -> void:
	if _log == null:
		DirAccess.make_dir_recursive_absolute("user://shots")
		_log = FileAccess.open("user://shots/_fortschritt_intro.txt", FileAccess.WRITE)
	_log.store_line("%d ms  %s" % [Time.get_ticks_msec(), text])
	_log.flush()


func _los() -> void:
	_merke("start")
	var szene: Node = load("res://chapters/intro/tinder_intro.tscn").instantiate()
	szene.test_kein_wechsel = true
	root.add_child(szene)
	await create_timer(1.8).timeout  # Aufblende abwarten
	_merke("aufgeblendet")
	_schuss("intro_kevin")

	for i in BerlinDialogue.INTRO_PROFILE.size():
		szene.wische(false)
		await create_timer(0.9).timeout
	_merke("oliver liegt")
	_schuss("intro_oliver_gedanke")

	szene.naechstes_foto()
	await create_timer(0.4).timeout
	_schuss("intro_oliver_foto2")

	szene.wische(true)  # startet die Gedanken
	await create_timer(0.6).timeout
	_schuss("intro_oliver_gedanke2")
	for i in BerlinDialogue.INTRO_GEDANKEN.size():
		szene.gedanke_weiter()
	await create_timer(1.5).timeout
	_merke("match")
	_schuss("intro_match")
	_merke("fertig")
	quit(0)


func _schuss(name: String) -> void:
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/%s.png" % name)
	_merke("SHOT " + name)
