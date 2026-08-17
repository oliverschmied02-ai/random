extends SceneTree

## Headless check for the model slot on both figures.
##
##   godot --headless --path . --script res://tools/headless_figur_check.gd
##
## Both halves are covered, and which one applies depends on what is actually
## in `actors/models/`:
##
##   1. no model file — the actor keeps its placeholder and the game behaves
##      exactly as before
##   2. model file present — it is mounted, turned to face forward, scaled to
##      the intended height, its arms come out of the T-pose, and the
##      placeholder disappears
##
## Case (2) is checked twice: once against whatever real models are in the
## repository, and once against a stand-in built here and saved to `user://` —
## a mannequin of boxes, deliberately the wrong size (2.4 m), so the scaling has
## something to correct. The fixture is built rather than committed to keep the
## repository free of assets nobody will ever look at.

## Wie groß der Prüfling gebaut wird — bewusst zu groß.
const PROBE_HOEHE := 2.4
const PROBE_PFAD := "user://probe_figur.tscn"

var _failures: PackedStringArray = []
var _notes: PackedStringArray = []


func _initialize() -> void:
	_ablauf()


func _physics_process(_delta: float) -> bool:
	return false


func _ablauf() -> void:
	await physics_frame
	_probe_bauen()
	await _rueckfall_pruefen()
	await _modell_pruefen()
	_report()


## Baut einen Strichmännchen-Ersatz aus Quadern und legt ihn als Szene ab.
func _probe_bauen() -> void:
	var wurzel := Node3D.new()
	wurzel.name = "Probe"

	var teile := {
		"Rumpf": [Vector3(0.5, 1.1, 0.3), Vector3(0.0, 1.35, 0.0)],
		"Kopf": [Vector3(0.28, 0.34, 0.28), Vector3(0.0, 2.2, 0.0)],
		"BeinLinks": [Vector3(0.2, 0.8, 0.2), Vector3(-0.15, 0.4, 0.0)],
		"BeinRechts": [Vector3(0.2, 0.8, 0.2), Vector3(0.15, 0.4, 0.0)],
		# Die Nase zeigt nach +Z — daran lässt sich prüfen, ob gedreht wurde.
		"Nase": [Vector3(0.08, 0.08, 0.12), Vector3(0.0, 2.2, 0.2)],
	}
	for name in teile:
		var wuerfel := BoxMesh.new()
		wuerfel.size = teile[name][0]
		var teil := MeshInstance3D.new()
		teil.name = name
		teil.mesh = wuerfel
		teil.position = teile[name][1]
		wurzel.add_child(teil)
		teil.owner = wurzel

	var szene := PackedScene.new()
	_expect(szene.pack(wurzel) == OK, "the stand-in can be packed")
	_expect(ResourceSaver.save(szene, PROBE_PFAD) == OK,
		"the stand-in can be saved to %s" % PROBE_PFAD)
	wurzel.free()


func _rueckfall_pruefen() -> void:
	var kapitel := load("res://chapters/berlin/berlin_chapter.tscn").instantiate() as Node3D
	root.add_child(kapitel)
	await physics_frame

	for paar in [["Anne", "Player"], ["Oliver", "Oliver"]]:
		var figur := kapitel.get_node_or_null("%s/Visual" % paar[1]) as Figur
		if figur == null:
			_fail("%s has no model slot on its Visual node" % paar[0])
			continue
		_expect(not figur.modell_pfad.is_empty(),
			"%s names the model it is waiting for" % paar[0])

		var platzhalter := figur.get_node_or_null("Platzhalter") as Node3D
		if ResourceLoader.exists(figur.modell_pfad):
			_echte_figur_pruefen(paar[0] as String, figur, platzhalter)
		else:
			_expect(figur.modell == null,
				"%s has no model — the file is not in the repository" % paar[0])
			_expect(platzhalter != null and platzhalter.visible,
				"%s keeps its placeholder until the model arrives" % paar[0])
			_note("%s wartet noch auf %s" % [paar[0], figur.modell_pfad])

	kapitel.queue_free()
	await physics_frame


## Eine Figur, für die tatsächlich ein Modell im Projekt liegt.
func _echte_figur_pruefen(name: String, figur: Figur, platzhalter: Node3D) -> void:
	if figur.modell == null:
		_fail("%s has a model file but it did not load" % name)
		return

	var hoehe := figur.gemessene_hoehe()
	_expect(absf(hoehe - figur.zielhoehe) < 0.03,
		"%s stands %.2f m tall as intended (%.2f m)" % [name, hoehe, figur.zielhoehe])
	_expect(platzhalter != null and not platzhalter.visible,
		"%s hides its placeholder now that the model is there" % name)

	var skelett := figur.skelett_finden()
	_expect(skelett != null, "%s brings a skeleton for the animations to come" % name)
	if skelett == null:
		return
	_expect(skelett.find_bone("Hips") >= 0 and skelett.find_bone("LeftUpLeg") >= 0,
		"%s uses the expected bone names" % name)
	_note("%s: %d Knochen, %.2f m" % [name, skelett.get_bone_count(), hoehe])

	# Die Arme müssen unterhalb der Schultern hängen, sonst steht die Figur
	# weiter in der T-Pose, in der sie gebaut wurde.
	var schulter := skelett.find_bone("LeftArm")
	var hand := skelett.find_bone("LeftHand")
	if schulter >= 0 and hand >= 0:
		var oben := skelett.get_bone_global_pose(schulter).origin.y
		var unten := skelett.get_bone_global_pose(hand).origin.y
		_expect(unten < oben - 0.2,
			"%s lets its arms hang: hand %.2f m below the shoulder" % [name, oben - unten])


func _modell_pruefen() -> void:
	var traeger := Node3D.new()
	root.add_child(traeger)

	var platzhalter := Node3D.new()
	platzhalter.name = "Platzhalter"

	var figur := Figur.new()
	figur.name = "Visual"
	figur.set_script(load("res://systems/figur/figur.gd"))
	figur.modell_pfad = PROBE_PFAD
	figur.zielhoehe = 1.75
	figur.add_child(platzhalter)
	traeger.add_child(figur)
	await physics_frame

	if figur.modell == null:
		_fail("a model file present is not picked up")
		traeger.queue_free()
		return

	var hoehe := figur.gemessene_hoehe()
	_note("Prüfling %.2f m gebaut, auf %.2f m gebracht" % [PROBE_HOEHE, hoehe])
	_expect(absf(hoehe - 1.75) < 0.02,
		"the model is scaled to the intended height: %.3f m" % hoehe)
	_expect(not platzhalter.visible, "the placeholder steps aside for the model")

	# Die Nase des Prüflings zeigt im Modell nach +Z. Nach dem Drehen muss sie
	# in Godots Vorwärtsrichtung zeigen, also nach −Z.
	var nase := figur.modell.get_node_or_null("Nase") as Node3D
	if nase == null:
		_fail("the stand-in lost its nose on the way")
	else:
		_expect(nase.global_position.z < traeger.global_position.z,
			"the model faces forward, not backwards: nose at z=%.2f"
				% nase.global_position.z)

	traeger.queue_free()
	await physics_frame


# --- Werkzeug --------------------------------------------------------------


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)


func _note(text: String) -> void:
	_notes.append(text)


func _report() -> void:
	for note in _notes:
		print("note: ", note)
	if _failures.is_empty():
		print("figur check: OK")
		quit()
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	print("figur check: %d failure(s)" % _failures.size())
	quit(1)
