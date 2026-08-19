extends SceneTree

## Prüflauf für das Dart-Minispiel.
##
##   godot --headless --path . --script res://tools/headless_darts_check.gd
##
## Wirft mit fest vorgegebenen Ziel- und Kraftwerten, statt Eingaben zu
## simulieren — nur so lässt sich prüfen, dass ein bestimmter Zielpunkt auch
## die erwartete Punktzahl ergibt.
##
## Der Prüflauf greift dafür bewusst auf die internen Felder `_ziel`, `_kraft`
## und `_werfen()` zu. Die Alternative wäre gewesen, dem Spielcode eine nur
## fürs Testen gedachte Schnittstelle anzuhängen — das wäre der schlechtere
## Tausch.

## Geplante Würfe: [Zielversatz von der Mitte, Ladestand, Maskenversatz].
## Maskenversatz null heißt: keine Maske im Spiel — der Wurf muss leer
## ausgehen. Die Masken werden mit Fallgeschwindigkeit 0 gesetzt, damit
## jeder Durchlauf dasselbe misst.
const PLAN: Array = [
	# Runde 1: zwei Treffer (40 Punkte), drei Fehlwürfe — verliert, Neustart.
	[Vector2(0.0, 0.0), 0.5, Vector2(0.0, 0.0)],
	[Vector2(0.6, 0.3), 0.5, Vector2(0.6, 0.3)],
	[Vector2(0.0, 0.0), 1.0, null],
	[Vector2(0.0, 0.0), 0.0, null],
	[Vector2(1.0, -0.4), 0.5, null],
	# Runde 2: fünf Treffer auf verstreute Masken — gewinnt mit 100.
	[Vector2(0.0, 0.0), 0.5, Vector2(0.0, 0.0)],
	[Vector2(-0.8, 0.5), 0.5, Vector2(-0.8, 0.5)],
	[Vector2(0.9, -0.2), 0.5, Vector2(0.9, -0.2)],
	[Vector2(0.3, 0.8), 0.5, Vector2(0.3, 0.8)],
	[Vector2(-0.4, -0.5), 0.5, Vector2(-0.4, -0.5)],
]

var _root: Node3D
var _darts: DartsGame
var _mitte: Vector3

var _frames: int = 0
var _index: int = 0
var _treffer: Array = []
var _punkte_vor_wurf: Array = []
var _gewonnen_mit: int = -1
var _warte: int = 0
var _nachlauf: int = 0
var _failures: PackedStringArray = []
var _notes: PackedStringArray = []


func _initialize() -> void:
	_root = load("res://chapters/berlin/berlin_chapter.tscn").instantiate() as Node3D
	root.add_child(_root)


## Erst im ersten Physikschritt verdrahten: während `_initialize` steht der
## Szenenbaum noch nicht, `@onready`-Felder der Szene sind dort noch leer.
func _vorbereiten() -> void:
	_darts = _root.get_node_or_null("DartsGame") as DartsGame
	if _darts == null:
		_fail("chapter scene has no DartsGame")
		return

	# Wartezeiten kurz halten, die Kamerafahrt entfällt; keine zufälligen
	# Masken — der Plan setzt seine eigenen, unbewegt.
	_darts.kamerafahrt = 0.0
	_darts.masken_spawn_aktiv = false
	_darts.intro_dauer = 0.2
	_darts.pause_nach_wurf = 0.05
	_darts.pause_nach_runde = 0.1
	_darts.runde_geschafft.connect(func(punkte: int) -> void: _gewonnen_mit = punkte)
	_darts._treffer.child_entered_tree.connect(_neue_spritze)


func _neue_spritze(knoten: Node) -> void:
	var spritze := knoten as Syringe
	if spritze != null:
		spritze.eingeschlagen.connect(_auf_treffer)


func _auf_treffer(punkte: int, ort: Vector3, radius: float) -> void:
	_treffer.append({"punkte": punkte, "ort": ort, "radius": radius})


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_vorbereiten()
	if _darts == null:
		_report()
		return true

	if _frames > 3000:
		_fail("ran out of frames after %d throws" % _treffer.size())
		_report()
		return true

	if _frames == 10:
		_mitte = _darts.ziel_punkt()
		_darts.starten()
		return false

	if _warte > 0:
		_warte -= 1
		return false

	if _index >= PLAN.size():
		# Nach dem letzten Einschlag noch etwas laufen lassen: das Rundenende
		# folgt erst nach der Pause, und mit ihm das Erfolgssignal.
		if _treffer.size() >= PLAN.size():
			_nachlauf += 1
			if _nachlauf > 45:
				_auswerten()
				return true
		return false

	if _darts.zustand != DartsGame.Zustand.ZIELEN:
		return false

	var wurf: Array = PLAN[_index]
	_punkte_vor_wurf.append(_darts.punkte)
	if wurf[2] != null:
		var versatz: Vector2 = wurf[2]
		_darts.maske_setzen(_mitte + Vector3(versatz.x, versatz.y, 0.0), 0.0)
	_darts._ziel = wurf[0]
	_darts._kraft = wurf[1]
	_darts._werfen()
	_index += 1
	_warte = 2
	return false


func _auswerten() -> void:
	_expect(_treffer.size() == PLAN.size(),
		"every throw landed: %d of %d" % [_treffer.size(), PLAN.size()])

	# --- Kraft verschiebt nur die Höhe, nie die Seite ---------------------
	var hoch: Dictionary = _treffer[2]
	var tief: Dictionary = _treffer[3]
	var seite := absf(hoch["ort"].x - tief["ort"].x)
	_expect(seite < 0.005,
		"power leaves the horizontal hit untouched: %.4f m apart" % seite)
	_expect(hoch["ort"].y > _mitte.y + 0.02,
		"full power lands high: %+.3f m" % (hoch["ort"].y - _mitte.y))
	_expect(tief["ort"].y < _mitte.y - 0.02,
		"no power lands low: %+.3f m" % (tief["ort"].y - _mitte.y))

	# --- Masken zählen, die leere Wand nicht ------------------------------
	for i in [0, 1]:
		_expect(_darts.punkte >= 0 and _punkte_vor_wurf.size() > i, "bookkeeping")
	_expect(_punkte_vor_wurf[1] == DartsConfig.MASKEN_PUNKTE,
		"a mask hit scores %d, got %d"
			% [DartsConfig.MASKEN_PUNKTE, _punkte_vor_wurf[1]])
	_expect(_punkte_vor_wurf[2] == 2 * DartsConfig.MASKEN_PUNKTE,
		"two hits add up, got %d" % _punkte_vor_wurf[2])
	_expect(_punkte_vor_wurf[3] == _punkte_vor_wurf[2],
		"a throw without mask scores nothing")
	_expect(_darts.masken_anzahl() == 0,
		"hit masks disappear, %d left" % _darts.masken_anzahl())

	# --- Verlorene Runde startet bei null neu ------------------------------
	var runde1 := 2 * DartsConfig.MASKEN_PUNKTE
	_expect(runde1 < DartsConfig.ZIELPUNKTZAHL,
		"the first round is meant to fall short: %d points" % runde1)
	_expect(_punkte_vor_wurf[5] == 0,
		"a missed target starts a fresh round at zero, got %d" % _punkte_vor_wurf[5])

	# --- Gewonnene Runde ---------------------------------------------------
	_expect(_gewonnen_mit == 5 * DartsConfig.MASKEN_PUNKTE,
		"reaching the target reports the score, got %d" % _gewonnen_mit)

	_note("Ladefehler: %+.3f m / %+.3f m senkrecht, %.4f m waagerecht"
		% [hoch["ort"].y - _mitte.y, tief["ort"].y - _mitte.y, seite])
	_note("verlorene Runde: %d von %d Punkten, danach Neustart bei %d"
		% [runde1, DartsConfig.ZIELPUNKTZAHL, _punkte_vor_wurf[5]])
	_note("gewonnene Runde: %d Punkte (fünf Masken abgeworfen)" % _gewonnen_mit)
	_report()


func _expect(bedingung: bool, beschreibung: String) -> void:
	if not bedingung:
		_fail(beschreibung)


func _fail(beschreibung: String) -> void:
	_failures.append(beschreibung)


func _note(text: String) -> void:
	_notes.append(text)


func _report() -> void:
	for note in _notes:
		print("note: ", note)
	if _failures.is_empty():
		print("darts check: OK")
		return
	for failure in _failures:
		printerr("FAIL: ", failure)
	print("darts check: %d failure(s)" % _failures.size())
	quit(1)
