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
## Tagesvariante des Straßenbaums: das Nachtlaub ist bei Sonne ein
## schwarzer Klumpen (siehe `tools/make_props.py`).
const _BAUM := preload("res://assets/props/baum_tag.glb")
const _AUTO := preload("res://assets/props/auto.glb")
const _LKW := preload("res://assets/props/lkw.glb")
const _BEMBEL := preload("res://assets/props/bembel.glb")
const _LATERNE := preload("res://assets/props/laterne.glb")
const _BANK := preload("res://assets/props/bank.glb")
const _TISCH := preload("res://assets/props/bistrotisch.glb")
const _STUHL := preload("res://assets/props/bistrostuhl.glb")
const _BLUMEN := preload("res://assets/props/blumenkasten.glb")
const _FAHRRAD := preload("res://assets/props/fahrrad.glb")
const _WIRTSSCHILD := preload("res://assets/props/wirtshausschild.glb")

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


## Ein Material aus einem der Foto-Textursätze unter `assets/texturen/`
## (ambientCG, CC0 — dieselben, die Kapitel 1 tragen): Albedo mit Farbton,
## Normal-Map, Rauheitskarte, triplanar. Dasselbe Verfahren wie
## `kulisse.gd::_foto_mat`; die beiden Kapitel teilen ihre Kulissen nicht,
## nur die Textursätze.
func _foto_mat(satz: String, ton: Color, masstab: float = 0.22,
		relief: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = ton
	m.albedo_texture = load("res://assets/texturen/%s/albedo.jpg" % satz)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/texturen/%s/normal.jpg" % satz)
	m.normal_scale = relief
	m.roughness = 1.0
	m.roughness_texture = load("res://assets/texturen/%s/rauheit.jpg" % satz)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(masstab, masstab, masstab)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
	# Berliner Wand: schlichter Putz, kein Fachwerk.
	var putz := _foto_mat("putz", Color(0.74, 0.68, 0.55), 0.26, 0.9)
	_kasten(Vector3(0, 4.5, -8.3), Vector3(26, 9, 0.6), putz)
	_fenster_reihe(Vector3(0, 0, -7.98), 0.0, 5, 3.2, [2.4, 5.4])
	var tuer := _TUER.instantiate() as Node3D
	add_child(tuer)
	tuer.position = Vector3(-5.6, 1.48, -7.98)
	# Gehweg und Fahrbahn.
	_kasten(Vector3(0, 0.04, -6.2), Vector3(26, 0.08, 3.6),
		_foto_mat("beton_platten", Color(0.76, 0.75, 0.72), 0.42, 0.7))
	_kasten(Vector3(0, 0.01, -1.5), Vector3(26, 0.02, 6.0),
		_foto_mat("asphalt", Color(0.42, 0.42, 0.44), 0.18, 1.0))
	# Der beladene LKW am Bordstein, Schnauze nach links (-X) — weit genug
	# rechts, dass das Fahrerhaus der Abschiedskamera nicht im Bild steht.
	_prop(_LKW, Vector3(6.4, 0, -2.6), -PI / 2.0)
	_prop(_LATERNE, Vector3(-7.0, 0, -5.8), PI)
	_prop(_BAUM, Vector3(9.5, 0, -5.9), 0.7)


# --- Autobahn (z = 300) ---------------------------------------------------------


func _autobahn_bauen() -> void:
	# Trockener Tagesasphalt: derselbe Foto-Satz wie in Berlin, nur hell
	# getönt und rau — der nasse Nachtasphalt dort ist fast schwarz.
	var asphalt := _foto_mat("asphalt", Color(0.46, 0.46, 0.48), 0.16, 1.0)
	var gras := _mat(Color(0.34, 0.45, 0.23), 1.0)
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
	# Boden aus Foto-Materialien: Kopfstein für die Gasse, Platten für die
	# Gehwege. Vorher lagen hier zwei flache Farbflächen — bei Tageslicht der
	# deutlichste Unterschied zwischen Kapitel 1 und 2.
	var kopfstein := _foto_mat("schotter", Color(0.62, 0.60, 0.58), 0.5, 1.1)
	var gehweg := _foto_mat("beton_platten", Color(0.78, 0.77, 0.74), 0.42, 0.7)

	_kasten(Vector3(257, 0.01, 0), Vector3(130, 0.02, 10.0), kopfstein)
	_kasten(Vector3(257, 0.045, 6.6), Vector3(130, 0.09, 3.2), gehweg)
	_kasten(Vector3(257, 0.045, -6.6), Vector3(130, 0.09, 3.2), gehweg)
	# Bordsteinkante, damit der Gehweg eine Kante hat statt einer Farbgrenze.
	var bord := _foto_mat("beton_rau", Color(0.66, 0.65, 0.62), 0.5, 0.8)
	for z in [5.0, -5.0]:
		_kasten(Vector3(257, 0.05, z), Vector3(130, 0.10, 0.22), bord)

	# Südzeile: Fachwerk — Putzgefache aus dem Foto-Satz, die Balken als
	# echte Geometrie davor (siehe _fachwerk_balken). Die Häuser stoßen
	# aneinander: eine Altstadtzeile mit Lücken sieht aus wie eine Reihe
	# freistehender Klötze.
	for i in 5:
		var x := 208.0 + i * 14.0
		var hoehe := 7.5 if i % 2 == 0 else 8.3
		_kasten(Vector3(x, hoehe / 2.0, 12.2), Vector3(14.2, hoehe, 8.0),
			_foto_mat("putz", Color(0.86, 0.82, 0.71), 0.30, 0.9))
		_fachwerk_balken(x, 14.0, hoehe, 8.16)
		_satteldach(Vector3(x, hoehe, 12.2), 14.4, 8.4)
		_fenster_reihe(Vector3(x, 0, 8.18), PI, 3, 5.6, [2.2, 5.2])
	# Nordzeile: Putzhäuser mit Fenstermodulen und Blumenkästen.
	for i in 5:
		var x := 210.0 + i * 15.0
		var ton: Color = PUTZTOENE[i % PUTZTOENE.size()]
		var hoehe := 9.0 if i % 2 == 0 else 9.8
		_kasten(Vector3(x, hoehe / 2.0, -12.2), Vector3(15.2, hoehe, 8.0),
			_foto_mat("putz", ton, 0.26, 0.9))
		_satteldach(Vector3(x, hoehe, -12.2), 15.4, 8.4)
		_fenster_reihe(Vector3(x, 0, -8.18), 0.0, 3, 3.8, [2.2, 5.2, 7.8])
		for versatz in [-3.8, 0.0, 3.8]:
			_prop(_BLUMEN, Vector3(x + versatz, 1.72, -8.02), 0.0)

	# Die Gasse schließen: quergestellte Häuser an beiden Enden, hinter den
	# Banden. Ohne sie endet der Blick in der weißen Bodenplatte.
	for daten in [[188.0, 10.5], [322.0, 11.5]]:
		var x: float = daten[0]
		var hoehe: float = daten[1]
		_kasten(Vector3(x, hoehe / 2.0, 0.0), Vector3(9.0, hoehe, 30.0),
			_foto_mat("putz", PUTZTOENE[1], 0.24, 0.9))
		_satteldach(Vector3(x, hoehe, 0.0), 9.4, 30.4, true)
		var nach_innen := 0.0 if x < 200.0 else PI
		var front := x + (4.6 if x < 200.0 else -4.6)
		_fenster_reihe(Vector3(front, 0, 0.0), PI / 2.0 + nach_innen, 4, 3.4,
			[2.4, 5.4, 8.2])

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
	# Abgestellte Räder — in Sachsenhausen lehnt an jeder zweiten Wand eins.
	for daten in [[232.0, 7.4, PI / 2.0], [251.0, -7.2, -PI / 2.0],
			[288.0, 7.3, PI / 2.0]]:
		_prop(_FAHRRAD, Vector3(daten[0], 0, daten[1]), daten[2])

	_passanten_setzen()

	# Unsichtbare Banden: die Straße ist der Spielraum.
	_bande(Vector3(257, 2, 8.0), Vector3(130, 4, 0.5))
	_bande(Vector3(257, 2, -8.0), Vector3(130, 4, 0.5))
	_bande(Vector3(196, 2, 0), Vector3(0.5, 4, 20))
	_bande(Vector3(314, 2, 0), Vector3(0.5, 4, 20))


## Ein Satteldach auf einem Hausklotz: zwei geneigte Flächen und die
## Giebeldreiecke dazwischen. Flach abgeschnittene Häuser sind das, woran
## man eine Kastenkulisse sofort erkennt — die Dachlinie macht die
## Silhouette.
##
## `laengs` dreht den First um 90°, für die quergestellten Häuser an den
## Enden der Gasse.
func _satteldach(traufe: Vector3, breite: float, tiefe: float,
		laengs: bool = false) -> void:
	var ziegel := _mat(Color(0.27, 0.14, 0.11), 0.9)
	var giebel := _mat(Color(0.62, 0.58, 0.52), 0.9)
	var spanne := tiefe if not laengs else breite
	var hoehe := spanne * 0.30
	var flaeche := sqrt(pow(spanne / 2.0, 2) + hoehe * hoehe)
	var neigung := atan2(hoehe, spanne / 2.0)

	for seite in [-1.0, 1.0]:
		var teil := MeshInstance3D.new()
		var form := BoxMesh.new()
		form.size = Vector3(breite if not laengs else flaeche, 0.16,
			flaeche if not laengs else tiefe)
		form.material = ziegel
		teil.mesh = form
		add_child(teil)
		if laengs:
			teil.position = traufe + Vector3(seite * spanne / 4.0, hoehe / 2.0, 0)
			teil.rotation.z = -seite * neigung
		else:
			teil.position = traufe + Vector3(0, hoehe / 2.0, seite * spanne / 4.0)
			teil.rotation.x = seite * neigung
	# Giebel: ein flaches Dreieck als zwei überlappende Keile anzunähern
	# wäre Aufwand ohne Gewinn — ein schmaler Kasten unter dem First reicht,
	# er wird von den Dachflächen fast vollständig verdeckt.
	for seite in [-1.0, 1.0]:
		var wand := MeshInstance3D.new()
		var form := BoxMesh.new()
		form.size = (Vector3(0.3, hoehe, tiefe * 0.5) if laengs
			else Vector3(breite * 0.5, hoehe, 0.3))
		form.material = giebel
		wand.mesh = form
		add_child(wand)
		wand.position = traufe + ((Vector3(seite * breite / 2.0, hoehe / 2.0, 0)
			if laengs else Vector3(0, hoehe / 2.0, seite * tiefe / 2.0)))


## Vier Passanten am Rand der Gasse. Kein eigenes Modell — umgefärbte
## Kopien von Anne und Oliver, in unterschiedlicher Größe (siehe
## `passant.gd`, dort steht auch, warum das trägt und wo die Grenze liegt).
## Sie stehen bewusst weit von der Laufstrecke entfernt.
func _passanten_setzen() -> void:
	var leute: Array = [
		# Ort, Blickrichtung, Modell, Größe, Kleidung, Haar
		[Vector3(221.0, 0.0, -6.4), 1.9, "oliver", 1.86,
			Color(0.22, 0.24, 0.28), Color(0.14, 0.11, 0.09)],
		[Vector3(243.5, 0.0, 6.9), -0.7, "anne", 1.66,
			Color(0.55, 0.24, 0.22), Color(0.28, 0.16, 0.09)],
		[Vector3(266.0, 0.0, -6.7), 2.6, "anne", 1.74,
			Color(0.20, 0.32, 0.30), Color(0.62, 0.52, 0.34)],
		[Vector3(281.0, 0.0, 7.0), 0.5, "oliver", 1.78,
			Color(0.42, 0.40, 0.30), Color(0.35, 0.28, 0.20)],
	]
	for daten: Array in leute:
		var person := Passant.new()
		person.modell_pfad = "res://actors/models/%s.glb" % daten[2]
		person.zielhoehe = daten[3]
		person.kleidung = daten[4]
		person.haar = daten[5]
		add_child(person)
		person.position = daten[0]
		person.rotation.y = daten[1]


## Echte Fachwerkbalken vor einer Putzfront: Schwelle, Rähm, Ständer und
## Andreaskreuze in den Feldern. Eine aufgemalte Fachwerktextur verrät sich
## bei Tag sofort — Fachwerk ist tiefes Relief, das Schatten wirft, und
## nichts davon lässt sich in eine Albedo malen.
##
## Alle Balken einer Front liegen in **einem** MultiMesh: ein Haus kostet
## damit einen Zeichenaufruf statt vierzig.
func _fachwerk_balken(mitte_x: float, breite: float, hoehe: float,
		front_z: float) -> void:
	const DICKE := 0.13
	const BALKEN := 0.24
	var lagen: Array = []   # je [Größe, Mitte, Drehung um Z]

	# Waagerechte: Schwelle unten, Riegel je Geschoss, Rähm oben.
	var geschosse := [0.35, hoehe / 2.0, hoehe - 0.35]
	for y: float in geschosse:
		lagen.append([Vector3(breite, BALKEN, DICKE), Vector3(0, y, 0), 0.0])
	# Senkrechte Ständer, gleichmäßig über die Front.
	var felder := 5
	for i in felder + 1:
		var x := -breite / 2.0 + breite * i / float(felder)
		lagen.append([Vector3(BALKEN, hoehe, DICKE), Vector3(x, hoehe / 2.0, 0), 0.0])
	# Andreaskreuze: in jedes zweite Feld beider Geschosse eine Strebe,
	# abwechselnd geneigt — regelmäßige Kreuze wirken wie ein Muster,
	# unregelmäßige wie ein Haus.
	var feldbreite := breite / float(felder)
	for etage in 2:
		var y_unten: float = geschosse[etage]
		var y_oben: float = geschosse[etage + 1]
		var feldhoehe := y_oben - y_unten
		for i in felder:
			# Ungerade Felder: die geraden Feldmitten sind die Fensterachsen
			# (siehe _fenster_reihe unten) — dort kreuzte die Strebe mitten
			# durchs Fenster.
			if i % 2 == 0:
				continue
			var x := -breite / 2.0 + feldbreite * (i + 0.5)
			var laenge := sqrt(feldbreite * feldbreite + feldhoehe * feldhoehe)
			var winkel: float = atan2(feldhoehe, feldbreite)
			if (i + etage) % 4 == 0:
				winkel = -winkel
			lagen.append([Vector3(BALKEN, laenge, DICKE),
				Vector3(x, (y_unten + y_oben) / 2.0, 0), winkel - PI / 2.0])

	var netz := MultiMesh.new()
	netz.transform_format = MultiMesh.TRANSFORM_3D
	var wuerfel := BoxMesh.new()
	wuerfel.size = Vector3.ONE
	netz.mesh = wuerfel
	netz.instance_count = lagen.size()
	for i in lagen.size():
		var lage: Array = lagen[i]
		var masse: Vector3 = lage[0]
		var ort: Vector3 = lage[1]
		var drehung: float = lage[2]
		# `scaled_local`, nicht `scaled`: Letzteres streckt den schon
		# gedrehten Balken entlang der Weltachsen — aus einer Strebe wird
		# dabei ein schiefer Stab, der aus dem Haus ragt.
		netz.set_instance_transform(i, Transform3D(
			Basis(Vector3.BACK, drehung).scaled_local(masse), ort))

	var traeger := MultiMeshInstance3D.new()
	traeger.multimesh = netz
	traeger.material_override = _mat(Color(0.26, 0.17, 0.11), 0.85)
	add_child(traeger)
	traeger.position = Vector3(mitte_x, 0.0, front_z)


func _kneipenfront_bauen() -> void:
	# Die Apfelweinkneipe: letztes Haus der Südzeile, warm beleuchtete Tür.
	_kasten(Vector3(300, 3.6, 12.2), Vector3(16, 7.2, 8.0),
		_foto_mat("putz", Color(0.88, 0.84, 0.72), 0.28, 0.9))
	_fachwerk_balken(300.0, 15.8, 7.2, 8.16)
	_satteldach(Vector3(300, 7.2, 12.2), 16.4, 8.4)
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
	schild.modulate = Color(0.93, 0.86, 0.66)
	add_child(schild)
	schild.position = Vector3(300, 4.15, 7.92)
	schild.rotation.y = PI
	var brett := _kasten(Vector3(300, 4.15, 7.96), Vector3(4.8, 0.72, 0.07),
		_mat(Color(0.20, 0.14, 0.09), 0.75))
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

	# Auslegerschild: liest man schon aus der Gasse, quer zur Fassade.
	_prop(_WIRTSSCHILD, Vector3(306.8, 3.2, 8.02), PI)

	# Außenbestuhlung — eine Apfelweinkneipe ohne Tische auf dem Gehweg ist
	# keine. Drei Tische mit je zwei Stühlen, die Stühle etwas verdreht:
	# exakt ausgerichtete Möbel sehen aus wie gerade aufgestellt.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3011
	for tisch_x in [293.4, 296.6, 304.4]:
		var z := 6.6 + rng.randf_range(-0.25, 0.25)
		_prop(_TISCH, Vector3(tisch_x, 0.09, z), rng.randf_range(0.0, TAU))
		for seite in [-1.0, 1.0]:
			_prop(_STUHL, Vector3(tisch_x + seite * 0.78, 0.09,
				z + rng.randf_range(-0.2, 0.2)),
				(PI / 2.0) * -seite + rng.randf_range(-0.35, 0.35))


func _skyline_bauen() -> void:
	# Die Bankentürme hinter Sachsenhausen — weit weg, im Tageslicht-Dunst.
	# Kühler und dunkler als die Gasse: so liest das Auge „weit weg".
	var glas := _tex_mat("res://assets/texturen/ffm/skyline.png", 0.06,
		Color(0.58, 0.66, 0.80))
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
