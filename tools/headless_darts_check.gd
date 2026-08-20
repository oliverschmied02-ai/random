# Prüflauf für das Masken-Minispiel — ohne Fenster, ohne Eingabegeräte.
#
#   godot --headless --path . --script res://tools/headless_darts_check.gd
#
# Regeln seit dem Umbau: zehn FFP2-Masken fallen, fünf Treffer gewinnen,
# Spritzen sind unbegrenzt. Geprüft wird mit fest vorgegebenen Ziel- und
# Kraftwerten und von Hand gesetzten, stillstehenden Masken — nur so misst
# jeder Durchlauf dasselbe. Der Prüflauf greift bewusst auf die internen
# Felder `_ziel`, `_kraft` und `_werfen()` zu.
extends SceneTree

var _fehler := 0
var _darts: DartsGame
var _mitte: Vector3
var _gewonnen_mit := -1


func _init() -> void:
	call_deferred("_los")


func _pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("  OK   ", text)
	else:
		_fehler += 1
		printerr("  FEHLT ", text)


func _ruhe(sekunden: float) -> void:
	var ende := Time.get_ticks_msec() + int(sekunden * 4000.0)
	var uhr := create_timer(sekunden)
	while uhr.time_left > 0.0 and Time.get_ticks_msec() < ende:
		await physics_frame


## Wirft mit festen Werten und wartet, bis die Spritze eingeschlagen ist
## und das Spiel wieder bereit steht (oder die Runde endet).
func _wurf(ziel: Vector2, kraft: float) -> void:
	_darts._ziel = ziel
	_darts._kraft = kraft
	_darts._werfen()
	var frist := 0
	while _darts.zustand == DartsGame.Zustand.FLUG and frist < 900:
		frist += 1
		await physics_frame
	await _ruhe(0.25)


func _maske(versatz: Vector2) -> void:
	_darts.maske_setzen(_mitte + Vector3(versatz.x, versatz.y, 0.0), 0.0)


func _los() -> void:
	var szene: Node = load("res://chapters/berlin/berlin_chapter.tscn").instantiate()
	root.add_child(szene)
	for ausloeser in szene.get_node("Triggers").get_children():
		if ausloeser is Area3D:
			ausloeser.monitoring = false
	await process_frame

	_darts = szene.get_node("DartsGame") as DartsGame
	_mitte = _darts.get_node("Scheibe/Mitte").global_position
	_darts.kamerafahrt = 0.0
	_darts.intro_dauer = 0.05
	_darts.pause_nach_wurf = 0.1
	_darts.pause_nach_runde = 0.4
	_darts.masken_spawn_aktiv = false
	_darts.runde_geschafft.connect(func(p: int) -> void: _gewonnen_mit = p)

	print("Masken-Minispiel:")
	_pruefe(_darts.get_node_or_null("Scheibe/Ring5") == null
		and _darts.get_node_or_null("Scheibe/Wandbrett") == null,
		"die Dartscheibe ist abgebaut")

	_darts.starten()
	var frist := 0
	while _darts.zustand != DartsGame.Zustand.ZIELEN and frist < 600:
		frist += 1
		await physics_frame
	_pruefe(_darts.zustand == DartsGame.Zustand.ZIELEN, "das Spiel startet ins Zielen")

	# Würfe ohne Maske: kein Punkt, aber auch kein Limit — es geht immer weiter.
	for i in 2:
		await _wurf(Vector2(0.3 * i, 0.2), 0.5)
	_pruefe(_darts.punkte == 0, "Würfe ins Leere geben keine Punkte")
	_pruefe(_darts.zustand == DartsGame.Zustand.ZIELEN,
		"nach Fehlwürfen geht es einfach weiter (Spritzen unbegrenzt)")

	# Verlieren: alle zehn Masken sind durch, zu wenig Treffer — die Runde
	# endet freundlich und beginnt von selbst neu.
	_darts.masken_erschienen = DartsConfig.MASKEN_PRO_RUNDE
	_darts.masken_erledigt = DartsConfig.MASKEN_PRO_RUNDE
	_darts.masken_spawn_aktiv = true
	frist = 0
	while _darts.zustand != DartsGame.Zustand.RUNDENENDE and frist < 300:
		frist += 1
		await physics_frame
	_pruefe(_darts.zustand == DartsGame.Zustand.RUNDENENDE,
		"zehn erledigte Masken ohne fünf Treffer beenden die Runde")
	frist = 0
	while _darts.zustand != DartsGame.Zustand.ZIELEN and frist < 900:
		frist += 1
		await physics_frame
	_darts.masken_spawn_aktiv = false
	for eintrag in _darts._masken.duplicate():
		_darts._maske_entfernen(eintrag)
	_darts.masken_erschienen = 0
	_darts.masken_erledigt = 0
	_pruefe(_darts.zustand == DartsGame.Zustand.ZIELEN and _darts.punkte == 0,
		"danach beginnt eine frische Runde bei null")
	_pruefe(_gewonnen_mit == -1, "Verlieren löst keinen Kapitel-Abschluss aus")

	# Gewinnen: fünf Treffer auf verstreute, stillstehende Masken. Der
	# zweite Wurf mit voller Kraft zeigt, dass die Wurfkraft nur die Höhe
	# verschiebt — die großzügige Trefferzone fängt das auf.
	var ziele: Array = [
		[Vector2(0.0, 0.0), 0.5],
		[Vector2(0.6, 0.3), 1.0],
		[Vector2(-0.8, 0.5), 0.5],
		[Vector2(0.9, -0.2), 0.5],
		[Vector2(-0.4, -0.5), 0.5],
	]
	for i in ziele.size():
		_maske(ziele[i][0])
		await _wurf(ziele[i][0], ziele[i][1])
		_pruefe(_darts.punkte == (i + 1) * DartsConfig.MASKEN_PUNKTE,
			"Treffer %d zählt (auch mit Kraft %.1f)" % [i + 1, ziele[i][1]])
	_pruefe(_darts.masken_anzahl() == 0, "alle getroffenen Masken sind entfernt")
	_pruefe(_darts.masken_erledigt == ziele.size(),
		"erledigte Masken werden gezählt")
	_pruefe(_darts.zustand == DartsGame.Zustand.RUNDENENDE,
		"der fünfte Treffer beendet die Runde sofort")
	_pruefe(_gewonnen_mit == DartsConfig.ZIELPUNKTZAHL,
		"gewonnen wird mit genau %d Punkten" % DartsConfig.ZIELPUNKTZAHL)

	if _fehler == 0:
		print("darts check: OK")
		quit(0)
	else:
		printerr("darts check: %d Fehler" % _fehler)
		quit(1)
