class_name KulisseFfm
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
const _ICE := preload("res://assets/props/ice.glb")
## Der Fahrzeugpark: Quaternius-NPC-Wagen (CC0, quaternius.com) — echte
## Proportionen (4,2 m lang, 1,2 m hoch), Front nach +Z wie die
## Projekt-Konvention, keine Skalierung nötig. Die GLBs kamen mit
## metallicFactor 1 und wurden einmalig gepatcht (siehe
## assets/props/quaternius/HERKUNFT.txt). Das Lackmaterial heißt je
## Modell anders (Blue, White, …) — getönt wird deshalb alles, was
## nicht Fenster, Anbau oder Leuchte ist. Das Taxi bleibt gelb.
const _AUTOS: Array = [
	preload("res://assets/props/quaternius/NormalCar1.glb"),
	preload("res://assets/props/quaternius/NormalCar2.glb"),
	preload("res://assets/props/quaternius/SUV.glb"),
	preload("res://assets/props/quaternius/Taxi.glb"),
]
## Diese Materialien sind kein Lack und werden nie getönt.
const _KEIN_LACK: Array[String] = [
	"Windows", "Black", "Grey", "Headlights", "TailLights",
]
## Deutsche Flottenfarben: viel Silber, Schwarz und Weiß, wenig Buntes.
const AUTO_FARBEN: Array[Color] = [
	Color(0.72, 0.73, 0.75), Color(0.10, 0.10, 0.11), Color(0.90, 0.90, 0.88),
	Color(0.35, 0.36, 0.38), Color(0.42, 0.10, 0.10), Color(0.13, 0.20, 0.38),
	Color(0.72, 0.73, 0.75), Color(0.10, 0.10, 0.11),
]
const _BEMBEL := preload("res://assets/props/bembel.glb")
const _LATERNE := preload("res://assets/props/laterne.glb")
const _BANK := preload("res://assets/props/bank.glb")
const _TISCH := preload("res://assets/props/bistrotisch.glb")
const _STUHL := preload("res://assets/props/bistrostuhl.glb")
const _BLUMEN := preload("res://assets/props/blumenkasten.glb")
const _FAHRRAD := preload("res://assets/props/fahrrad.glb")
const _WIRTSSCHILD := preload("res://assets/props/wirtshausschild.glb")
const _GERIPPTE := preload("res://assets/props/gerippte.glb")
const _TRESEN := preload("res://assets/props/tresen.glb")
const _BILDERRAHMEN := preload("res://assets/props/bilderrahmen.glb")
const _PENDELLAMPE := preload("res://assets/props/pendellampe.glb")

## Vom Kapitel animiert: der LKW auf der Autobahn.
var lkw_fahrt: Node3D
## Der ICE der Zug-Zwischenszene — das Kapitel schiebt ihn (wie den LKW).
var zug: Node3D
## Gegenverkehr auf der Autobahn, fährt von selbst.
var _gegenverkehr: Array = []
## Die Rotoren der Windräder — gedreht in `_process`.
var _windraeder: Array = []
## Die sechs Räder des fahrenden LKW, für die Drehung.
var _lkw_raeder: Array[Node3D] = []
## Karosserie des fahrenden LKW, für das Wippen der Federung.
var _lkw_karosserie: Node3D
var _lkw_ruhelage: Vector3 = Vector3.ZERO
## Tempo des LKW in m/s — das Kapitel setzt es beim Fahren.
var lkw_tempo: float = 0.0
var _wipp_uhr: float = 0.0

const PUTZTOENE: Array[Color] = [
	Color(0.78, 0.70, 0.55), Color(0.72, 0.66, 0.58), Color(0.77, 0.72, 0.60),
]


func _ready() -> void:
	_abschied_bauen()
	_autobahn_bauen()
	_bahn_bauen()
	_sachsenhausen_bauen()
	_kneipe_bauen()


func _process(delta: float) -> void:
	for auto in _gegenverkehr:
		auto.position.x -= 22.0 * delta
		if auto.position.x < -290.0:
			auto.position.x = 290.0
	# Windräder: langsam und majestätisch — echte Anlagen drehen mit
	# gut 10 Umdrehungen pro Minute.
	for rotor in _windraeder:
		(rotor as Node3D).rotation.z += delta * 1.1
	_lkw_beleben(delta)


## Baut ein zufälliges Straßenfahrzeug — auch das Fahrspiel bedient sich
## hier. Der Rückgabeknoten ist noch nicht eingehängt.
func auto_bauen(rng: RandomNumberGenerator) -> Node3D:
	var wahl := rng.randi() % _AUTOS.size()
	var auto := (_AUTOS[wahl] as PackedScene).instantiate() as Node3D
	if wahl == 3:
		return auto  # das Taxi bleibt gelb
	var ton: Color = AUTO_FARBEN[rng.randi() % AUTO_FARBEN.size()]
	auto_einfaerben(auto, ton)
	return auto


## Tönt den Lack eines Quaternius-Wagens. Der Lack heißt je Modell anders,
## deshalb wird alles getönt, was nicht in _KEIN_LACK steht.
static func auto_einfaerben(auto: Node3D, ton: Color) -> void:
	for kind in auto.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		if teil == null or teil.mesh == null:
			continue
		for s in teil.mesh.get_surface_count():
			var material := teil.get_active_material(s) as BaseMaterial3D
			if material == null or material.resource_name in _KEIN_LACK \
					or material.resource_name.begins_with("Material"):
				continue
			var kopie := material.duplicate() as BaseMaterial3D
			kopie.albedo_color = ton
			teil.set_surface_override_material(s, kopie)


## Was einen fahrenden LKW von einem geschobenen Klotz unterscheidet:
## drehende Räder und eine Karosserie, die auf der Federung arbeitet.
##
## Die Räder drehen sich um ihre eigene X-Achse mit `Tempo / Radius`; bei
## 21 m/s und 52 cm Radius sind das gut 40 rad/s. Das ist schneller, als
## 60 Bilder je Sekunde zeigen können (Stroboskop) — deshalb läuft die
## Drehung bewusst **gebremst** mit Faktor 0,45. Sie soll nach Fahrt
## aussehen, nicht stimmen; ein Rad, das rückwärts zu laufen scheint,
## ist schlimmer als ein zu langsames.
func _lkw_beleben(delta: float) -> void:
	if lkw_tempo <= 0.01 or _lkw_karosserie == null:
		return
	var winkel := lkw_tempo / 0.52 * 0.45 * delta
	for rad in _lkw_raeder:
		rad.rotate_x(winkel)
	_wipp_uhr += delta
	# Zwei überlagerte Schwingungen: die lange ist die Federung über
	# Fahrbahnwellen, die kurze der Motor im Standgas.
	var heben := sin(_wipp_uhr * 2.3) * 0.022 + sin(_wipp_uhr * 17.0) * 0.004
	var neigen := sin(_wipp_uhr * 1.7 + 0.8) * 0.0045
	_lkw_karosserie.position = _lkw_ruhelage + Vector3(0.0, heben, 0.0)
	_lkw_karosserie.rotation.z = neigen


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
	# Leitplanken mit Pfosten. Ein durchgehendes Band ohne Pfosten ist das,
	# woran eine Autobahnkulisse als Kulisse auffällt — die Pfosten geben
	# der Fahrt außerdem ihren Takt.
	for z in [295.0, 296.0]:
		_kasten(Vector3(0, 0.62, z), Vector3(620, 0.28, 0.07), metall)
	var pfosten := MultiMesh.new()
	pfosten.transform_format = MultiMesh.TRANSFORM_3D
	var pfahl := BoxMesh.new()
	pfahl.size = Vector3(0.10, 0.62, 0.10)
	pfahl.material = _mat(Color(0.50, 0.52, 0.54), 0.5)
	pfosten.mesh = pfahl
	var pfahl_orte: Array[Vector3] = []
	var px := -300.0
	while px < 300.0:
		pfahl_orte.append(Vector3(px, 0.31, 295.0))
		pfahl_orte.append(Vector3(px, 0.31, 296.0))
		px += 4.0
	pfosten.instance_count = pfahl_orte.size()
	for i in pfahl_orte.size():
		pfosten.set_instance_transform(i,
			Transform3D(Basis.IDENTITY, pfahl_orte[i]))
	var pfostentraeger := MultiMeshInstance3D.new()
	pfostentraeger.multimesh = pfosten
	add_child(pfostentraeger)

	# Leitpfosten am Fahrbahnrand mit rotem Rückstrahler — das deutscheste
	# Detail einer Autobahn, alle 50 m, und sie zählen die Fahrt mit.
	var leit := MultiMesh.new()
	leit.transform_format = MultiMesh.TRANSFORM_3D
	var pfahl2 := BoxMesh.new()
	pfahl2.size = Vector3(0.12, 1.00, 0.08)
	pfahl2.material = _mat(Color(0.90, 0.89, 0.86), 0.6)
	leit.mesh = pfahl2
	var leit_orte: Array[Vector3] = []
	px = -300.0
	while px < 300.0:
		leit_orte.append(Vector3(px, 0.50, 304.4))
		leit_orte.append(Vector3(px, 0.50, 286.6))
		px += 50.0
	leit.instance_count = leit_orte.size()
	for i in leit_orte.size():
		leit.set_instance_transform(i, Transform3D(Basis.IDENTITY, leit_orte[i]))
	var leittraeger := MultiMeshInstance3D.new()
	leittraeger.multimesh = leit
	add_child(leittraeger)
	for ort in leit_orte:
		_kasten(ort + Vector3(0, 0.32, -0.05 if ort.z > 295.0 else 0.05),
			Vector3(0.09, 0.10, 0.02),
			_mat(Color(0.62, 0.10, 0.08), 0.3, Color(0.7, 0.1, 0.08), 0.6))

	# Reifenspuren: zwei dunklere Bahnen je Fahrbahn. Frischer Asphalt ohne
	# Spuren sieht aus wie am Tag der Eröffnung.
	var spur := _mat(Color(0.34, 0.34, 0.36), 0.85)
	for z in [298.0, 301.6, 289.4, 293.0]:
		_kasten(Vector3(0, 0.045, z), Vector3(620, 0.005, 0.9), spur)
	# Querfugen im Beton, alle 12 m.
	var fugen := MultiMesh.new()
	fugen.transform_format = MultiMesh.TRANSFORM_3D
	var fuge := BoxMesh.new()
	fuge.size = Vector3(0.06, 0.008, 8.0)
	fuge.material = _mat(Color(0.28, 0.28, 0.30), 0.9)
	fugen.mesh = fuge
	var fugen_orte: Array[Vector3] = []
	px = -300.0
	while px < 300.0:
		fugen_orte.append(Vector3(px, 0.05, 300.0))
		fugen_orte.append(Vector3(px, 0.05, 291.0))
		px += 12.0
	fugen.instance_count = fugen_orte.size()
	for i in fugen_orte.size():
		fugen.set_instance_transform(i, Transform3D(Basis.IDENTITY, fugen_orte[i]))
	var fugentraeger := MultiMeshInstance3D.new()
	fugentraeger.multimesh = fugen
	add_child(fugentraeger)

	_autobahnbruecke(78.0)
	_autobahn_umgebung()

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
	# Räder und Karosserie merken, damit `_lkw_beleben` sie bewegen kann.
	# Das Modell liefert sie als eigene Knoten (`rad_0` … `rad_5`).
	for kind in lkw_fahrt.get_children():
		var teil := kind as Node3D
		if teil == null:
			continue
		if String(teil.name).begins_with("rad_"):
			_lkw_raeder.append(teil)
		elif String(teil.name).begins_with("karosserie"):
			_lkw_karosserie = teil
			_lkw_ruhelage = teil.position
	# Innenlicht für die Kabinen-Einstellung: unter dem Dach kommt kein
	# Sonnenlicht an, das Armaturenbrett wäre eine schwarze Fläche.
	if lkw_fahrt != null:
		var kabinenlicht := OmniLight3D.new()
		kabinenlicht.light_color = Color(0.90, 0.93, 1.0)
		kabinenlicht.light_energy = 1.5
		kabinenlicht.omni_range = 3.2
		kabinenlicht.shadow_enabled = false
		lkw_fahrt.add_child(kabinenlicht)
		kabinenlicht.position = Vector3(0.0, 2.25, 3.2)
	var rng_autos := RandomNumberGenerator.new()
	rng_autos.seed = 501
	for i in 3:
		var auto := auto_bauen(rng_autos)
		add_child(auto)
		auto.position = Vector3(-120.0 + i * 170.0, 0, 291.0)
		auto.rotation.y = -PI / 2.0
		_gegenverkehr.append(auto)


## Die Landschaft, die eine A5 zur A5 macht: Felder in Streifen (eines
## davon Raps), Windräder, eine Strommastenreihe, ein Dorf mit Kirchturm
## am Horizont, ein Stück Lärmschutzwand und Gebüsch am Rand. Alles
## billige Kästen — aber es sind *diese* Dinge, an denen das Auge
## „deutsche Autobahn" liest, nicht die Fahrbahn selbst.
func _autobahn_umgebung() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2107

	# Felder: breite Streifen hinter beiden Seiten, in Ackertönen.
	var toene: Array[Color] = [
		Color(0.42, 0.50, 0.24), Color(0.55, 0.47, 0.30), Color(0.86, 0.78, 0.22),
		Color(0.38, 0.46, 0.26), Color(0.48, 0.40, 0.28), Color(0.50, 0.56, 0.30),
	]
	var lauf := -300.0
	var reihe := 0
	while lauf < 300.0:
		var breite := rng.randf_range(60.0, 110.0)
		_kasten(Vector3(lauf + breite / 2.0, 0.008, 372.0),
			Vector3(breite, 0.02, 96.0), _mat(toene[reihe % toene.size()], 1.0))
		_kasten(Vector3(lauf + breite / 2.0, 0.008, 222.0),
			Vector3(breite, 0.02, 60.0), _mat(toene[(reihe + 3) % toene.size()], 1.0))
		lauf += breite
		reihe += 1

	# Windräder weit hinter der Gegenfahrbahn.
	for x in [-190.0, -60.0, 90.0, 230.0]:
		_windrad(Vector3(x + rng.randf_range(-15.0, 15.0), 0.0,
			rng.randf_range(180.0, 205.0)))

	# Strommasten mit Leitungen auf der eigenen Seite.
	var stahl := _mat(Color(0.55, 0.56, 0.58), 0.5)
	var mast_x: Array[float] = []
	var mx := -280.0
	while mx < 300.0:
		mast_x.append(mx)
		var fuss := Vector3(mx, 0.0, 352.0)
		_kasten(fuss + Vector3(0, 11.0, 0), Vector3(1.4, 22.0, 1.4), stahl)
		_kasten(fuss + Vector3(0, 21.0, 0), Vector3(9.0, 0.5, 0.5), stahl)
		_kasten(fuss + Vector3(0, 17.5, 0), Vector3(6.5, 0.5, 0.5), stahl)
		mx += 105.0
	for i in mast_x.size() - 1:
		for arm: Vector3 in [Vector3(-3.6, 20.7, 0), Vector3(3.6, 20.7, 0),
				Vector3(-2.4, 17.2, 0), Vector3(2.4, 17.2, 0)]:
			var a: Vector3 = Vector3(mast_x[i], 0, 352.0) + arm
			var b: Vector3 = Vector3(mast_x[i + 1], 0, 352.0) + arm
			_kasten((a + b) / 2.0 - Vector3(0, 0.8, 0),
				Vector3(a.distance_to(b), 0.06, 0.06),
				_mat(Color(0.25, 0.25, 0.27), 0.6))

	# Ein Stück Lärmschutzwand an der eigenen Seite.
	var wand := _foto_mat("beton_rau", Color(0.55, 0.58, 0.52), 0.3, 0.8)
	_kasten(Vector3(-160.0, 2.1, 307.5), Vector3(90.0, 4.2, 0.5), wand)
	for px in range(-200, -115, 12):
		_kasten(Vector3(px, 2.3, 307.5), Vector3(0.4, 4.6, 0.7),
			_mat(Color(0.4, 0.42, 0.44), 0.6))

	# Gebüsch am Fahrbahnrand: flache dunkelgrüne Kugeln als MultiMesh.
	var busch := MultiMesh.new()
	busch.transform_format = MultiMesh.TRANSFORM_3D
	var kugel := SphereMesh.new()
	kugel.radius = 1.0
	kugel.height = 1.4
	kugel.radial_segments = 10
	kugel.rings = 5
	kugel.material = _mat(Color(0.20, 0.30, 0.16), 1.0)
	busch.mesh = kugel
	var busch_orte: Array[Transform3D] = []
	for i in 44:
		var bx := rng.randf_range(-290.0, 290.0)
		var bz := 309.0 + rng.randf_range(0.0, 5.0) if i % 2 == 0 \
			else 281.5 - rng.randf_range(0.0, 5.0)
		var gr := rng.randf_range(0.7, 1.6)
		busch_orte.append(Transform3D(
			Basis.IDENTITY.scaled(Vector3(gr, gr * 0.8, gr)),
			Vector3(bx, 0.5 * gr, bz)))
	busch.instance_count = busch_orte.size()
	for i in busch_orte.size():
		busch.set_instance_transform(i, busch_orte[i])
	var buschtraeger := MultiMeshInstance3D.new()
	buschtraeger.multimesh = busch
	add_child(buschtraeger)

	# Ein Dorf am Horizont: Häuschen mit Satteldächern um einen Kirchturm.
	var putz := _mat(Color(0.82, 0.79, 0.72), 0.9)
	var dachrot := _mat(Color(0.52, 0.28, 0.20), 0.9)
	for i in 9:
		var hx := -40.0 + rng.randf_range(-45.0, 45.0)
		var hz := 415.0 + rng.randf_range(-12.0, 12.0)
		var hb := rng.randf_range(6.0, 10.0)
		var hh := rng.randf_range(4.0, 6.0)
		_kasten(Vector3(hx, hh / 2.0, hz), Vector3(hb, hh, hb * 0.8), putz)
		var dach := MeshInstance3D.new()
		var prisma := PrismMesh.new()
		prisma.size = Vector3(hb + 0.6, hh * 0.5, hb * 0.8 + 0.6)
		prisma.material = dachrot
		dach.mesh = prisma
		add_child(dach)
		dach.position = Vector3(hx, hh + hh * 0.25, hz)
	# Kirchturm mit Spitzhelm.
	_kasten(Vector3(-38.0, 9.0, 418.0), Vector3(5.0, 18.0, 5.0), putz)
	var helm := MeshInstance3D.new()
	var kegel := CylinderMesh.new()
	kegel.top_radius = 0.0
	kegel.bottom_radius = 3.4
	kegel.height = 7.0
	kegel.radial_segments = 8
	kegel.material = _mat(Color(0.28, 0.32, 0.36), 0.7)
	helm.mesh = kegel
	add_child(helm)
	helm.position = Vector3(-38.0, 21.5, 418.0)


## Ein Windrad: Rohrmast, Gondel, drei Blätter an einem Rotorknoten, der
## sich in `_process` dreht. Nichts sagt schneller „deutsche Autobahn".
func _windrad(fuss: Vector3) -> void:
	var weiss := _mat(Color(0.88, 0.89, 0.90), 0.6)
	var mast := MeshInstance3D.new()
	var rohr := CylinderMesh.new()
	rohr.top_radius = 0.7
	rohr.bottom_radius = 1.3
	rohr.height = 42.0
	rohr.radial_segments = 12
	rohr.material = weiss
	mast.mesh = rohr
	add_child(mast)
	mast.position = fuss + Vector3(0, 21.0, 0)
	_kasten(fuss + Vector3(0, 42.5, 0.6), Vector3(2.2, 2.4, 5.0), weiss)
	var rotor := Node3D.new()
	add_child(rotor)
	# Die Gondel schaut zur Autobahn (-Z): der Rotor sitzt davor.
	rotor.position = fuss + Vector3(0, 42.5, -2.2)
	for i in 3:
		var blatt := MeshInstance3D.new()
		var form := BoxMesh.new()
		form.size = Vector3(1.1, 16.0, 0.35)
		form.material = weiss
		blatt.mesh = form
		rotor.add_child(blatt)
		blatt.position = Vector3(0, 0, 0)
		blatt.rotation.z = TAU * i / 3.0
		# Blattwurzel an der Nabe: das Blatt hängt an seinem unteren Ende.
		blatt.position = blatt.transform.basis.y * 8.0
	_windraeder.append(rotor)


## Eine Brücke über die Autobahn. Sie kostet fünf Kästen und ist der
## stärkste Fahr-Eindruck, den es für das Geld gibt: etwas kommt heran,
## huscht über einen weg und ist vorbei. Ohne so etwas wirkt eine geraden
## Autobahn wie ein Laufband.
func _autobahnbruecke(x: float) -> void:
	var beton := _foto_mat("beton_rau", Color(0.72, 0.71, 0.68), 0.22, 0.8)
	var kappe := _mat(Color(0.66, 0.65, 0.62), 0.8)
	# Überbau, leicht überhöht, plus Geländer.
	_kasten(Vector3(x, 6.30, 295.5), Vector3(9.0, 0.95, 42.0), beton)
	_kasten(Vector3(x - 4.6, 6.95, 295.5), Vector3(0.35, 1.05, 42.0), kappe)
	_kasten(Vector3(x + 4.6, 6.95, 295.5), Vector3(0.35, 1.05, 42.0), kappe)
	# Widerlager außerhalb der Fahrbahnen, dazu ein Mittelpfeiler.
	for z in [316.0, 275.0]:
		_kasten(Vector3(x, 2.90, z), Vector3(8.4, 6.80, 4.0), beton)
	_kasten(Vector3(x, 2.90, 295.5), Vector3(7.0, 6.80, 1.4), beton)


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


# --- Bahnstrecke und Bahnsteig (z 500) --------------------------------------------


## Die Zug-Zwischenszene: eine zweigleisige Strecke hinter den Feldern,
## dazu ein Bahnsteig mit Dach, Schild und Uhr — genug „Frankfurt Hbf",
## dass die Begrüßung einen Ort hat. Der Zug selbst hängt an `zug`;
## bewegt wird er vom Kapitel (wie der LKW auf der Autobahn).
func _bahn_bauen() -> void:
	var gras := _mat(Color(0.40, 0.48, 0.26), 1.0)
	var schotter := _foto_mat("schotter", Color(0.58, 0.56, 0.54), 0.4, 1.1)
	var stahl := _mat(Color(0.42, 0.43, 0.46), 0.35)
	stahl.metallic = 0.5
	var dunkel := _mat(Color(0.20, 0.20, 0.22), 0.8)
	var beton := _foto_mat("beton_platten", Color(0.72, 0.72, 0.74), 0.4, 0.7)

	# Wiesen- und Ackerstreifen schließen an die Autobahnfelder (bis z 420) an;
	# südlich der Strecke erst Wiese, der Acker beginnt weiter hinten.
	_kasten(Vector3(210.0, 0.005, 460.0), Vector3(380.0, 0.02, 80.0), gras)
	_kasten(Vector3(210.0, 0.005, 519.0), Vector3(380.0, 0.02, 38.0), gras)
	_kasten(Vector3(210.0, 0.005, 557.0), Vector3(380.0, 0.02, 38.0),
		_mat(Color(0.52, 0.46, 0.28), 1.0))

	# Bahndamm: Schotterbett, Schwellen (ein MultiMesh je Gleis), Schienen.
	# Gleis 1 (z 500) liegt am Bahnsteig, Gleis 2 (z 509,4) dahinter —
	# erst das zweite Gleis macht aus einem Damm einen Bahnhof.
	for gleis_z in [500.0, 509.4]:
		_kasten(Vector3(210.0, 0.17, gleis_z), Vector3(360.0, 0.34, 7.0), schotter)
		var schwellen := MultiMesh.new()
		schwellen.transform_format = MultiMesh.TRANSFORM_3D
		var holz := BoxMesh.new()
		holz.size = Vector3(0.26, 0.16, 2.6)
		holz.material = _mat(Color(0.30, 0.26, 0.22), 0.95)
		schwellen.mesh = holz
		var plaetze := int(356.0 / 0.8)
		schwellen.instance_count = plaetze
		for i in plaetze:
			schwellen.set_instance_transform(i, Transform3D(Basis.IDENTITY,
				Vector3(32.0 + i * 0.8, 0.32, gleis_z)))
		var traeger := MultiMeshInstance3D.new()
		traeger.multimesh = schwellen
		add_child(traeger)
		for seite in [-0.7175, 0.7175]:
			_kasten(Vector3(210.0, 0.50, gleis_z + seite),
				Vector3(356.0, 0.16, 0.08), stahl)

	# Oberleitung: Masten mit Ausleger, darüber der Fahrdraht.
	var mx := 44.0
	while mx < 385.0:
		_kasten(Vector3(mx, 3.30, 496.4), Vector3(0.30, 6.6, 0.30), dunkel)
		_kasten(Vector3(mx, 6.10, 498.2), Vector3(0.12, 0.12, 3.9), dunkel)
		mx += 36.0
	_kasten(Vector3(210.0, 5.55, 500.0), Vector3(356.0, 0.05, 0.05), dunkel)

	# Der Bahnsteig (Südseite): Kante auf Wagenbodenhöhe, weißer
	# Sicherheitsstreifen, Dach auf Stützen, Stationsschilder, Uhr, Bänke.
	_kasten(Vector3(285.0, 0.575, 504.6), Vector3(96.0, 1.15, 5.7), beton)
	_bande(Vector3(285.0, 0.575, 504.6), Vector3(96.0, 1.15, 5.7))
	_kasten(Vector3(285.0, 1.16, 502.05), Vector3(96.0, 0.03, 0.35),
		_mat(Color(0.88, 0.88, 0.86), 0.6))
	var sx := 249.0
	while sx < 325.0:
		_kasten(Vector3(sx, 2.85, 505.2), Vector3(0.28, 3.40, 0.28), dunkel)
		sx += 12.0
	_kasten(Vector3(285.0, 4.62, 504.9), Vector3(84.0, 0.12, 5.4),
		_mat(Color(0.80, 0.81, 0.83), 0.5))
	for schild_x in [255.0, 285.0, 315.0]:
		_bahnhofsschild(Vector3(schild_x, 3.55, 504.2))
	_bahnhofsuhr(Vector3(270.0, 3.35, 504.2))
	for bank_x in [262.0, 298.0]:
		_prop(_BANK, Vector3(bank_x, 1.16, 506.2), 0.0)

	# Ein paar Bäume als Tiefenstaffelung um die Strecke.
	for baum in [[96.0, 522.0], [118.0, 531.0], [205.0, 521.0],
			[118.0, 476.0], [352.0, 524.0], [372.0, 481.0]]:
		_prop(_BAUM, Vector3(baum[0], 0.0, baum[1]), baum[0] * 0.7, 1.2)

	# Der Zug: Front zeigt nach +Z, mit PI/2 fährt er in +X — dieselbe
	# Konvention wie beim LKW. Startlage setzt das Kapitel.
	zug = _ICE.instantiate() as Node3D
	add_child(zug)
	zug.rotation.y = PI / 2.0
	zug.position = Vector3(20.0, 0.58, 500.0)


## Weißes „Frankfurt (Main) Hbf" auf DB-Blau, von beiden Seiten lesbar.
func _bahnhofsschild(ort: Vector3) -> void:
	_kasten(ort, Vector3(4.0, 0.62, 0.10), _mat(Color(0.08, 0.19, 0.42), 0.5))
	for seite in [-1.0, 1.0]:
		var text := Label3D.new()
		text.text = "Frankfurt (Main) Hbf"
		text.font_size = 96
		text.pixel_size = 0.004
		text.modulate = Color(0.96, 0.96, 0.98)
		add_child(text)
		text.position = ort + Vector3(0.0, 0.0, 0.06 * seite)
		if seite < 0.0:
			text.rotation.y = PI
	for haenger in [-1.6, 1.6]:
		_kasten(ort + Vector3(haenger, 0.60, 0.0), Vector3(0.06, 0.62, 0.06),
			_mat(Color(0.20, 0.20, 0.22), 0.8))


## Die Bahnhofsuhr: weiße Scheibe, zwei Zeiger, kurz vor fünf.
func _bahnhofsuhr(ort: Vector3) -> void:
	var zeiger := _mat(Color(0.10, 0.10, 0.12), 0.6)
	_kasten(ort + Vector3(0, 0.62, 0), Vector3(0.08, 0.72, 0.08), zeiger)
	for seite in [-1.0, 1.0]:
		var blatt := MeshInstance3D.new()
		var scheibe := CylinderMesh.new()
		scheibe.top_radius = 0.36
		scheibe.bottom_radius = 0.36
		scheibe.height = 0.05
		scheibe.material = _mat(Color(0.94, 0.94, 0.92), 0.4)
		blatt.mesh = scheibe
		add_child(blatt)
		blatt.position = ort + Vector3(0, 0, 0.03 * seite)
		blatt.rotation.x = PI / 2.0
		_kasten(ort + Vector3(0.0, 0.09, 0.062 * seite),
			Vector3(0.035, 0.24, 0.012), zeiger)
		_kasten(ort + Vector3(-0.09, 0.0, 0.062 * seite),
			Vector3(0.22, 0.035, 0.012), zeiger)


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
	# Zwei Geparkte aus dem Kenney-Fahrzeugpark, in gedeckten Farben.
	var rng_gasse := RandomNumberGenerator.new()
	rng_gasse.seed = 217
	for daten: Array in [[Vector3(217.0, 0, 3.4), PI / 2.0],
			[Vector3(268.0, 0, -3.4), -PI / 2.0]]:
		var wagen := auto_bauen(rng_gasse)
		add_child(wagen)
		wagen.position = daten[0]
		wagen.rotation.y = daten[1]
	# Abgestellte Räder — in Sachsenhausen lehnt an jeder zweiten Wand eins.
	for daten in [[232.0, 7.4, PI / 2.0], [251.0, -7.2, -PI / 2.0],
			[288.0, 7.3, PI / 2.0]]:
		# Reifen-Tiefpunkt des neu gebauten Rades liegt bei −0,049.
		_prop(_FAHRRAD, Vector3(daten[0], 0.05, daten[1]), daten[2])

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
## `actors/passant.gd`, dort steht auch, warum das trägt und wo die
## Grenze liegt). Sie stehen bewusst weit von der Laufstrecke entfernt;
## ohne Wegpunkte stehen sie einfach (Mocap-Ruhebewegung von `Figur`).
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
		person.kleid_ton = daten[4]
		person.haar_ton = daten[5]
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
	# Die Skyline hinter Sachsenhausen — und zwar *die* Skyline. Frankfurt
	# erkennt man an drei Silhouetten, nicht an grauen Klötzen:
	# der Commerzbank-Turm (dreieckiger Grundriss, gelber Mast), der
	# Messeturm (roter Granit, Pyramidenspitze) und der Main Tower
	# (runder Glaszylinder mit Antenne). Dahinter generische Füllung.
	var glas := _tex_mat("res://assets/texturen/ffm/skyline.png", 0.06,
		Color(0.58, 0.66, 0.80))
	var granit := _mat(Color(0.66, 0.52, 0.46), 0.7)
	var metall := _mat(Color(0.55, 0.57, 0.60), 0.5)

	# Commerzbank Tower: dreiseitiges Prisma (CylinderMesh mit 3 Segmenten),
	# obendrauf der gelbe Mast.
	var commerz := MeshInstance3D.new()
	var drei := CylinderMesh.new()
	drei.top_radius = 20.0
	drei.bottom_radius = 20.0
	drei.height = 185.0
	drei.radial_segments = 3
	drei.material = glas
	commerz.mesh = drei
	add_child(commerz)
	commerz.position = Vector3(520.0, 92.5, -20.0)
	commerz.rotation.y = 0.4
	_kasten(Vector3(520.0, 200.0, -20.0), Vector3(1.6, 36.0, 1.6),
		_mat(Color(0.85, 0.75, 0.30), 0.5, Color(0.9, 0.8, 0.3), 0.3))

	# Messeturm: quadratischer Schaft, Rücksprung, Pyramidenspitze.
	_kasten(Vector3(560.0, 75.0, 45.0), Vector3(26.0, 150.0, 26.0), granit)
	_kasten(Vector3(560.0, 158.0, 45.0), Vector3(17.0, 18.0, 17.0), granit)
	var pyramide := MeshInstance3D.new()
	var spitz := CylinderMesh.new()
	spitz.top_radius = 0.0
	spitz.bottom_radius = 12.0
	spitz.height = 22.0
	spitz.radial_segments = 4
	spitz.material = _mat(Color(0.60, 0.42, 0.38), 0.6)
	pyramide.mesh = spitz
	add_child(pyramide)
	pyramide.position = Vector3(560.0, 178.0, 45.0)
	pyramide.rotation.y = PI / 4.0

	# Main Tower: runder Glaszylinder mit Antennenspitze.
	var main := MeshInstance3D.new()
	var rund := CylinderMesh.new()
	rund.top_radius = 13.0
	rund.bottom_radius = 13.0
	rund.height = 145.0
	rund.radial_segments = 20
	rund.material = glas
	main.mesh = rund
	add_child(main)
	main.position = Vector3(470.0, 72.5, 15.0)
	_kasten(Vector3(470.0, 165.0, 15.0), Vector3(1.2, 40.0, 1.2), metall)

	# Füllung dahinter: die generischen Kästen bleiben, etwas versetzt.
	var tuerme: Array = [
		[420.0, -60.0, 110.0, 24.0], [452.0, -95.0, 150.0, 28.0],
		[440.0, 75.0, 95.0, 20.0], [505.0, -70.0, 128.0, 26.0],
		[545.0, -45.0, 165.0, 30.0], [595.0, 0.0, 140.0, 32.0],
		[480.0, 100.0, 85.0, 22.0], [610.0, 60.0, 120.0, 28.0],
	]
	for turm: Array in tuerme:
		_kasten(Vector3(turm[0], turm[2] / 2.0, turm[1]),
			Vector3(turm[3], turm[2], turm[3] * 0.8), glas)


# --- Kneipenstube (400, -100) ----------------------------------------------------


func _kneipe_bauen() -> void:
	var wand := _foto_mat("putz", Color(0.80, 0.72, 0.58), 0.34, 0.8)
	var holz := _tex_mat("res://assets/texturen/ffm/holz.png", 0.5,
		Color(0.58, 0.47, 0.38))
	var balken := _mat(Color(0.26, 0.17, 0.11), 0.85)
	var vertaefelung := _mat(Color(0.34, 0.21, 0.13), 0.6)

	_kasten(Vector3(400, 0.05, -100), Vector3(13, 0.1, 9.5), holz)          # Boden
	_kasten(Vector3(400, 3.55, -100), Vector3(13, 0.2, 9.5), balken)        # Decke
	_kasten(Vector3(400, 1.8, -104.8), Vector3(13, 3.6, 0.3), wand)         # Rückwand (Spielwand)
	_kasten(Vector3(400, 1.8, -95.2), Vector3(13, 3.6, 0.3), wand)
	_kasten(Vector3(393.4, 1.8, -100), Vector3(0.3, 3.6, 9.5), wand)
	_kasten(Vector3(406.6, 1.8, -100), Vector3(0.3, 3.6, 9.5), wand)
	for x in [396.0, 400.0, 404.0]:
		_kasten(Vector3(x, 3.35, -100), Vector3(0.25, 0.25, 9.5), balken)   # Deckenbalken

	# Holzvertäfelung bis Brusthöhe mit Abschlussleiste — der Unterschied
	# zwischen „Wirtsstube" und „weißer Raum mit Möbeln". Sie läuft rings
	# um alle vier Wände, knapp vor dem Putz.
	for daten in [
			[Vector3(400, 0.60, -104.58), Vector3(12.6, 1.20, 0.06)],
			[Vector3(400, 0.60, -95.42), Vector3(12.6, 1.20, 0.06)],
			[Vector3(393.58, 0.60, -100), Vector3(0.06, 1.20, 9.2)],
			[Vector3(406.42, 0.60, -100), Vector3(0.06, 1.20, 9.2)]]:
		_kasten(daten[0], daten[1], vertaefelung)
	for daten in [
			[Vector3(400, 1.23, -104.55), Vector3(12.6, 0.08, 0.10)],
			[Vector3(400, 1.23, -95.45), Vector3(12.6, 0.08, 0.10)],
			[Vector3(393.55, 1.23, -100), Vector3(0.10, 0.08, 9.2)],
			[Vector3(406.45, 1.23, -100), Vector3(0.10, 0.08, 9.2)]]:
		_kasten(daten[0], daten[1], balken)

	_kneipenfenster_bauen()
	_schankraum_bauen()
	_stube_moeblieren(holz, balken)

	# Pendellampen: sichtbare Leuchten über den Tischen und dem Wurftisch.
	# Ein warmer Lichtfleck ohne Lampe darüber liest sich als Fehler.
	for x in [396.6, 400.0, 403.4]:
		_prop(_PENDELLAMPE, Vector3(x, 3.42, -100.0))
		var lampe := OmniLight3D.new()
		lampe.light_color = Color(1.0, 0.80, 0.52)
		lampe.light_energy = 1.5
		lampe.omni_range = 6.5
		lampe.shadow_enabled = true
		add_child(lampe)
		lampe.position = Vector3(x, 2.85, -100.0)
	# Über dem Wurftisch hängt eine eigene, tiefer sitzende Lampe.
	_prop(_PENDELLAMPE, Vector3(400.0, 3.42, -103.0))
	var wurflicht := OmniLight3D.new()
	wurflicht.light_color = Color(1.0, 0.86, 0.62)
	wurflicht.light_energy = 2.2
	wurflicht.omni_range = 5.0
	add_child(wurflicht)
	wurflicht.position = Vector3(400.0, 2.85, -103.0)


## Das Fenster zur Gasse: Rahmen, Sprossen, Bank und dahinter der helle
## Tag. Vorher stand hier eine leuchtende Platte in der Wand — von innen
## sah das aus wie ein Loch mit Licht dahinter, was es ja auch war.
func _kneipenfenster_bauen() -> void:
	var rahmen := _mat(Color(0.86, 0.83, 0.76), 0.7)
	var tageslicht := _mat(Color(0.95, 0.97, 1.0), 0.4,
		Color(0.90, 0.94, 1.0), 2.2)
	for z in [-97.6, -101.4]:
		# Die Scheibe sitzt in der Laibung, nicht in der Wandfläche.
		var scheibe := _kasten(Vector3(406.30, 1.95, z),
			Vector3(0.04, 1.30, 1.90), tageslicht)
		scheibe.rotation.y = 0.0
		for teil in [
				[Vector3(406.24, 2.66, z), Vector3(0.14, 0.12, 2.10)],
				[Vector3(406.24, 1.24, z), Vector3(0.16, 0.14, 2.10)],
				[Vector3(406.24, 1.95, z - 1.02), Vector3(0.14, 1.54, 0.12)],
				[Vector3(406.24, 1.95, z + 1.02), Vector3(0.14, 1.54, 0.12)],
				[Vector3(406.22, 1.95, z), Vector3(0.10, 1.30, 0.05)],
				[Vector3(406.22, 1.95, z), Vector3(0.10, 0.05, 1.90)]]:
			_kasten(teil[0], teil[1], rahmen)
		# Fensterbank mit zwei Gläsern darauf.
		_kasten(Vector3(406.12, 1.20, z), Vector3(0.34, 0.06, 2.10), rahmen)
		_prop(_GERIPPTE, Vector3(406.10, 1.23, z - 0.35), 0.4)
		_prop(_GERIPPTE, Vector3(406.10, 1.23, z + 0.28), 2.1)


## Der Schankraum: Tresen, Rückbuffet mit Flaschen und Gläsern, Bembel
## auf dem Tresen, der Wirt dahinter.
func _schankraum_bauen() -> void:
	var tresen := _prop(_TRESEN, Vector3(395.6, 0.0, -96.9), PI)
	tresen.rotation.y = PI

	# Rückbuffet an der Rückwand: zwei Regalbretter mit Flaschen.
	var brett := _mat(Color(0.28, 0.18, 0.12), 0.7)
	for hoehe in [1.55, 1.95]:
		_kasten(Vector3(395.6, hoehe, -95.62), Vector3(3.2, 0.05, 0.30), brett)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8814
	var flaschentoene: Array[Color] = [
		Color(0.07, 0.13, 0.06), Color(0.16, 0.10, 0.04),
		Color(0.05, 0.09, 0.12), Color(0.20, 0.14, 0.05),
	]
	for hoehe in [1.58, 1.98]:
		for i in 16:
			var x := 394.15 + i * 0.19 + rng.randf_range(-0.02, 0.02)
			# Bauch und Hals getrennt — ein einzelner Kegel liest sich als
			# Kegel, nicht als Flasche.
			var glasfarbe := _mat(
				flaschentoene[rng.randi() % flaschentoene.size()], 0.22)
			var bauch := MeshInstance3D.new()
			var unten := CylinderMesh.new()
			unten.top_radius = 0.036
			unten.bottom_radius = 0.039
			unten.height = 0.22
			unten.material = glasfarbe
			bauch.mesh = unten
			add_child(bauch)
			bauch.position = Vector3(x, hoehe + 0.11, -95.62)
			var hals := MeshInstance3D.new()
			var oben := CylinderMesh.new()
			oben.top_radius = 0.012
			oben.bottom_radius = 0.018
			oben.height = 0.09
			oben.material = glasfarbe
			hals.mesh = oben
			add_child(hals)
			hals.position = Vector3(x, hoehe + 0.265, -95.62)
	# Gläser und Bembel auf dem Tresen.
	for i in 6:
		_prop(_GERIPPTE, Vector3(394.5 + i * 0.28, 1.09, -97.15),
			rng.randf() * TAU)
	_prop(_BEMBEL, Vector3(396.6, 1.09, -97.05), 0.7)
	_prop(_BEMBEL, Vector3(396.95, 1.09, -96.75), 2.4)

	# Der Wirt hinter dem Tresen. Er sieht auf, wenn jemand nah ist.
	var wirt := Wirt.new()
	wirt.modell_pfad = "res://actors/models/oliver.glb"
	wirt.zielhoehe = 1.79
	wirt.blickziel_pfad = ^"../../Player"
	add_child(wirt)
	wirt.position = Vector3(395.6, 0.0, -96.15)
	# Blick in den Gastraum (Godot schaut nach -Z), nicht zur Rückwand.
	wirt.rotation.y = 0.0


## Tische, Bänke, Bilder, Garderobe, Bembel-Regal.
func _stube_moeblieren(holz: Material, balken: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	# Zwei runde Tische, gedeckt: Bembel und je zwei Geripptes. Ein leerer
	# Tisch sieht aus wie eine geschlossene Kneipe.
	for daten in [[397.5, -101.8], [401.6, -101.2]]:
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
		_prop(_BEMBEL, Vector3(daten[0] + 0.16, 0.88, daten[1] - 0.10), 0.8)
		for versatz in [Vector3(-0.24, 0.0, 0.16), Vector3(0.02, 0.0, 0.30)]:
			_prop(_GERIPPTE,
				Vector3(daten[0], 0.88, daten[1]) + versatz, rng.randf() * TAU)
		# Zwei Bierdeckel — kleines Detail, große Wirkung auf einem Tisch.
		for versatz in [Vector3(-0.30, 0.0, -0.10), Vector3(0.20, 0.0, 0.24)]:
			var deckel := _kasten(
				Vector3(daten[0], 0.879, daten[1]) + versatz,
				Vector3(0.10, 0.004, 0.10), _mat(Color(0.80, 0.76, 0.66), 0.95))
			deckel.rotation.y = rng.randf() * TAU
	_prop(_BANK, Vector3(397.5, 0.1, -100.4), 0.0)
	_prop(_BANK, Vector3(401.6, 0.1, -99.9), 0.0)
	_prop(_STUHL, Vector3(398.2, 0.05, -102.7), rng.randf_range(2.6, 3.6))
	_prop(_STUHL, Vector3(402.4, 0.05, -102.2), rng.randf_range(2.6, 3.6))

	# Regal mit Bembeln an der Westwand.
	_kasten(Vector3(393.7, 1.5, -100.5), Vector3(0.25, 0.06, 3.4), balken)
	for i in 5:
		_prop(_BEMBEL, Vector3(393.7, 1.53, -102.0 + i * 0.7), i * 1.1)

	# Drei gerahmte Bilder auf der Vertäfelung. Jeder Rahmen bekommt eine
	# eigene Textur — dreimal dasselbe Bild fällt sofort auf.
	var bilder: Array = [
		[Vector3(397.8, 1.92, -95.36), 0.0, 1],
		[Vector3(402.6, 1.92, -95.36), 0.0, 2],
		[Vector3(393.62, 1.92, -98.4), PI / 2.0, 3],
	]
	for eintrag: Array in bilder:
		var rahmen := _prop(_BILDERRAHMEN, eintrag[0], eintrag[1])
		var flaeche := rahmen.get_node_or_null("bild") as MeshInstance3D
		if flaeche != null:
			var leinwand := StandardMaterial3D.new()
			leinwand.albedo_texture = load(
				"res://assets/texturen/ffm/wandbild_%d.png" % eintrag[2])
			leinwand.roughness = 0.85
			flaeche.material_override = leinwand

	# Garderobenhaken mit zwei Jacken neben der Tür.
	_kasten(Vector3(404.8, 1.72, -95.42), Vector3(1.20, 0.08, 0.06), balken)
	for daten in [[404.42, Color(0.20, 0.22, 0.28)],
			[405.18, Color(0.30, 0.18, 0.14)]]:
		var haken := _kasten(Vector3(daten[0], 1.66, -95.34),
			Vector3(0.04, 0.14, 0.04), balken)
		haken.rotation.x = 0.3
		_kasten(Vector3(daten[0], 1.30, -95.30), Vector3(0.34, 0.62, 0.12),
			_mat(daten[1], 0.95))

	# Banden, damit in der Stube niemand durch Wände läuft.
	_bande(Vector3(400, 1.8, -104.6), Vector3(13, 3.6, 0.4))
	_bande(Vector3(400, 1.8, -95.4), Vector3(13, 3.6, 0.4))
	_bande(Vector3(393.6, 1.8, -100), Vector3(0.4, 3.6, 9.5))
	_bande(Vector3(406.4, 1.8, -100), Vector3(0.4, 3.6, 9.5))
