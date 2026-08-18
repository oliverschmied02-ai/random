extends Node3D

## Die Kulisse: macht aus den grauen Blöcken einen Berliner Abend.
##
## Alles hier ist **Anstrich, keine Architektur**: Fassaden, Dächer, Gehwege,
## Lichter, Drähte und Schilder werden beim Laden über die vorhandenen Blöcke
## gelegt. Die Blöcke selbst — und damit Kollision, Route und alle gemessenen
## Zeiten — bleiben unangetastet. Einzige Ausnahme: die Gehwege tragen eine
## 8 cm hohe Platte mit Kollision, genau die Bordsteinkante, für die das
## Stufen-Steigen gebaut wurde.
##
## Gebaut wird prozedural statt von Hand: die Fassaden lesen Lage und Maße der
## Blöcke zur Laufzeit, und tausende Fenster von Hand zu setzen wäre
## Fleißarbeit ohne Urteil. Der Zufall ist gesät (je Wand aus ihrem Namen),
## damit jede Runde gleich aussieht.
##
## Drei Dinge tragen den Realismus:
##
## * **Oberflächen statt Farbflächen.** Putz, Asphalt und Beton bekommen
##   prozedurale Rauschtexturen samt Normal-Maps (Triplanar — kein UV-Zuschnitt
##   nötig). Nichts verrät „Computer" so sehr wie mathematisch glatte Flächen.
## * **Nasser Asphalt.** Die Fahrbahn ist stellenweise spiegelnd (fleckige
##   Rauheit), und Screen-Space-Reflexionen holen Laternen und Leuchtschilder
##   in die Straße. Sichtbar im Forward+-Renderer, also im fertigen Spiel.
## * **Kleinzeug in Massen**: Dachaufbauten, Fensterbänke, Vorhänge,
##   Oberleitungen, Mülleimer, Gullys, Plakate. Alles landet in wenigen
##   MultiMeshes — ein Zeichenaufruf je Materialgruppe.

## Anteil erleuchteter Fenster. 2020, halb elf: die meisten sind zu Hause.
@export_range(0.0, 1.0, 0.01) var fenster_an_anteil: float = 0.14
## Etagenhöhe der Altbauten.
@export_range(2.0, 5.0, 0.1) var etage: float = 3.0
## Fensterabstand entlang der Fassade.
@export_range(1.5, 5.0, 0.1) var fenster_raster: float = 2.5

## Berliner Altbautöne — bewusst gedeckt, das Licht kommt von den Fenstern.
const PALETTE: Array[Color] = [
	Color(0.78, 0.70, 0.55), Color(0.72, 0.62, 0.48), Color(0.62, 0.64, 0.55),
	Color(0.74, 0.66, 0.62), Color(0.66, 0.62, 0.58), Color(0.77, 0.72, 0.60),
]

## Gehwegplatten: je [x_min, z_min, x_max, z_max], entlang der Hauskanten.
const GEHWEGE: Array = [
	[-12.0, -42.0, -8.5, 22.0], [8.5, -42.0, 12.0, 22.0],
	[12.0, -46.5, 72.0, -43.0], [-12.0, -67.0, 48.0, -63.5],
	[48.0, -135.0, 51.5, -67.0], [68.5, -123.0, 72.0, -67.0],
	[48.0, -147.0, 118.0, -143.5], [76.0, -126.5, 142.0, -123.0],
	[118.0, -205.0, 121.5, -147.0], [138.5, -245.0, 142.0, -147.0],
	[108.0, -247.0, 111.5, -203.0],
]

## Mittelstreifen der Fahrbahnen: [x, z, x, z] von–bis, gestrichelt.
const MARKIERUNGEN: Array = [
	[0.0, 18.0, 0.0, -38.0], [60.0, -72.0, 60.0, -130.0],
	[54.0, -135.0, 136.0, -135.0], [130.0, -152.0, 130.0, -238.0],
]

## Wo unten an den Fassaden nichts hingebaut werden darf: [x_min, z_min,
## x_max, z_max] — Büronische und Café haben eigene Kulisse.
const GRUND_FREI: Array = [
	[11.0, -13.0, 16.0, -5.0],
	[47.0, -106.0, 52.0, -94.0],
]

## Geparkte Autos: [x, z, Drehung]. 2020 fährt niemand, aber Berliner
## Straßenränder stehen immer voll.
const AUTOS: Array = [
	[-6.6, 2.0, 0.0], [-6.6, -14.0, 0.0], [-6.4, -31.0, 0.0],
	[66.6, -96.0, 0.0], [66.4, -117.0, 0.0],
	[135.6, -168.0, 0.0], [135.4, -215.0, 0.0],
]

## Gullydeckel am Fahrbahnrand: [x, z].
const GULLYS: Array = [
	[-7.6, -6.0], [7.6, -26.0], [16.0, -44.6], [30.0, -65.4],
	[52.6, -88.0], [67.4, -112.0], [56.0, -144.6], [96.0, -125.4],
	[122.6, -170.0], [137.4, -196.0], [126.0, -232.0],
]

var _stapel: Dictionary = {}
var _materialien: Dictionary = {}
var _flacker: Array = []
var _spiess_dreher: Node3D


func _ready() -> void:
	_materialien_anlegen()
	_boden_umfaerben()
	_fassaden_bauen()
	_gehwege_bauen()
	_markierungen_bauen()
	_gleisbett_bauen()
	_oberleitung_spannen()
	_laternen_anzuenden()
	_autos_parken()
	_moeblieren()
	_himmel_fuellen()
	_doenerbude_beleben()
	_cafe_beschildern()
	_buero_beschildern()
	_fernsehturm_beleuchten()
	_litfasssaeulen_stellen()
	_fuelllicht_anbringen()
	_stapel_absetzen()


## Lebendiges Licht: eine Laterne flackert, das Dönerschild brummt. Reine
## Sinusmischungen — unregelmäßig genug, dass kein Muster auffällt, und ohne
## Zufall, damit jeder Prüflauf dasselbe sieht.
func _process(_delta: float) -> void:
	if _spiess_dreher != null:
		_spiess_dreher.rotate_y(_delta * 0.9)
	var t := Time.get_ticks_msec() / 1000.0
	for eintrag in _flacker:
		var faktor: float = eintrag["ruhe"] + eintrag["hub"] * (
			0.5 * sin(t * eintrag["takt"]) + 0.3 * sin(t * eintrag["takt"] * 3.7 + 1.3)
		)
		if eintrag["aussetzer"] and sin(t * 0.83) > 0.996:
			faktor = 0.1
		var material: StandardMaterial3D = eintrag["material"]
		material.emission_energy_multiplier = eintrag["basis"] * clampf(faktor, 0.05, 1.2)
		var licht: OmniLight3D = eintrag["licht"]
		if licht != null:
			licht.light_energy = eintrag["licht_basis"] * clampf(faktor, 0.05, 1.2)


# --- Materialien und Sammelbecken -------------------------------------------


func _materialien_anlegen() -> void:
	_materialien = {
		&"rahmen": _mat(Color(0.82, 0.78, 0.70), 0.8),
		&"laibung": _mat(Color(0.04, 0.045, 0.06), 0.6),
		&"glas_dunkel": _mat(Color(0.07, 0.09, 0.13), 0.25, Color(0.10, 0.13, 0.20), 0.35),
		&"glas_hell": _mat(Color(0.85, 0.68, 0.42), 0.6, Color(1.0, 0.72, 0.38), 1.9),
		&"glas_hell2": _mat(Color(0.88, 0.78, 0.55), 0.6, Color(1.0, 0.85, 0.55), 1.5),
		&"glas_tv": _mat(Color(0.5, 0.6, 0.8), 0.6, Color(0.55, 0.7, 1.2), 1.7),
		&"vorhang": _mat(Color(0.38, 0.26, 0.17), 0.9),
		&"sockel": _foto_mat("beton_rau", Color(0.64, 0.62, 0.59), 0.3, 1.2),
		&"tuer": _mat(Color(0.23, 0.17, 0.13), 0.7),
		&"laden": _mat(Color(0.36, 0.37, 0.39), 0.5),
		&"ladenschild": _mat(Color(0.42, 0.18, 0.16), 0.7),
		&"gitter": _mat(Color(0.14, 0.15, 0.17), 0.5),
		&"markierung": _mat(Color(0.75, 0.74, 0.70), 0.9),
		&"gleisbett": _foto_mat("schotter", Color(0.45, 0.45, 0.48), 0.8, 1.6),
		&"birne": _mat(Color(1.0, 0.75, 0.4), 0.5, Color(1.0, 0.62, 0.25), 3.2),
		&"dach": _mat(Color(0.16, 0.16, 0.18), 0.9),
		&"schornstein": _mat(Color(0.42, 0.33, 0.28), 0.95),
		&"antenne": _mat(Color(0.12, 0.13, 0.15), 0.5),
		&"draht": _mat(Color(0.05, 0.05, 0.06), 0.6),
		&"muell": _mat(Color(0.80, 0.34, 0.06), 0.6),
		&"kasten_grau": _mat(Color(0.44, 0.46, 0.43), 0.8),
		&"auto": _mat(Color(0.10, 0.11, 0.13), 0.35),
		&"auto_hell": _mat(Color(0.28, 0.29, 0.32), 0.4),
		&"rad": _mat(Color(0.05, 0.05, 0.05), 0.9),
		&"radkappe": _mat(Color(0.52, 0.54, 0.58), 0.35),
		&"stossstange": _mat(Color(0.15, 0.16, 0.17), 0.55),
		&"kennzeichen": _mat(Color(0.82, 0.83, 0.78), 0.4),
		&"ruecklicht": _mat(Color(0.35, 0.04, 0.04), 0.3, Color(0.9, 0.1, 0.08), 0.4),
		&"frontlicht": _mat(Color(0.6, 0.63, 0.66), 0.2),
		&"muell_deckel": _mat(Color(0.5, 0.21, 0.05), 0.6),
		&"gully": _mat(Color(0.09, 0.09, 0.10), 0.7),
		&"poller": _mat(Color(0.18, 0.19, 0.21), 0.6),
		&"plakat_a": _mat(Color(0.74, 0.71, 0.63), 0.9),
		&"plakat_b": _mat(Color(0.60, 0.65, 0.60), 0.9),
		&"fuge": _mat(Color(0.30, 0.30, 0.32), 0.95),
		&"stern": _mat(Color(0.0, 0.0, 0.0), 1.0, Color(0.85, 0.88, 1.0), 1.2),
		&"ampel_rot": _mat(Color(0.3, 0.02, 0.02), 0.4, Color(1.0, 0.08, 0.05), 3.0),
	}


func _mat(farbe: Color, rauheit: float, leuchten: Color = Color.BLACK, staerke: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = farbe
	m.roughness = rauheit
	if staerke > 0.0:
		m.emission_enabled = true
		m.emission = leuchten
		m.emission_energy_multiplier = staerke
	return m


## Ein Material aus einem gebackenen Textursatz (assets/texturen/<satz>):
## Albedo (mit dem Farbton multipliziert), Normal-Map und Rauheitskarte,
## triplanar gemappt — die Kastengeometrie braucht dafür keine UV-Arbeit.
## `masstab` in Wiederholungen je Meter (0.22 ≈ alle 4,5 m).
func _foto_mat(satz: String, ton: Color, masstab: float = 0.22, relief: float = 1.0) -> StandardMaterial3D:
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
	return m


func _lege(gruppe: StringName, lage: Transform3D) -> void:
	if not _stapel.has(gruppe):
		_stapel[gruppe] = []
	_stapel[gruppe].append(lage)


## Baut aus jedem Sammelbecken genau eine MultiMesh-Instanz. Kugeln und
## Zylinder sind Einheitskörper und werden je Instanz skaliert.
func _stapel_absetzen() -> void:
	var kugelgruppen := [&"birne", &"stern", &"ampel_rot"]
	var zylindergruppen := [&"gully", &"poller", &"rad", &"antenne"]
	for gruppe in _stapel:
		var mesh: Mesh
		if gruppe in kugelgruppen:
			var kugel := SphereMesh.new()
			kugel.radius = 0.5
			kugel.height = 1.0
			mesh = kugel
		elif gruppe in zylindergruppen:
			var rohr := CylinderMesh.new()
			rohr.top_radius = 0.5
			rohr.bottom_radius = 0.5
			rohr.height = 1.0
			mesh = rohr
		else:
			mesh = BoxMesh.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var lagen: Array = _stapel[gruppe]
		mm.instance_count = lagen.size()
		for i in lagen.size():
			mm.set_instance_transform(i, lagen[i])
		var traeger := MultiMeshInstance3D.new()
		traeger.name = "MM_%s" % gruppe
		traeger.multimesh = mm
		traeger.material_override = _materialien[gruppe]
		add_child(traeger)


func _kasten(gruppe: StringName, mitte: Vector3, masse: Vector3, drehung: float, rolle: float = 0.0) -> void:
	var basis := Basis(Vector3.UP, drehung)
	if not is_zero_approx(rolle):
		basis = basis * Basis(Vector3(0, 0, 1), rolle)
	_lege(gruppe, Transform3D(basis * Basis.from_scale(masse), mitte))


func _kugel(gruppe: StringName, mitte: Vector3, durchmesser: float) -> void:
	_lege(gruppe, Transform3D(Basis.from_scale(Vector3.ONE * durchmesser), mitte))


func _zylinder(gruppe: StringName, mitte: Vector3, durchmesser: float, hoehe: float, liegend: float = 0.0) -> void:
	var basis := Basis.IDENTITY
	if not is_zero_approx(liegend):
		basis = Basis(Vector3(0, 0, 1), liegend)
	_lege(gruppe, Transform3D(
		basis * Basis.from_scale(Vector3(durchmesser, hoehe, durchmesser)), mitte
	))


# --- Boden und Fassaden -------------------------------------------------------


## Nasser Nachtasphalt: dunkel, fleckig rau — wo das Rauschen glatt wird,
## stehen Pfützen, und dort spiegeln sich die Laternen (im Forward+-Renderer
## über Screen-Space-Reflexionen, eingeschaltet in der Umgebung der Szene).
func _boden_umfaerben() -> void:
	var boden := get_parent().get_node_or_null("Ground") as CSGBox3D
	if boden == null:
		return
	# Pfützen und Risse stecken im gebackenen Asphaltsatz — die Rauheitskarte
	# macht die nassen Stellen spiegelglatt, dort greifen die Reflexionen.
	boden.material = _foto_mat("asphalt", Color(0.4, 0.41, 0.45), 0.09, 1.0)


func _fassaden_bauen() -> void:
	var waende := get_parent().get_node_or_null("Walls")
	if waende == null:
		return
	var rng := RandomNumberGenerator.new()
	var nummer := 0
	for kind in waende.get_children():
		var block := kind as CSGBox3D
		if block == null:
			continue
		rng.seed = hash(String(block.name))
		block.material = _foto_mat("putz", PALETTE[nummer % PALETTE.size()], 0.24, 0.8)
		nummer += 1
		for richtung in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			_fassade(block, richtung, rng)
		_dach_bauen(block, rng)


## Die Dachlinie gegen den Nachthimmel: Attika, Schornsteine, Antennen.
## Genau die Silhouette, die aus einem Kasten ein Haus macht.
func _dach_bauen(block: CSGBox3D, rng: RandomNumberGenerator) -> void:
	var oben := block.position.y + block.size.y * 0.5
	_kasten(&"dach",
		Vector3(block.position.x, oben + 0.5, block.position.z),
		Vector3(block.size.x - 1.6, 1.0, block.size.z - 1.6), 0.0)

	var flaeche := maxf(block.size.x, block.size.z)
	var laengs := Vector3(1, 0, 0) if block.size.x >= block.size.z else Vector3(0, 0, 1)
	var quer := Vector3(0, 0, 1) if block.size.x >= block.size.z else Vector3(1, 0, 0)
	var quer_halb := (minf(block.size.x, block.size.z) - 3.0) * 0.5

	var anzahl := int(flaeche / 13.0)
	for i in anzahl:
		var u := (rng.randf() - 0.5) * (flaeche - 4.0)
		var v := (rng.randf() - 0.5) * 2.0 * quer_halb
		var fusspunkt := block.position + laengs * u + quer * v
		fusspunkt.y = oben + 1.0
		if rng.randf() < 0.7:
			_kasten(&"schornstein", fusspunkt + Vector3.UP * rng.randf_range(0.5, 1.0),
				Vector3(0.9, 1.6, 0.55), 0.0)
		else:
			var hoehe := rng.randf_range(2.2, 3.6)
			_zylinder(&"antenne", fusspunkt + Vector3.UP * hoehe * 0.5, 0.05, hoehe)
			_kasten(&"antenne", fusspunkt + Vector3.UP * (hoehe - 0.3),
				Vector3(1.1, 0.03, 0.03), rng.randf_range(0.0, PI))


## Eine Gebäudeseite: Sockel, Fensterraster, Gesims, unten Türen und Läden.
func _fassade(block: CSGBox3D, n: Vector3, rng: RandomNumberGenerator) -> void:
	var breite := block.size.z if absf(n.x) > 0.5 else block.size.x
	if breite < 8.0:
		return
	var drehung := 0.0
	if n == Vector3.RIGHT:
		drehung = PI * 0.5
	elif n == Vector3.LEFT:
		drehung = -PI * 0.5
	elif n == Vector3.FORWARD:
		drehung = PI
	var seit := Vector3(0, 0, 1) if absf(n.x) > 0.5 else Vector3(1, 0, 0)
	var tiefe := block.size.x * 0.5 if absf(n.x) > 0.5 else block.size.z * 0.5
	var fuss := block.position + n * tiefe
	var unten := block.position.y - block.size.y * 0.5
	var oben := block.position.y + block.size.y * 0.5

	var ort := func(u: float, y: float, d: float) -> Vector3:
		return Vector3(fuss.x + seit.x * u + n.x * d, y, fuss.z + seit.z * u + n.z * d)

	# Sockel und Gesims rahmen die Fassade oben und unten ein.
	_kasten(&"sockel", ort.call(0.0, unten + 0.55, 0.05), Vector3(breite, 1.1, 0.12), drehung)
	_kasten(&"rahmen", ort.call(0.0, oben - 0.22, 0.14), Vector3(breite + 0.25, 0.35, 0.34), drehung)
	if block.size.y > 9.0:
		_kasten(&"rahmen", ort.call(0.0, unten + 4.35, 0.07), Vector3(breite, 0.16, 0.16), drehung)

	# Fensterraster: mittig verteilt, Ränder bleiben frei. Der Rahmen steht
	# vor der Wand, das Glas liegt dahinter zurückgesetzt in einer dunklen
	# Laibung — diese drei Zentimeter Tiefe machen aus Aufklebern Fenster.
	var spalten := int((breite - 3.2) / fenster_raster) + 1
	var start := -(spalten - 1) * fenster_raster * 0.5
	var reihe := 0
	var y := unten + 2.2
	while y + 1.0 < oben - 0.9:
		for i in spalten:
			var u := start + i * fenster_raster
			_kasten(&"laibung", ort.call(u, y + 0.8, 0.01), Vector3(1.18, 1.78, 0.05), drehung)
			# Rahmen als vier Leisten — eine volle Platte würde die
			# zurückgesetzte Scheibe verdecken. Dazu ein Sprossenkreuz.
			_kasten(&"rahmen", ort.call(u, y + 1.635, 0.055), Vector3(1.15, 0.08, 0.06), drehung)
			_kasten(&"rahmen", ort.call(u, y - 0.035, 0.055), Vector3(1.15, 0.08, 0.06), drehung)
			_kasten(&"rahmen", ort.call(u - 0.535, y + 0.8, 0.055), Vector3(0.08, 1.75, 0.06), drehung)
			_kasten(&"rahmen", ort.call(u + 0.535, y + 0.8, 0.055), Vector3(0.08, 1.75, 0.06), drehung)
			_kasten(&"rahmen", ort.call(u, y + 0.8, 0.045), Vector3(0.05, 1.6, 0.04), drehung)
			_kasten(&"rahmen", ort.call(u, y + 1.05, 0.045), Vector3(1.05, 0.05, 0.04), drehung)
			_kasten(&"rahmen", ort.call(u, y - 0.14, 0.1), Vector3(1.32, 0.09, 0.2), drehung)

			var los := rng.randf()
			var gruppe: StringName = &"glas_dunkel"
			if los < fenster_an_anteil * 0.55:
				gruppe = &"glas_hell"
			elif los < fenster_an_anteil:
				gruppe = &"glas_hell2"
			elif los < fenster_an_anteil + 0.02:
				gruppe = &"glas_tv"
			_kasten(gruppe, ort.call(u, y + 0.8, 0.025), Vector3(0.95, 1.55, 0.04), drehung)
			# Vorhänge: als Silhouette vor dem erleuchteten Fenster.
			if gruppe != &"glas_dunkel" and rng.randf() < 0.45:
				_kasten(&"vorhang", ort.call(u - 0.32, y + 0.8, 0.04), Vector3(0.3, 1.5, 0.03), drehung)
				_kasten(&"vorhang", ort.call(u + 0.32, y + 0.8, 0.04), Vector3(0.3, 1.5, 0.03), drehung)

			if reihe >= 1 and rng.randf() < 0.07:
				_kasten(&"rahmen", ort.call(u, y - 0.16, 0.42), Vector3(1.7, 0.12, 0.85), drehung)
				_kasten(&"gitter", ort.call(u, y + 0.32, 0.8), Vector3(1.7, 0.9, 0.06), drehung)
		y += etage
		reihe += 1

	# Erdgeschoss: hin und wieder eine Tür, hin und wieder ein
	# heruntergelassener Rollladen — 2020 hatte vieles einfach zu.
	for i in spalten:
		var u := start + i * fenster_raster
		var stelle: Vector3 = ort.call(u, unten + 1.25, 0.06)
		if _grund_verboten(stelle):
			continue
		if i % 6 == 2:
			_kasten(&"tuer", stelle, Vector3(1.35, 2.5, 0.12), drehung)
		elif i % 7 == 4 and rng.randf() < 0.75:
			_kasten(&"laden", ort.call(u, unten + 1.28, 0.055), Vector3(3.3, 2.55, 0.1), drehung)
			_kasten(&"ladenschild", ort.call(u, unten + 2.85, 0.07), Vector3(3.5, 0.55, 0.12), drehung)
			# Aushänge am geschlossenen Laden — schief, wie mit Klebeband.
			if rng.randf() < 0.6:
				_kasten(&"plakat_a", ort.call(u - 0.8, unten + 1.7, 0.115),
					Vector3(0.45, 0.62, 0.01), drehung, rng.randf_range(-0.07, 0.07))
			if rng.randf() < 0.4:
				_kasten(&"plakat_b", ort.call(u + 0.9, unten + 1.5, 0.115),
					Vector3(0.5, 0.7, 0.01), drehung, rng.randf_range(-0.07, 0.07))


func _grund_verboten(stelle: Vector3) -> bool:
	for feld in GRUND_FREI:
		if stelle.x >= feld[0] and stelle.z >= feld[1] and stelle.x <= feld[2] and stelle.z <= feld[3]:
			return true
	return false


# --- Straßenraum -------------------------------------------------------------


func _gehwege_bauen() -> void:
	var material := _foto_mat("beton_platten", Color(0.6, 0.6, 0.63), 0.35, 0.6)
	for feld in GEHWEGE:
		var masse := Vector3(feld[2] - feld[0], 0.16, feld[3] - feld[1])
		var mitte := Vector3((feld[0] + feld[2]) * 0.5, 0.0, (feld[1] + feld[3]) * 0.5)

		var koerper := StaticBody3D.new()
		koerper.position = mitte
		var form := CollisionShape3D.new()
		var kasten := BoxShape3D.new()
		kasten.size = masse
		form.shape = kasten
		koerper.add_child(form)
		var sicht := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = masse
		mesh.material = material
		sicht.mesh = mesh
		koerper.add_child(sicht)
		add_child(koerper)

		# Plattenfugen quer zur Laufrichtung — Beton kommt in Stücken.
		var laengs_x := masse.x >= masse.z
		var laenge := masse.x if laengs_x else masse.z
		var fugen := int(laenge / 1.6)
		for i in fugen:
			var v := -laenge * 0.5 + (i + 0.5) * 1.6
			var stelle := mitte + (Vector3(v, 0.081, 0) if laengs_x else Vector3(0, 0.081, v))
			_kasten(&"fuge", stelle,
				Vector3(0.03, 0.004, masse.z) if laengs_x else Vector3(masse.x, 0.004, 0.03), 0.0)

	for eintrag in GULLYS:
		_zylinder(&"gully", Vector3(eintrag[0], 0.015, eintrag[1]), 0.75, 0.03)


func _markierungen_bauen() -> void:
	for linie in MARKIERUNGEN:
		var von := Vector3(linie[0], 0.012, linie[1])
		var bis := Vector3(linie[2], 0.012, linie[3])
		var laenge := von.distance_to(bis)
		var richtung := (bis - von).normalized()
		var drehung := 0.0 if absf(richtung.z) > 0.5 else PI * 0.5
		var strich := 2.2
		var schritt := 6.4
		var s := strich * 0.5
		while s + strich * 0.5 <= laenge:
			_kasten(&"markierung", von + richtung * s, Vector3(0.16, 0.024, strich), drehung)
			s += schritt


func _gleisbett_bauen() -> void:
	_kasten(&"gleisbett", Vector3(30.0, 0.008, -55.0), Vector3(86.0, 0.03, 3.6), 0.0)


## Fahrdraht über den Gleisen und Querspanner zwischen den Häusern — der
## Himmel über Berliner Straßen ist nie leer.
func _oberleitung_spannen() -> void:
	_kasten(&"draht", Vector3(30.0, 5.6, -55.0), Vector3(86.0, 0.035, 0.035), 0.0)
	_kasten(&"draht", Vector3(30.0, 6.15, -55.0), Vector3(86.0, 0.03, 0.03), 0.0)
	for x in [-8.0, 10.0, 28.0, 46.0, 64.0]:
		_kasten(&"draht", Vector3(x, 6.4, -55.0), Vector3(0.028, 0.028, 24.5), 0.0)
	for z in [-80.0, -100.0, -120.0]:
		_kasten(&"draht", Vector3(60.0, 6.5, z), Vector3(24.5, 0.028, 0.028), 0.0)
	for z in [-160.0, -200.0]:
		_kasten(&"draht", Vector3(130.0, 6.5, z), Vector3(24.5, 0.028, 0.028), 0.0)


func _laternen_anzuenden() -> void:
	var moebel := get_parent().get_node_or_null("StreetFurniture")
	if moebel == null:
		return
	# Zwei Leuchtmittel im Bestand, wie auf echten Straßen: warmweiß und das
	# orangere Natriumdampf-Licht. Laterne 5 flackert.
	var glas_warm := _mat(Color(1.0, 0.85, 0.6), 0.4, Color(1.0, 0.78, 0.45), 2.4)
	var glas_orange := _mat(Color(1.0, 0.78, 0.45), 0.4, Color(1.0, 0.62, 0.28), 2.4)
	for i in range(1, 11):
		var kopf := moebel.get_node_or_null("Kopf%d" % i) as CSGBox3D
		if kopf == null:
			continue
		var orange := i % 2 == 0
		var glas := glas_orange if orange else glas_warm
		var licht := OmniLight3D.new()
		licht.position = kopf.position + Vector3(0, -0.35, 0)
		licht.light_color = Color(1.0, 0.72, 0.4) if orange else Color(1.0, 0.82, 0.55)
		licht.light_energy = 3.4
		licht.omni_range = 15.0
		licht.omni_attenuation = 1.4
		add_child(licht)
		_lichtkegel(licht.position, licht.light_color)
		if i == 5:
			glas = glas.duplicate()
			_flacker.append({
				"material": glas, "licht": licht, "basis": 2.4, "licht_basis": 3.4,
				"ruhe": 0.7, "hub": 0.35, "takt": 11.0, "aussetzer": true,
			})
		kopf.material = glas

		# Der orange Berliner Mülleimer, am Mast montiert.
		if i % 2 == 1:
			var mast := moebel.get_node_or_null("Mast%d" % i) as CSGCylinder3D
			if mast != null:
				# Feste Griffhöhe statt relativ zum Mastmittelpunkt — der
				# liegt je nach Masthöhe woanders und hob die Eimer hoch.
				_kasten(&"muell",
					Vector3(mast.position.x + 0.2, 1.1, mast.position.z + 0.08),
					Vector3(0.34, 0.5, 0.3), 0.3)
				_kasten(&"muell_deckel",
					Vector3(mast.position.x + 0.2, 1.38, mast.position.z + 0.08),
					Vector3(0.38, 0.06, 0.34), 0.3)


## Der sichtbare Lichtschein unter einer Laterne: ein additiver, ungeschatteter
## Kegel — die billige Ausgabe von volumetrischem Nebel, die überall läuft.
func _lichtkegel(quelle: Vector3, farbe: Color) -> void:
	var kegel := MeshInstance3D.new()
	var form := CylinderMesh.new()
	var hoehe := maxf(quelle.y - 0.3, 1.0)
	form.top_radius = 0.14
	form.bottom_radius = 1.7
	form.height = hoehe
	var schein := StandardMaterial3D.new()
	schein.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	schein.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	schein.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	schein.albedo_color = Color(farbe.r, farbe.g, farbe.b, 0.045)
	form.material = schein
	kegel.mesh = form
	kegel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kegel.position = Vector3(quelle.x, 0.3 + hoehe * 0.5, quelle.z)
	add_child(kegel)


## Geparkte Autos: Karosserie, dunkles Glashaus, Räder. Nachts am Straßenrand
## reicht das — niemand schaut einem stehenden Auto auf die Türgriffe.
func _autos_parken() -> void:
	var nummer := 0
	for eintrag in AUTOS:
		var fuss := Vector3(eintrag[0], 0.0, eintrag[1])
		var drehung: float = eintrag[2]
		var gruppe: StringName = &"auto" if nummer % 3 != 2 else &"auto_hell"
		nummer += 1
		_kasten(gruppe, fuss + Vector3(0, 0.55, 0), Vector3(1.76, 0.6, 4.35), drehung)
		_kasten(&"glas_dunkel", fuss + Vector3(0, 1.08, -0.25).rotated(Vector3.UP, drehung),
			Vector3(1.6, 0.5, 2.3), drehung)
		_kasten(gruppe, fuss + Vector3(0, 1.12, -0.25).rotated(Vector3.UP, drehung),
			Vector3(1.62, 0.06, 2.35), drehung)
		for ecke in [Vector3(0.85, 0.32, 1.45), Vector3(-0.85, 0.32, 1.45),
				Vector3(0.85, 0.32, -1.45), Vector3(-0.85, 0.32, -1.45)]:
			var rad_basis := Basis(Vector3.UP, drehung) * Basis(Vector3(0, 0, 1), PI * 0.5)
			_lege(&"rad", Transform3D(
				rad_basis * Basis.from_scale(Vector3(0.64, 0.24, 0.64)),
				fuss + ecke.rotated(Vector3.UP, drehung)))
			_lege(&"radkappe", Transform3D(
				rad_basis * Basis.from_scale(Vector3(0.3, 0.26, 0.3)),
				fuss + ecke.rotated(Vector3.UP, drehung)))

		# Was ein Auto von einem Kasten unterscheidet: Stoßstangen,
		# Kennzeichen, Leuchten, Spiegel.
		for ende in [1.0, -1.0]:
			_kasten(&"stossstange",
				fuss + Vector3(0, 0.3, 2.2 * ende).rotated(Vector3.UP, drehung),
				Vector3(1.82, 0.16, 0.14), drehung)
			_kasten(&"kennzeichen",
				fuss + Vector3(0, 0.44, 2.24 * ende).rotated(Vector3.UP, drehung),
				Vector3(0.52, 0.11, 0.02), drehung)
			for seite in [0.6, -0.6]:
				_kasten(&"ruecklicht" if ende < 0 else &"frontlicht",
					fuss + Vector3(seite, 0.72, 2.19 * ende).rotated(Vector3.UP, drehung),
					Vector3(0.3, 0.11, 0.04), drehung)
		for seite in [0.93, -0.93]:
			_kasten(gruppe,
				fuss + Vector3(seite, 1.0, 0.85).rotated(Vector3.UP, drehung),
				Vector3(0.07, 0.08, 0.16), drehung)


## Poller, Verteilerkästen, eine rote Ampel über leerer Kreuzung, Plakate an
## den Litfaßsäulen — das leblose Inventar einer Stadt im Lockdown.
func _moeblieren() -> void:
	for z in [-4.0, -9.0, -14.0]:
		_zylinder(&"poller", Vector3(8.2, 0.5, z), 0.14, 0.85)
	for z in [-186.0, -190.0, -194.0]:
		_zylinder(&"poller", Vector3(121.9, 0.5, z), 0.14, 0.85)

	for eintrag in [[-8.3, -35.0, PI * 0.5], [51.4, -78.0, -PI * 0.5], [119.9, -152.0, -PI * 0.5]]:
		_kasten(&"kasten_grau", Vector3(eintrag[0], 0.65, eintrag[1]),
			Vector3(0.65, 1.15, 0.42), eintrag[2])

	_ampel(Vector3(10.6, 0.08, -44.3))
	_ampel(Vector3(70.8, 0.08, -133.2))


## Eine Fußgängerampel, die rot in die leere Straße leuchtet — 2020 in einem
## Bild. Der Mast ist ein Zylinder, das rote Licht glüht.
func _ampel(fuss: Vector3) -> void:
	_zylinder(&"poller", fuss + Vector3(0, 1.7, 0), 0.09, 3.4)
	_kasten(&"gitter", fuss + Vector3(0, 3.15, 0), Vector3(0.24, 0.62, 0.24), 0.0)
	_kugel(&"ampel_rot", fuss + Vector3(0, 3.32, 0), 0.13)
	_kasten(&"gitter", fuss + Vector3(0, 2.2, 0), Vector3(0.2, 0.4, 0.2), 0.0)
	_kugel(&"ampel_rot", fuss + Vector3(0, 2.3, 0), 0.1)


## Mond und ein schwaches Sternfeld. Über einer Stadt sieht man wenige Sterne —
## die Lichtglocke frisst sie —, aber ein völlig leerer Himmel wirkt wie eine
## Decke. Alles weit außerhalb der begehbaren Welt.
func _himmel_fuellen() -> void:
	var mond := MeshInstance3D.new()
	var scheibe := SphereMesh.new()
	scheibe.radius = 16.0
	scheibe.height = 32.0
	scheibe.material = _mat(Color(0.9, 0.89, 0.84), 0.8, Color(0.95, 0.93, 0.85), 1.3)
	mond.mesh = scheibe
	mond.position = Vector3(280.0, 460.0, -580.0)
	add_child(mond)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2020
	for i in 220:
		var winkel := rng.randf() * TAU
		var hoehe := rng.randf_range(0.35, 0.95)
		var radius := 820.0
		var flach := sqrt(1.0 - hoehe * hoehe) * radius
		var stelle := Vector3(cos(winkel) * flach + 65.0, hoehe * radius, sin(winkel) * flach - 105.0)
		_kugel(&"stern", stelle, rng.randf_range(0.6, 1.3))


# --- Schauplätze ---------------------------------------------------------------


func _doenerbude_beleben() -> void:
	var bude := get_parent().get_node_or_null("Doenerbude")
	if bude == null:
		return
	var schild := bude.get_node_or_null("Schild") as CSGBox3D
	if schild != null:
		var leuchten := _mat(Color(0.95, 0.79, 0.29), 0.5, Color(1.0, 0.76, 0.2), 2.2)
		schild.material = leuchten
		_flacker.append({
			"material": leuchten, "licht": null, "basis": 2.2, "licht_basis": 0.0,
			"ruhe": 0.94, "hub": 0.06, "takt": 31.0, "aussetzer": false,
		})
	var spiess := bude.get_node_or_null("Spiess") as CSGBox3D
	if spiess != null:
		# Der Klotz-Platzhalter weicht einem echten Spieß am selben Ort.
		spiess.visible = false
		_spiess_bauen(spiess.position)

	_schrift("DÖNER", Vector3(122.0, 3.86, -237.4), 0.0, Color(0.5, 0.1, 0.08), 260)
	_schrift("IMBISS · SPÄTKAUF", Vector3(122.0, 3.32, -237.4), 0.0, Color(0.32, 0.09, 0.08), 84)

	# Lichterkette unter dem Vordach — neun warme Punkte.
	for i in 9:
		_kugel(&"birne", Vector3(119.9 + i * 0.53, 2.58 - 0.04 * (i % 2), -234.35), 0.11)

	var licht := get_parent().get_node_or_null("Lichter/Doener") as OmniLight3D
	if licht != null:
		licht.light_energy = 3.4
		licht.omni_range = 15.0
		licht.shadow_enabled = true


## Ein Dönerspieß, wie er hinter jedem Tresen steht: Teller, Stange, der
## Fleischkegel in Schichten (er dreht sich langsam) und dahinter das rot
## glühende Heizelement an der Seitenwand.
func _spiess_bauen(stelle: Vector3) -> void:
	var fuss := Vector3(stelle.x, 0.0, stelle.z)
	var metall := _mat(Color(0.72, 0.74, 0.78), 0.35)
	metall.metallic = 0.8

	var teller := MeshInstance3D.new()
	var teller_form := CylinderMesh.new()
	teller_form.top_radius = 0.3
	teller_form.bottom_radius = 0.3
	teller_form.height = 0.03
	teller_form.material = metall
	teller.mesh = teller_form
	teller.position = fuss + Vector3(0, 1.02, 0)
	add_child(teller)

	var stange := MeshInstance3D.new()
	var stangen_form := CylinderMesh.new()
	stangen_form.top_radius = 0.012
	stangen_form.bottom_radius = 0.012
	stangen_form.height = 1.7
	stangen_form.material = metall
	stange.mesh = stangen_form
	stange.position = fuss + Vector3(0, 1.85, 0)
	add_child(stange)

	# Der Kegel dreht sich um die Stange — deshalb hängen die Schichten an
	# einem eigenen Drehknoten auf der Spießachse.
	_spiess_dreher = Node3D.new()
	_spiess_dreher.position = fuss
	add_child(_spiess_dreher)
	# Gebratenes Braun statt rohem Beige, und ein durchgehendes Profil:
	# jede Schicht endet mit dem Radius, mit dem die nächste beginnt.
	var fleisch := _mat(Color(0.4, 0.24, 0.11), 0.68, Color(0.6, 0.28, 0.09), 0.12)
	var kruste := _mat(Color(0.32, 0.18, 0.08), 0.72, Color(0.55, 0.24, 0.07), 0.12)
	var radien := [0.1, 0.17, 0.22, 0.25, 0.26, 0.25, 0.22, 0.17, 0.1]
	for i in radien.size() - 1:
		var schicht := MeshInstance3D.new()
		var form := CylinderMesh.new()
		form.bottom_radius = radien[i]
		form.top_radius = radien[i + 1]
		form.height = 0.14
		form.material = kruste if i % 2 == 0 else fleisch
		schicht.mesh = form
		schicht.position = Vector3(0, 1.19 + i * 0.14, 0)
		_spiess_dreher.add_child(schicht)

	var heizung := MeshInstance3D.new()
	var heiz_form := BoxMesh.new()
	heiz_form.size = Vector3(0.08, 1.2, 0.42)
	heiz_form.material = _mat(Color(0.3, 0.1, 0.06), 0.6, Color(1.0, 0.32, 0.08), 1.8)
	heizung.mesh = heiz_form
	heizung.position = fuss + Vector3(-0.45, 1.75, 0)
	add_child(heizung)

	var glut := OmniLight3D.new()
	glut.position = fuss + Vector3(-0.3, 1.75, 0)
	glut.light_color = Color(1.0, 0.45, 0.2)
	glut.light_energy = 1.3
	glut.omni_range = 2.6
	glut.omni_attenuation = 1.5
	add_child(glut)


func _cafe_beschildern() -> void:
	_schrift("CAFÉ", Vector3(48.5, 3.15, -100.0), PI * 0.5, Color(0.86, 0.80, 0.68), 260)
	var zettel := _schrift(
		"WEGEN CORONA GESCHLOSSEN", Vector3(48.45, 1.75, -99.2), PI * 0.5,
		Color(0.92, 0.92, 0.88), 42
	)
	zettel.rotate_z(0.05)


func _buero_beschildern() -> void:
	_schrift("BÜRO", Vector3(14.78, 2.3, -7.65), -PI * 0.5, Color(0.9, 0.86, 0.7), 46)


func _fernsehturm_beleuchten() -> void:
	var turm := get_parent().get_node_or_null("Fernsehturm")
	if turm == null:
		return
	var kugel := turm.get_node_or_null("Kugel") as CSGSphere3D
	if kugel != null:
		kugel.material = _mat(Color(0.45, 0.48, 0.54), 0.6, Color(0.35, 0.42, 0.55), 0.5)
	# Das rote Blinklicht an der Antennenspitze — nachts das Erste, was man
	# vom Turm sieht.
	var lampe := MeshInstance3D.new()
	var punkt := SphereMesh.new()
	punkt.radius = 1.4
	punkt.height = 2.8
	punkt.material = _mat(Color(1, 0.1, 0.1), 0.4, Color(1, 0.05, 0.05), 4.0)
	lampe.mesh = punkt
	lampe.position = Vector3(20, 240, -700)
	add_child(lampe)


func _litfasssaeulen_stellen() -> void:
	for stelle: Vector3 in [Vector3(-10.2, 0.08, -18.0), Vector3(70.3, 0.08, -112.0)]:
		var saeule := MeshInstance3D.new()
		var rohr := CylinderMesh.new()
		rohr.top_radius = 0.62
		rohr.bottom_radius = 0.62
		rohr.height = 3.0
		rohr.material = _mat(Color(0.26, 0.22, 0.21), 0.85)
		saeule.mesh = rohr
		saeule.position = stelle + Vector3(0, 1.5, 0)
		add_child(saeule)
		var deckel := MeshInstance3D.new()
		var kappe := CylinderMesh.new()
		kappe.top_radius = 0.5
		kappe.bottom_radius = 0.72
		kappe.height = 0.3
		kappe.material = _mat(Color(0.15, 0.14, 0.14), 0.8)
		deckel.mesh = kappe
		deckel.position = stelle + Vector3(0, 3.15, 0)
		add_child(deckel)

		# Plakatreste, tangential angeklebt und leicht schief.
		for i in 3:
			var winkel := i * TAU / 3.0 + 0.4
			var lage := stelle + Vector3(cos(winkel), 0.0, sin(winkel)) * 0.64
			lage.y = 1.55 + 0.2 * i
			_kasten(&"plakat_a" if i % 2 == 0 else &"plakat_b", lage,
				Vector3(0.55, 0.85, 0.015), -winkel + PI * 0.5, 0.04 * (i - 1))


## Ein schwaches Licht an der Kamera. Nachts wären die Gesichter zwischen den
## Laternen sonst schwarz — das Fülllicht hält die beiden lesbar, ohne dass es
## als Lichtquelle auffällt.
func _fuelllicht_anbringen() -> void:
	var rig := get_parent().get_node_or_null("ThirdPersonCamera")
	if rig == null:
		return
	var licht := OmniLight3D.new()
	licht.light_color = Color(0.75, 0.78, 0.9)
	licht.light_energy = 0.28
	licht.omni_range = 12.0
	licht.omni_attenuation = 1.8
	licht.position = Vector3(0, 1.6, 0)
	rig.add_child(licht)


func _schrift(text: String, ort: Vector3, drehung: float, farbe: Color, groesse: int) -> Label3D:
	var schild := Label3D.new()
	schild.text = text
	schild.font_size = groesse
	schild.modulate = farbe
	schild.position = ort
	schild.rotation.y = drehung
	add_child(schild)
	return schild
