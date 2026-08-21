extends Node3D

## Die Kulisse für Kapitel 2 — Frankfurt. Vier Schauplätze in einer Szene,
## räumlich weit auseinander, die Sequenzen schneiden dazwischen:
##
## * **Abschied** (um den Ursprung): eine Berliner Hauswand, Gehweg,
##   der beladene Umzugs-LKW am Bordstein.
## * **Autobahn** (bei z = 300): 600 m A5 bei Tag — zwei Richtungsfahrbahnen,
##   Leitplanken, blaue Schilder mit fallenden Kilometern, Bäume, und der
##   fahrende LKW (`LkwFahrt`, vom Kapitel animiert).
## * **Sachsenhausen** (x 195–320): Fachwerkzeile gegen Putzhäuser, am Ende
##   die Apfelweinkneipe, dahinter die Bankentürme der Skyline.
## * **Kneipenstube** (bei 400, -100): Holzboden, Tische, Bembel-Regal und
##   die Wurfecke des Minispiels.
##
## Wie in Kapitel 1 gilt: alles hier ist Anstrich. Kollision kommt vom
## globalen Boden plus wenigen unsichtbaren Banden in Sachsenhausen.

const _FENSTER := preload("res://assets/props/fenster_modul.glb")
const _TUER := preload("res://assets/props/tuer_modul.glb")
const _BAUM := preload("res://assets/props/baum.glb")
const _AUTO := preload("res://assets/props/auto.glb")
const _LKW := preload("res://assets/props/lkw.glb")
const _BEMBEL := preload("res://assets/props/bembel.glb")
const _LATERNE := preload("res://assets/props/laterne.glb")
const _BANK := preload("res://assets/props/bank.glb")

## Vom Kapitel animiert: der LKW auf der Autobahn.
var lkw_fahrt: Node3D
## Gegenverkehr auf der Autobahn, fährt von selbst.
var _gegenverkehr: Array = []

const PUTZTOENE: Array[Color] = [
	Color(0.78, 0.70, 0.55), Color(0.72, 0.66, 0.58), Color(0.77, 0.72, 0.60),
]


func _ready() -> void:
	_abschied_bauen()
	_autobahn_bauen()
	_sachsenhausen_bauen()
	_kneipe_bauen()


func _process(delta: float) -> void:
	for auto in _gegenverkehr:
		auto.position.x -= 22.0 * delta
		if auto.position.x < -290.0:
			auto.position.x = 290.0


# --- Werkzeuge ----------------------------------------------------------------


func _mat(farbe: Color, rauheit: float = 0.9, leuchten: Color = Color.BLACK,
		staerke: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = farbe
	m.roughness = rauheit
	if staerke > 0.0:
		m.emission_enabled = true
		m.emission = leuchten
		m.emission_energy_multiplier = staerke
	return m


func _tex_mat(pfad: String, masstab: float, farbe: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(pfad)
	m.albedo_color = farbe
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * masstab
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


func _kasten(mitte: Vector3, masse: Vector3, material: Material,
		drehung: float = 0.0) -> MeshInstance3D:
	var teil := MeshInstance3D.new()
	var form := BoxMesh.new()
	form.size = masse
	form.material = material
	teil.mesh = form
	add_child(teil)
	teil.position = mitte
	teil.rotation.y = drehung
	return teil


func _prop(szene: PackedScene, ort: Vector3, gier: float = 0.0,
		masstab: float = 1.0) -> Node3D:
	var teil := szene.instantiate() as Node3D
	add_child(teil)
	teil.position = ort
	teil.rotation.y = gier
	if masstab != 1.0:
		teil.scale = Vector3.ONE * masstab
	return teil


## Unsichtbare Bande, damit niemand aus dem Schauplatz läuft.
func _bande(mitte: Vector3, masse: Vector3) -> void:
	var koerper := StaticBody3D.new()
	var form := CollisionShape3D.new()
	var kasten := BoxShape3D.new()
	kasten.size = masse
	form.shape = kasten
	koerper.add_child(form)
	add_child(koerper)
	koerper.position = mitte


func _fenster_reihe(wand_front: Vector3, richtung: float, anzahl: int,
		abstand: float, hoehen: Array) -> void:
	## Setzt Fenstermodule auf eine Wandfront. `wand_front` ist die Mitte
	## der Front, `richtung` die Blickrichtung der Fassade (Gier).
	var quer := Vector3(cos(richtung), 0, -sin(richtung))
	for hoehe: float in hoehen:
		for i in anzahl:
			var u := (i - (anzahl - 1) * 0.5) * abstand
			var teil := _FENSTER.instantiate() as Node3D
			add_child(teil)
			teil.position = wand_front + quer * u + Vector3(0, hoehe, 0)
			teil.rotation.y = richtung


# --- Abschied (Berlin, Ursprung) ------------------------------------------------


func _abschied_bauen() -> void:
	var putz := _tex_mat("res://assets/texturen/ffm/fachwerk.png", 0.0, Color.WHITE)
	# Berliner Wand: schlichter Putz, kein Fachwerk — eigenes Material.
	putz = _mat(Color(0.58, 0.53, 0.43), 0.95)
	_kasten(Vector3(0, 4.5, -8.3), Vector3(26, 9, 0.6), putz)
	_fenster_reihe(Vector3(0, 0, -7.98), 0.0, 5, 3.2, [2.4, 5.4])
	var tuer := _TUER.instantiate() as Node3D
	add_child(tuer)
	tuer.position = Vector3(-5.6, 1.48, -7.98)
	# Gehweg und Bordstein.
	_kasten(Vector3(0, 0.04, -6.2), Vector3(26, 0.08, 3.6), _mat(Color(0.62, 0.62, 0.6), 0.95))
	_kasten(Vector3(0, 0.01, -1.5), Vector3(26, 0.02, 6.0), _mat(Color(0.16, 0.16, 0.18), 0.85))
	# Der beladene LKW am Bordstein, Schnauze nach links (-X) — weit genug
	# rechts, dass das Fahrerhaus der Abschiedskamera nicht im Bild steht.
	_prop(_LKW, Vector3(6.4, 0, -2.6), -PI / 2.0)
	_prop(_LATERNE, Vector3(-7.0, 0, -5.8), PI)
	_prop(_BAUM, Vector3(9.5, 0, -5.9), 0.7)


# --- Autobahn (z = 300) ---------------------------------------------------------


func _autobahn_bauen() -> void:
	var asphalt := _mat(Color(0.22, 0.22, 0.24), 0.9)
	var gras := _mat(Color(0.30, 0.42, 0.22), 1.0)
	var metall := _mat(Color(0.62, 0.64, 0.66), 0.4)

	_kasten(Vector3(0, 0.02, 300.0), Vector3(620, 0.05, 8.0), asphalt)   # Richtung Süden
	_kasten(Vector3(0, 0.02, 291.0), Vector3(620, 0.05, 8.0), asphalt)   # Gegenrichtung
	_kasten(Vector3(0, 0.01, 295.5), Vector3(620, 0.06, 1.6), gras)      # Mittelstreifen
	_kasten(Vector3(0, 0.005, 322.0), Vector3(620, 0.03, 36.0), gras)
	_kasten(Vector3(0, 0.005, 270.0), Vector3(620, 0.03, 36.0), gras)
	for z in [295.0, 296.0]:
		_kasten(Vector3(0, 0.62, z), Vector3(620, 0.28, 0.07), metall)   # Leitplanken

	# Fahrbahnmarkierung: gestrichelt, als MultiMesh.
	var striche := MultiMesh.new()
	striche.transform_format = MultiMesh.TRANSFORM_3D
	var strich := BoxMesh.new()
	strich.size = Vector3(3.0, 0.012, 0.16)
	strich.material = _mat(Color(0.85, 0.85, 0.85), 0.8)
	striche.mesh = strich
	var orte: Array[Vector3] = []
	var x := -300.0
	while x < 300.0:
		orte.append(Vector3(x, 0.05, 300.0))
		orte.append(Vector3(x, 0.05, 291.0))
		x += 9.0
	striche.instance_count = orte.size()
	for i in orte.size():
		striche.set_instance_transform(i, Transform3D(Basis.IDENTITY, orte[i]))
	var traeger := MultiMeshInstance3D.new()
	traeger.multimesh = striche
	add_child(traeger)

	# Bäume am Rand, locker gestreut.
	var rng := RandomNumberGenerator.new()
	rng.seed = 65
	for i in 26:
		var seite := 318.0 if i % 2 == 0 else 273.0
		_prop(_BAUM, Vector3(-280.0 + i * 22.0 + rng.randf_range(-4, 4), 0, seite),
			rng.randf_range(0, TAU), rng.randf_range(0.9, 1.3))

	# Die blauen Schilder — die Kilometer fallen Richtung Frankfurt.
	for daten in [[-120.0, "schild_1"], [30.0, "schild_2"], [160.0, "schild_3"]]:
		_schild(daten[0], daten[1])

	# Der fahrende LKW (vom Kapitel animiert) und etwas Gegenverkehr.
	# Die Schnauze des Modells zeigt nach +Z; +PI/2 dreht sie in
	# Fahrtrichtung +X (der Gegenverkehr fährt -X, also -PI/2).
	lkw_fahrt = _prop(_LKW, Vector3(-240.0, 0, 300.0), PI / 2.0)
	lkw_fahrt.name = "LkwFahrt"
	for i in 3:
		var auto := _prop(_AUTO, Vector3(-120.0 + i * 170.0, 0, 291.0), -PI / 2.0)
		_gegenverkehr.append(auto)


func _schild(x: float, textur: String) -> void:
	var stoff := StandardMaterial3D.new()
	stoff.albedo_texture = load("res://assets/texturen/ffm/%s.png" % textur)
	stoff.roughness = 0.6
	var flaeche := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.8, 1.9)
	quad.material = stoff
	flaeche.mesh = quad
	add_child(flaeche)
	flaeche.position = Vector3(x, 3.0, 304.6)
	flaeche.rotation.y = -PI / 2.0   # dem Verkehr in Fahrtrichtung +X zugewandt
	var mast := _mat(Color(0.5, 0.52, 0.55), 0.5)
	for versatz in [-1.5, 1.5]:
		_kasten(Vector3(x, 1.5, 304.6 + versatz * 0.0), Vector3(0.12, 3.0, 0.12), mast)
		break
	_kasten(Vector3(x - 0.05, 1.5, 304.6), Vector3(0.14, 3.2, 0.14), mast)


# --- Sachsenhausen (x 195–320) ---------------------------------------------------


func _sachsenhausen_bauen() -> void:
	var fachwerk := _tex_mat("res://assets/texturen/ffm/fachwerk.png", 0.32)
	var kopfstein := _mat(Color(0.42, 0.40, 0.38), 0.95)
	var gehweg := _mat(Color(0.60, 0.58, 0.55), 0.95)

	_kasten(Vector3(257, 0.01, 0), Vector3(130, 0.02, 10.0), kopfstein)
	_kasten(Vector3(257, 0.045, 6.6), Vector3(130, 0.09, 3.2), gehweg)
	_kasten(Vector3(257, 0.045, -6.6), Vector3(130, 0.09, 3.2), gehweg)

	# Südzeile: Fachwerk, jede Front leicht anders getönt.
	for i in 4:
		var x := 208.0 + i * 14.0
		var haus := _kasten(Vector3(x, 3.75, 12.2), Vector3(12.5, 7.5, 8.0), fachwerk)
		haus.rotation.y = 0.0
		_fenster_reihe(Vector3(x, 0, 8.18), PI, 3, 3.6, [2.2, 5.2])
	# Nordzeile: Putzhäuser mit Fenstermodulen.
	for i in 4:
		var x := 210.0 + i * 15.0
		var ton: Color = PUTZTOENE[i % PUTZTOENE.size()]
		_kasten(Vector3(x, 4.5, -12.2), Vector3(13.5, 9.0, 8.0), _mat(ton, 0.95))
		_fenster_reihe(Vector3(x, 0, -8.18), 0.0, 3, 3.8, [2.2, 5.2, 7.8])

	_kneipenfront_bauen()
	_skyline_bauen()

	# Straßenmöbel und Grün.
	for daten in [[215.0, 5.6], [235.0, 5.6], [255.0, 5.6], [222.0, -5.6], [246.0, -5.6]]:
		_prop(_BAUM, Vector3(daten[0], 0, daten[1]), daten[0] * 0.7, 1.05)
	_prop(_LATERNE, Vector3(228.0, 0, -5.4), 0.0)
	_prop(_LATERNE, Vector3(262.0, 0, 5.4), PI)
	_prop(_BANK, Vector3(240.0, 0, 5.8), PI)
	_prop(_AUTO, Vector3(217.0, 0, 3.4), PI / 2.0)
	_prop(_AUTO, Vector3(268.0, 0, -3.4), -PI / 2.0)

	# Unsichtbare Banden: die Straße ist der Spielraum.
	_bande(Vector3(257, 2, 8.0), Vector3(130, 4, 0.5))
	_bande(Vector3(257, 2, -8.0), Vector3(130, 4, 0.5))
	_bande(Vector3(196, 2, 0), Vector3(0.5, 4, 20))
	_bande(Vector3(314, 2, 0), Vector3(0.5, 4, 20))


func _kneipenfront_bauen() -> void:
	# Die Apfelweinkneipe: letztes Haus der Südzeile, warm beleuchtete Tür.
	var fachwerk := _tex_mat("res://assets/texturen/ffm/fachwerk.png", 0.32,
		Color(0.95, 0.9, 0.82))
	_kasten(Vector3(300, 3.25, 12.2), Vector3(16, 6.5, 8.0), fachwerk)
	var tuer := _TUER.instantiate() as Node3D
	add_child(tuer)
	tuer.position = Vector3(300, 1.48, 8.18)
	tuer.rotation.y = PI
	_fenster_reihe(Vector3(294.5, 0, 8.18), PI, 1, 3.0, [2.0])
	_fenster_reihe(Vector3(305.5, 0, 8.18), PI, 1, 3.0, [2.0])

	var schild := Label3D.new()
	schild.text = "ZUM GERIPPTEN — APFELWEIN"
	schild.font_size = 96
	schild.pixel_size = 0.004
	schild.modulate = Color(0.25, 0.16, 0.08)
	add_child(schild)
	schild.position = Vector3(300, 3.6, 8.12)
	schild.rotation.y = PI
	var brett := _kasten(Vector3(300, 3.6, 8.16), Vector3(4.6, 0.7, 0.06),
		_mat(Color(0.92, 0.88, 0.78), 0.8))
	brett.rotation.y = 0.0

	var lampe := OmniLight3D.new()
	lampe.light_color = Color(1.0, 0.85, 0.6)
	lampe.light_energy = 1.2
	lampe.omni_range = 6.0
	add_child(lampe)
	lampe.position = Vector3(300, 3.1, 7.2)

	# Zwei Bembel als Deko vor dem Fenster.
	_prop(_BEMBEL, Vector3(295.6, 1.15, 7.9), 0.6, 1.6)
	_prop(_BEMBEL, Vector3(304.6, 1.15, 7.9), -0.4, 1.6)


func _skyline_bauen() -> void:
	# Die Bankentürme hinter Sachsenhausen — weit weg, im Tageslicht-Dunst.
	var glas := _tex_mat("res://assets/texturen/ffm/skyline.png", 0.06,
		Color(0.82, 0.87, 0.95))
	var rng := RandomNumberGenerator.new()
	rng.seed = 69
	var tuerme: Array = [
		[420.0, -60.0, 120.0, 24.0], [455.0, -20.0, 155.0, 28.0],
		[440.0, 30.0, 95.0, 20.0], [495.0, -80.0, 170.0, 30.0],
		[520.0, 10.0, 130.0, 26.0], [560.0, -40.0, 200.0, 34.0],
		[480.0, 70.0, 85.0, 22.0],
	]
	for turm: Array in tuerme:
		_kasten(Vector3(turm[0], turm[2] / 2.0, turm[1]),
			Vector3(turm[3], turm[2], turm[3] * 0.8), glas)
	# Eine Antennenspitze auf dem höchsten.
	_kasten(Vector3(560, 212, -40), Vector3(1.2, 24, 1.2), _mat(Color(0.4, 0.42, 0.45), 0.5))


# --- Kneipenstube (400, -100) ----------------------------------------------------


func _kneipe_bauen() -> void:
	var wand := _mat(Color(0.82, 0.74, 0.60), 0.95)
	var holz := _tex_mat("res://assets/texturen/ffm/holz.png", 0.5)
	var balken := _mat(Color(0.30, 0.21, 0.14), 0.9)

	_kasten(Vector3(400, 0.05, -100), Vector3(13, 0.1, 9.5), holz)          # Boden
	_kasten(Vector3(400, 3.55, -100), Vector3(13, 0.2, 9.5), balken)        # Decke
	_kasten(Vector3(400, 1.8, -104.8), Vector3(13, 3.6, 0.3), wand)         # Rückwand (Spielwand)
	_kasten(Vector3(400, 1.8, -95.2), Vector3(13, 3.6, 0.3), wand)
	_kasten(Vector3(393.4, 1.8, -100), Vector3(0.3, 3.6, 9.5), wand)
	_kasten(Vector3(406.6, 1.8, -100), Vector3(0.3, 3.6, 9.5), wand)
	for x in [396.0, 400.0, 404.0]:
		_kasten(Vector3(x, 3.35, -100), Vector3(0.25, 0.25, 9.5), balken)   # Deckenbalken

	# Ein „Fenster" mit Tageslicht: leuchtende Scheibe an der Ostwand.
	var tag := _kasten(Vector3(406.44, 1.9, -98.0), Vector3(0.05, 1.4, 2.2),
		_mat(Color(0.95, 0.97, 1.0), 0.4, Color(0.9, 0.95, 1.0), 1.6))
	tag.rotation.y = 0.0

	# Tresen, Tische, Bänke, Bembel-Regal.
	_kasten(Vector3(395.0, 0.55, -96.6), Vector3(2.8, 1.1, 0.8), balken)
	for daten in [[397.5, -101.8], [401.5, -101.2]]:
		var fuss := MeshInstance3D.new()
		var rohr := CylinderMesh.new()
		rohr.top_radius = 0.06
		rohr.bottom_radius = 0.08
		rohr.height = 0.72
		rohr.material = balken
		fuss.mesh = rohr
		add_child(fuss)
		fuss.position = Vector3(daten[0], 0.46, daten[1])
		var platte := MeshInstance3D.new()
		var scheibe := CylinderMesh.new()
		scheibe.top_radius = 0.55
		scheibe.bottom_radius = 0.55
		scheibe.height = 0.05
		scheibe.material = holz
		platte.mesh = scheibe
		add_child(platte)
		platte.position = Vector3(daten[0], 0.85, daten[1])
		_prop(_BEMBEL, Vector3(daten[0] + 0.15, 0.88, daten[1] - 0.1), 0.8)
	_prop(_BANK, Vector3(397.5, 0.1, -100.4), 0.0)
	_prop(_BANK, Vector3(401.5, 0.1, -99.9), 0.0)

	# Regal mit Bembeln an der Westwand.
	_kasten(Vector3(393.7, 1.5, -100.5), Vector3(0.25, 0.06, 3.4), balken)
	for i in 5:
		_prop(_BEMBEL, Vector3(393.7, 1.53, -102.0 + i * 0.7), i * 1.1)

	# Warmes Licht.
	for x in [397.0, 403.0]:
		var lampe := OmniLight3D.new()
		lampe.light_color = Color(1.0, 0.82, 0.55)
		lampe.light_energy = 1.6
		lampe.omni_range = 7.0
		add_child(lampe)
		lampe.position = Vector3(x, 3.0, -100)

	# Banden, damit in der Stube niemand durch Wände läuft.
	_bande(Vector3(400, 1.8, -104.6), Vector3(13, 3.6, 0.4))
	_bande(Vector3(400, 1.8, -95.4), Vector3(13, 3.6, 0.4))
	_bande(Vector3(393.6, 1.8, -100), Vector3(0.4, 3.6, 9.5))
	_bande(Vector3(406.4, 1.8, -100), Vector3(0.4, 3.6, 9.5))
