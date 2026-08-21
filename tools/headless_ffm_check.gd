# Prüflauf für Kapitel 2 — Frankfurt. Ohne Fenster, ohne Eingabegeräte.
#
#   godot --headless --path . --script res://tools/headless_ffm_check.gd
#
# Spielt die Sequenzkette mit gerafften Wartezeiten durch: Abschied,
# Autobahn, Ankunft, Lauf zur Kneipe (per Teleport an die Tür), Krug-Spiel
# (ein echter Wurf muss Krüge fällen, dann räumt der Test-Stoß ab),
# Sieg-Dialog, Level-Übergang, Abspann — bis `kapitel_abgeschlossen`.
extends SceneTree

var _fehler := 0
var _fertig := false


func _init() -> void:
	call_deferred("_los")


func _pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("  OK   ", text)
	else:
		_fehler += 1
		printerr("  FEHLT ", text)


func _druecke(aktion: StringName) -> void:
	var druck := InputEventAction.new()
	druck.action = aktion
	druck.pressed = true
	Input.parse_input_event(druck)
	var los := InputEventAction.new()
	los.action = aktion
	los.pressed = false
	Input.parse_input_event(los)


func _los() -> void:
	var szene := (load("res://chapters/frankfurt/frankfurt_chapter.tscn")
		as PackedScene).instantiate()
	szene.test_schnell = true
	root.add_child(szene)
	await physics_frame

	var spieler: Node3D = szene.get_node("Player")
	var dialog = szene.get_node("UI/DialogueBox")
	var krug = szene.get_node("KrugSpiel")
	krug.intro_dauer = 0.1
	# Achtung, GDScript-Falle: Lambdas fangen lokale Variablen als Kopie —
	# das Flag muss ein Feld des Prüflaufs sein.
	szene.kapitel_abgeschlossen.connect(func() -> void: _fertig = true)

	print("Kapitel Frankfurt:")

	# Durch Abschied, Autobahn und Ankunft: Dialoge weiterklicken, bis die
	# Steuerung übergeben wird (der spielbare Lauf beginnt).
	var frames := 0
	while not spieler.input_enabled and frames < 6000:
		frames += 1
		if dialog.is_playing() and frames % 10 == 0:
			_druecke(&"interact")
		await physics_frame
	_pruefe(spieler.input_enabled,
		"Abschied, Autobahn und Ankunft laufen bis zur Steuerungs-Übergabe")

	# Die drei Fundstücke in der Gasse: ansprechen, reden lassen, Steuerung
	# zurückbekommen. Sie dürfen den Lauf nicht verschlucken.
	for punkt in szene.get_node("Erinnerungen").get_children():
		var marke: Node3D = punkt
		spieler.velocity = Vector3.ZERO
		spieler.global_position = marke.global_position + Vector3.UP * 0.3
		for i in 12:
			await physics_frame
		_druecke(&"interact")
		frames = 0
		while not dialog.is_playing() and frames < 180:
			frames += 1
			await physics_frame
		_pruefe(dialog.is_playing(), "Erinnerung '%s' spricht" % marke.name)
		frames = 0
		while dialog.is_playing() and frames < 900:
			frames += 1
			if frames % 14 == 0:
				_druecke(&"interact")
			await physics_frame
		frames = 0
		while not spieler.input_enabled and frames < 180:
			frames += 1
			await physics_frame
		_pruefe(spieler.input_enabled,
			"Erinnerung '%s' gibt die Steuerung zurück" % marke.name)

	# Zur Kneipentür — der Prüflauf teleportiert, der Trigger muss greifen.
	spieler.global_position = Vector3(300.0, 0.5, 7.7)
	frames = 0
	while spieler.input_enabled and frames < 900:
		frames += 1
		if dialog.is_playing() and frames % 10 == 0:
			_druecke(&"interact")
		await physics_frame
	_pruefe(not spieler.input_enabled, "die Kneipentür übernimmt die Szene")

	# Warten, bis das Krug-Spiel zielt.
	frames = 0
	while krug.zustand != krug.Zustand.ZIELEN and frames < 1800:
		frames += 1
		if dialog.is_playing() and frames % 10 == 0:
			_druecke(&"interact")
		await physics_frame
	_pruefe(krug.zustand == krug.Zustand.ZIELEN, "das Krug-Spiel beginnt")
	# Zwei Sekunden Physik abwarten: ein Turm, der sich nach dem Auftauen
	# von selbst setzt, fällt sonst erst nach dieser Prüfung um.
	var ruhe := create_timer(2.0)
	while ruhe.time_left > 0.0:
		await physics_frame
	_pruefe(krug.gefallen_zaehler() == 0, "alle Krüge stehen zu Beginn")

	# Ein echter Wurf auf einen Turm muss Krüge fällen. Das Ziel rechnet das
	# Spiel selbst aus (`zielvorschlag`) — eine festgeschriebene Marke zeigte
	# nach jeder Änderung am Aufbau daneben.
	krug._ziel = krug.zielvorschlag()
	krug._kraft = 0.5
	krug._werfen()
	var uhr := create_timer(2.0)
	while uhr.time_left > 0.0:
		await physics_frame
	_pruefe(krug.gefallen_zaehler() > 0,
		"ein Treffer fällt Krüge (gefallen: %d)" % krug.gefallen_zaehler())

	# Der Test-Stoß räumt den Rest ab — der Sieg muss von selbst kommen.
	krug.alle_umwerfen_test()
	frames = 0
	while krug.zustand != krug.Zustand.SIEG and frames < 1200:
		frames += 1
		await physics_frame
	_pruefe(krug.zustand == krug.Zustand.SIEG, "leerer Tisch gewinnt die Runde")

	# Sieg-Dialog, Level-Übergang, Abspann — bis zum Kapitelabschluss.
	frames = 0
	while not _fertig and frames < 6000:
		frames += 1
		if dialog.is_playing() and frames % 10 == 0:
			_druecke(&"interact")
		await physics_frame
	_pruefe(_fertig, "das Kapitel meldet sich abgeschlossen")

	if _fehler == 0:
		print("ffm check: OK")
		quit(0)
	else:
		printerr("ffm check: %d Fehler" % _fehler)
		quit(1)
