# Prüflauf für die Tinder-Intro — ohne Fenster, ohne Eingabegeräte.
#
#   godot --headless --path . --script res://tools/headless_intro_check.gd
#
# Prüft den Kartenstapel als Zustandsmaschine: drei Scherz-Profile lassen
# sich nur nach links wischen (rechts federt zurück und Anne kommentiert),
# dann liegt Oliver mit drei Fotos, die Gedanken laufen Zeile für Zeile,
# links federt zurück, rechts macht das Match — und erst dann.
extends SceneTree

var _fehler := 0


func _init() -> void:
	call_deferred("_los")


func _pruefe(bedingung: bool, text: String) -> void:
	if bedingung:
		print("  OK   ", text)
	else:
		_fehler += 1
		printerr("  FEHLT ", text)


func _ruhe(sekunden: float = 0.9) -> void:
	# Engine-Zeit statt Bilderzählen: die Karten-Tweens laufen auf derselben
	# Uhr, damit ist das Warten unabhängig von der headless-Bildrate.
	await create_timer(sekunden).timeout


func _los() -> void:
	var szene: Node = load("res://chapters/intro/tinder_intro.tscn").instantiate()
	szene.test_kein_wechsel = true
	root.add_child(szene)
	await process_frame
	await process_frame

	print("Tinder-Intro:")
	_pruefe(szene.karten_index() == 0, "erste Karte liegt")
	_pruefe(szene.zustand() == szene.Zustand.WISCHEN, "Anfangszustand ist WISCHEN")

	# Rechts wischen auf einem Scherz-Profil: Karte bleibt, Anne winkt ab.
	szene.wische(true)
	await _ruhe()
	_pruefe(szene.karten_index() == 0, "rechts auf Kevin federt zurück")
	_pruefe(not szene.match_erreicht, "kein Match durch Zurückfedern")

	# Die drei Scherz-Profile nach links.
	for i in 3:
		var flog: bool = szene.wische(false)
		_pruefe(flog, "Karte %d fliegt nach links" % (i + 1))
		await _ruhe()
	_pruefe(szene.karten_index() == 3, "nach drei Wischen liegt Oliver")

	# Olivers Karte startet die Gedanken; Wischen ist derweil gesperrt.
	_pruefe(szene.zustand() == szene.Zustand.GEDANKEN, "Gedanken beginnen von selbst")
	_pruefe(not szene.wische(false), "während der Gedanken wird nicht gewischt")
	for i in BerlinDialogue.INTRO_GEDANKEN.size():
		szene.gedanke_weiter()
	_pruefe(szene.zustand() == szene.Zustand.WISCHEN, "nach den Gedanken wird gewischt")

	# Durch die Fotos blättern: drei Stück, dann wieder das erste.
	_pruefe(szene.foto_index() == 0, "Foto 1 liegt zuerst")
	szene.naechstes_foto()
	szene.naechstes_foto()
	_pruefe(szene.foto_index() == 2, "zweimal Tippen zeigt Foto 3")
	szene.naechstes_foto()
	_pruefe(szene.foto_index() == 0, "danach wieder Foto 1")

	# Links auf Oliver federt zurück — er fliegt nicht weg.
	szene.wische(false)
	await _ruhe()
	_pruefe(szene.karten_index() == 3, "links auf Oliver federt zurück")
	_pruefe(not szene.match_erreicht, "noch kein Match")

	# Rechts auf Oliver: Match.
	szene.wische(true)
	await _ruhe(1.2)
	_pruefe(szene.match_erreicht, "rechts auf Oliver macht das Match")
	_pruefe(szene.zustand() == szene.Zustand.MATCH, "Zustand steht auf MATCH")

	if _fehler == 0:
		print("intro check: OK")
		quit(0)
	else:
		printerr("intro check: %d Fehler" % _fehler)
		quit(1)
