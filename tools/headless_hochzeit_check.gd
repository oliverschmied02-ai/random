# Prüflauf für Kapitel 3 — die Hochzeit. Ohne Fenster, ohne Eingabegeräte.
#
#   godot --headless --path . --script res://tools/headless_hochzeit_check.gd
#
# Spielt die Kette durch: Auftakt, Weg zum Traubogen (per Teleport), Regeln,
# Brautstrauß-Fangen (ein echter Fang und ein bewusstes Verpassen werden
# geprüft), Sieg, Geschenkbildschirm, Abspann — bis `kapitel_abgeschlossen`.
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
	var szene := (load("res://chapters/hochzeit/hochzeit_chapter.tscn")
		as PackedScene).instantiate()
	szene.test_schnell = true
	szene.weiter_nach_abspann = false
	root.add_child(szene)
	await physics_frame

	var spieler: Node3D = szene.get_node("Player")
	var dialog = szene.get_node("UI/DialogueBox")
	var spiel: StraussSpiel = szene.get_node("StraussSpiel")
	spiel.intro_dauer = 0.1
	spiel.wurf_abstand = 0.7
	spiel.flugzeit = 0.6
	# Achtung, GDScript-Falle: Lambdas fangen lokale Variablen als Kopie.
	szene.kapitel_abgeschlossen.connect(func() -> void: _fertig = true)

	print("Kapitel Hochzeit:")

	# Auftakt-Dialog bis zur Steuerungs-Übergabe.
	var frames := 0
	while not spieler.input_enabled and frames < 4000:
		frames += 1
		if dialog.is_playing() and frames % 10 == 0:
			_druecke(&"interact")
		await physics_frame
	_pruefe(spieler.input_enabled, "der Auftakt gibt die Steuerung frei")

	# Zwölf Gäste müssen stehen — sie sind der halbe Schauplatz.
	var gaeste: Array = szene.get_node("Kulisse").gaeste
	_pruefe(gaeste.size() == szene.get_node("Kulisse").GAESTE_GESAMT,
		"die Hochzeitsgesellschaft ist vollzählig (%d Gäste)" % gaeste.size())

	# Zum Traubogen — der Prüflauf teleportiert, der Trigger muss greifen.
	spieler.global_position = Vector3(0.0, 0.5, 6.5)
	frames = 0
	while spieler.input_enabled and frames < 900:
		frames += 1
		if dialog.is_playing() and frames % 10 == 0:
			_druecke(&"interact")
		await physics_frame
	_pruefe(not spieler.input_enabled, "der Traubogen übernimmt die Szene")

	# Warten, bis gefangen werden kann.
	frames = 0
	while spiel.zustand != StraussSpiel.Zustand.FANGEN and frames < 2400:
		frames += 1
		if dialog.is_playing() and frames % 10 == 0:
			_druecke(&"interact")
		await physics_frame
	_pruefe(spiel.zustand == StraussSpiel.Zustand.FANGEN,
		"das Fangspiel beginnt")

	# Ein Strauß muss bewusst verpasst werden: nicht zugreifen.
	var vorher_verpasst: int = spiel.verpasst
	frames = 0
	while spiel.verpasst == vorher_verpasst and frames < 900:
		frames += 1
		await physics_frame
	_pruefe(spiel.verpasst > vorher_verpasst,
		"ein Strauß ohne Zugriff gilt als verpasst")

	# Und einer muss gefangen werden: Hände auf die Flugbahn, zugreifen.
	var vorher_gefangen: int = spiel.gefangen
	frames = 0
	while spiel.gefangen == vorher_gefangen and frames < 3000:
		frames += 1
		# Die Hände auf den nächsten anfliegenden Strauß setzen und im
		# richtigen Moment greifen — genau das, was die Spielerin tut.
		if not spiel._fliegende.is_empty():
			var flug: Dictionary = spiel._fliegende[0]
			var ziel: Vector3 = flug["ziel"]
			spiel._haende.global_position = ziel
			if float(flug["uhr"]) / float(flug["dauer"]) > 0.72:
				spiel.greifen()
		await physics_frame
	_pruefe(spiel.gefangen > vorher_gefangen,
		"ein Zugriff auf der Flugbahn fängt den Strauß")

	# Den Rest der Runde abkürzen und gewinnen.
	spiel.alle_fangen_test()
	frames = 0
	while spiel.zustand != StraussSpiel.Zustand.SIEG and frames < 6000:
		frames += 1
		if not spiel._fliegende.is_empty():
			var flug: Dictionary = spiel._fliegende[0]
			spiel._haende.global_position = flug["ziel"]
			if float(flug["uhr"]) / float(flug["dauer"]) > 0.72:
				spiel.greifen()
		await physics_frame
	_pruefe(spiel.zustand == StraussSpiel.Zustand.SIEG,
		"fünf gefangene Sträuße gewinnen die Runde")

	# Sieg-Dialog, Geschenkbildschirm, Abspann — bis zum Kapitelabschluss.
	frames = 0
	while not _fertig and frames < 9000:
		frames += 1
		if frames % 10 == 0:
			_druecke(&"interact")
		await physics_frame
	_pruefe(_fertig, "das Kapitel meldet sich abgeschlossen")

	if _fehler == 0:
		print("hochzeit check: OK")
		quit(0)
	else:
		printerr("hochzeit check: %d Fehler" % _fehler)
		quit(1)
