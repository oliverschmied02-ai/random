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
## Seit die Emission gedimmt ist (warm statt überstrahlt), dürfen es ein
## paar mehr sein — die Stadt wirkt bewohnt, nicht beleuchtet.
@export_range(0.0, 1.0, 0.01) var fenster_an_anteil: float = 0.18
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

## Straßenbäume: [x, z], entlang der Gehwege, mit Abstand zu Türen, Café,
## Bürofront und Bude. Unter den Oberleitungen bleiben sie mit ~5,2 m Höhe.
const BAEUME: Array = [
	[-10.3, 14.0], [-10.3, 1.0], [-10.3, -12.0], [-10.3, -25.0], [-10.3, -37.0],
	[10.3, -24.0], [10.3, -36.0],
	[22.0, -44.7], [36.0, -44.7], [50.0, -44.7], [64.0, -44.7],
	[49.8, -74.0], [49.8, -86.0], [49.8, -112.0], [49.8, -122.0],
	[70.5, -76.0], [70.5, -91.0], [70.5, -106.0], [70.5, -119.0],
	[62.0, -145.2], [78.0, -145.2], [94.0, -145.2], [110.0, -145.2],
	[82.0, -124.9], [98.0, -124.9], [114.0, -124.9], [130.0, -124.9],
	[119.9, -156.0], [119.9, -170.0], [119.9, -199.0],
	[140.3, -160.0], [140.3, -176.0], [140.3, -192.0], [140.3, -208.0], [140.3, -222.0],
]

## Fahrende Autos: je [von_x, von_z, bis_x, bis_z, versatz_s]. Sie fahren
## auf den Durchgangsstraßen, halten vor der Spielerin und tauchen nach
## einer Pause wieder am Anfang auf.
const FAHRTEN: Array = [
	[-2.2, 22.0, -2.2, -40.0, 0.0],
	[57.8, -68.0, 57.8, -132.0, 19.0],
	[138.0, -132.8, 54.0, -132.8, 41.0],
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
var _regen: CPUParticles3D
var _tram: Node3D
var _flugzeug: Node3D
var _flugzeug_blink: MeshInstance3D
var _verkehr: Array = []


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
	_baenke_ersetzen()
	_fuelllicht_anbringen()
	_baeume_pflanzen()
	_verkehr_starten()
	_passanten_beleben()
	_fahrraeder_abstellen()
	_pfuetzen_giessen()
	_regen_bauen()
	_tram_bauen()
	_flugzeug_starten()
	_spiegelsonden_setzen()
	_stapel_absetzen()


## Lebendiges Licht: eine Laterne flackert, das Dönerschild brummt. Reine
## Sinusmischungen — unregelmäßig genug, dass kein Muster auffällt, und ohne
## Zufall, damit jeder Prüflauf dasselbe sieht.
func _process(_delta: float) -> void:
	if _spiess_dreher != null:
		_spiess_dreher.rotate_y(_delta * 0.9)
	_verkehr_pflegen(_delta)
	var t := Time.get_ticks_msec() / 1000.0

	# Der Regen folgt der Kamera — nur dort, wo jemand hinsieht, muss es regnen.
	if _regen != null:
		var kamera := get_viewport().get_camera_3d()
		if kamera != null:
			var dort := kamera.global_position
			_regen.global_position = Vector3(dort.x, dort.y + 8.0, dort.z)

	# Die ferne Tram: quert alle 80 Sekunden die Gleisstraße, von Ost nach
	# West, und bleibt dabei östlich der Wegkreuzung (x > 30).
	if _tram != null:
		var takt := fmod(t, 80.0)
		if takt < 11.5:
			_tram.visible = true
			_tram.position.x = 112.0 - 7.0 * takt
		else:
			_tram.visible = false

	# Das Flugzeug zieht in gut drei Minuten über die Stadt, Blinklicht im Takt.
	if _flugzeug != null:
		var anteil := fmod(t, 200.0) / 200.0
		_flugzeug.position = Vector3(-400.0, 390.0, -650.0).lerp(
			Vector3(500.0, 390.0, -250.0), anteil)
		_flugzeug_blink.visible = fmod(t, 1.2) < 0.15
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
		# Fensterlicht: Emission bewusst unter ~1,2 — ab 2,0 frisst der
		# Tonemapper die Farbe und jedes Fenster strahlt klinisch weiß.
		# So bleibt es warmes Wohnzimmerlicht.
		&"glas_hell": _mat(Color(0.85, 0.60, 0.32), 0.6, Color(1.0, 0.60, 0.24), 1.1),
		&"glas_hell2": _mat(Color(0.88, 0.72, 0.46), 0.6, Color(1.0, 0.78, 0.42), 0.85),
		&"glas_tv": _mat(Color(0.5, 0.6, 0.8), 0.6, Color(0.5, 0.65, 1.1), 1.0),
		&"vorhang": _mat(Color(0.38, 0.26, 0.17), 0.9),
		&"sockel": _foto_mat("beton_rau", Color(0.64, 0.62, 0.59), 0.3, 1.2),
		&"tuer": _mat(Color(0.23, 0.17, 0.13), 0.7),
		&"laden": _mat(Color(0.36, 0.37, 0.39), 0.5),
		&"ladenschild": _mat(Color(0.42, 0.18, 0.16), 0.7),
		&"gitter": _mat(Color(0.14, 0.15, 0.17), 0.5),
		&"markierung": _mat(Color(0.75, 0.74, 0.70), 0.9),
		&"gleisbett": _foto_mat("schotter", Color(0.34, 0.34, 0.37), 0.8, 1.0),
		&"birne": _mat(Color(1.0, 0.75, 0.4), 0.5, Color(1.0, 0.62, 0.25), 3.2),
		&"dach": _mat(Color(0.16, 0.16, 0.18), 0.9),
		&"schornstein": _foto_mat("klinker", Color(0.85, 0.83, 0.8), 0.5, 1.0),
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
		&"fallrohr": _mat(Color(0.2, 0.21, 0.23), 0.55),
		&"graffiti_a": _graffiti_mat("a"),
		&"graffiti_b": _graffiti_mat("b"),
		&"graffiti_c": _graffiti_mat("c"),
		&"plakat_a": _mat(Color(0.74, 0.71, 0.63), 0.9),
		&"plakat_b": _mat(Color(0.60, 0.65, 0.60), 0.9),
		&"fuge": _mat(Color(0.30, 0.30, 0.32), 0.95),
		&"stern": _mat(Color(0.0, 0.0, 0.0), 1.0, Color(0.85, 0.88, 1.0), 0.55),
		&"ampel_rot": _mat(Color(0.3, 0.02, 0.02), 0.4, Color(1.0, 0.08, 0.05), 3.0),
	}
	# Schotter ist matt — die Foto-Rauheitskarte von Gravel022 ist zu glatt,
	# im Streifwinkel spiegelte das ganze Gleisbett wie nasses Glas.
	var bett := _materialien[&"gleisbett"] as StandardMaterial3D
	bett.roughness_texture = null
	bett.roughness = 0.97


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
	# Ohne anisotrope Filterung verschmieren Bodentexturen im flachen
	# Blickwinkel zu Schlieren — und Boden füllt das halbe Bild.
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Ein Graffiti-Tag (gebacken von tools/make_graffiti.py) als durchsichtige
## Fläche fürs Erdgeschoss.
func _graffiti_mat(variante: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/texturen/graffiti/%s.png" % variante)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.92
	return m


## Holt das Netz aus einem Requisiten-GLB — für MultiMesh-Instanzierung.
func _modul_mesh(name: String) -> Mesh:
	var szene := load("res://assets/props/%s.glb" % name) as PackedScene
	if szene == null:
		return null
	var wurzel := szene.instantiate()
	for kind in wurzel.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		if teil != null and teil.mesh != null:
			var netz := teil.mesh
			wurzel.free()
			return netz
	wurzel.free()
	return null


func _lege(gruppe: StringName, lage: Transform3D) -> void:
	if not _stapel.has(gruppe):
		_stapel[gruppe] = []
	_stapel[gruppe].append(lage)


## Baut aus jedem Sammelbecken genau eine MultiMesh-Instanz. Kugeln und
## Zylinder sind Einheitskörper und werden je Instanz skaliert.
func _stapel_absetzen() -> void:
	var kugelgruppen := [&"birne", &"stern", &"ampel_rot"]
	var zylindergruppen := [&"gully", &"poller", &"rad", &"antenne", &"radkappe", &"fallrohr"]
	var flaechengruppen := [&"graffiti_a", &"graffiti_b", &"graffiti_c"]
	# Fassadenmodule aus der Blender-Werkstatt: ein echtes Netz je Gruppe,
	# tausendfach instanziert wie die Grundkörper.
	var modulgruppen := {
		&"modul_fenster": "fenster_modul",
		&"modul_tuer": "tuer_modul",
		&"modul_gesims": "gesims_modul",
	}
	for gruppe in _stapel:
		var mesh: Mesh
		if gruppe in modulgruppen:
			mesh = _modul_mesh(modulgruppen[gruppe])
			if mesh == null:
				continue
		elif gruppe in kugelgruppen:
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
		elif gruppe in flaechengruppen:
			mesh = QuadMesh.new()
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
		# Module bringen ihre gebackene Textur aus dem GLB mit — kein Override.
		if gruppe in _materialien:
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
	boden.material = _foto_mat("asphalt", Color(0.55, 0.56, 0.6), 0.09, 1.0)


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
	# Regenfallrohre an den Fassadenrändern — Zink von Traufe bis Sockel.
	if breite > 12.0:
		for seite in [-1.0, 1.0]:
			_zylinder(&"fallrohr",
				ort.call(seite * (breite * 0.5 - 0.7), (unten + oben) * 0.5, 0.12),
				0.11, oben - unten - 0.4)
	# Kranzgesims als echtes Profil, je Wandbreite gestreckt.
	_lege(&"modul_gesims", Transform3D(
		Basis(Vector3.UP, drehung) * Basis.from_scale(Vector3(breite + 0.3, 1.0, 1.0)),
		ort.call(0.0, oben - 0.42, 0.0)))
	if block.size.y > 9.0:
		_kasten(&"rahmen", ort.call(0.0, unten + 4.35, 0.07), Vector3(breite, 0.16, 0.16), drehung)

	# Fensterraster: mittig verteilt, Ränder bleiben frei. Jedes Fenster ist
	# ein Blender-Modul: Faschen-Band, abgeschrägte Laibung, Fensterbank —
	# mit gebackener Verschattung, die aus dem 7-cm-Relief eine tiefe
	# Laibung macht. Scheibe und Vorhang hängen dahinter wie gehabt.
	var spalten := int((breite - 3.2) / fenster_raster) + 1
	var start := -(spalten - 1) * fenster_raster * 0.5
	var reihe := 0
	var y := unten + 2.2
	while y + 1.0 < oben - 0.9:
		for i in spalten:
			var u := start + i * fenster_raster
			_lege(&"modul_fenster", Transform3D(
				Basis(Vector3.UP, drehung), ort.call(u, y + 0.8, 0.0)))
			# Sprossenkreuz hinter der Öffnung — das Modul lässt sie offen.
			_kasten(&"rahmen", ort.call(u, y + 0.8, 0.03), Vector3(0.05, 1.5, 0.03), drehung)
			_kasten(&"rahmen", ort.call(u, y + 1.05, 0.03), Vector3(0.95, 0.05, 0.03), drehung)

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
				# Geländer aus Handlauf und Stäben — eine volle Platte liest
				# sich als Brett, erst die Lücken machen es zum Balkon.
				_kasten(&"gitter", ort.call(u, y + 0.78, 0.8), Vector3(1.7, 0.05, 0.05), drehung)
				for stab in 9:
					_kasten(&"gitter",
						ort.call(u - 0.8 + stab * 0.2, y + 0.36, 0.8),
						Vector3(0.028, 0.8, 0.028), drehung)
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
			_lege(&"modul_tuer", Transform3D(
				Basis(Vector3.UP, drehung), ort.call(u, unten + 1.48, 0.0)))
		elif i % 5 == 1 and rng.randf() < 0.3:
			# Ein verwitterter Tag zwischen den Fenstern — nichts sagt
			# schneller „Berlin" als besprühter Putz in Hüfthöhe.
			var tag: StringName = [&"graffiti_a", &"graffiti_b", &"graffiti_c"][rng.randi() % 3]
			_lege(tag, Transform3D(
				Basis(Vector3.UP, drehung)
					* Basis(Vector3(0, 0, 1), rng.randf_range(-0.06, 0.06))
					* Basis.from_scale(Vector3(rng.randf_range(1.8, 2.6), rng.randf_range(0.9, 1.3), 1.0)),
				ort.call(u + rng.randf_range(-0.4, 0.4), unten + 1.35, 0.115)))
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
	var material := _foto_mat("beton_platten", Color(0.72, 0.72, 0.76), 0.35, 0.6)
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


## Stellt ein in Blender gebautes Requisit auf (assets/props/<name>.glb).
## Abgestellte Fahrräder an den Hauswänden — nichts sagt schneller
## „Berlin". Das Modell liegt mit Gier 0 längs der Z-Achse (wie in
## Sachsenhausen erprobt); `lehnen` kippt es leicht zur Wand, als
## stünde es angelehnt statt auf einem unsichtbaren Ständer.
func _fahrraeder_abstellen() -> void:
	# [x, z, gier, lehnen] — an den Innenkanten der Gehwege, mit Abstand
	# zu Bäumen, Türen und den freigehaltenen Fronten (Büro, Café).
	for daten: Array in [
		[-11.3, 8.0, 0.0, -0.09], [-11.3, -18.5, 0.0, -0.07],
		[11.35, -22.5, PI, 0.09], [30.0, -46.2, PI * 0.5, -0.08],
		[51.2, -80.0, PI, 0.08], [68.85, -83.0, 0.0, -0.09],
		[86.0, -146.6, PI * 0.5, -0.07], [121.1, -180.0, PI, 0.08],
		[141.6, -212.0, PI, 0.08], [111.1, -232.0, 0.0, -0.08],
	]:
		# Der Reifen-Tiefpunkt liegt durch die eingebaute Anlehnung bei
		# −0,049 im Netz — der Aufsatzpunkt gehört auf die Gehwegplatte.
		var rad := _prop("fahrrad", Vector3(daten[0], 0.08 + 0.058, daten[1]), daten[2])
		if rad != null:
			rad.scale = Vector3.ONE * 1.18
			rad.rotation.z = daten[3]


## Pfützen auf den Gehwegen: flache, spiegelglatte Scheiben — die
## Screen-Space-Reflexionen der Szene holen Laternen und erleuchtete
## Fenster hinein, wie auf der Fahrbahn. Leicht elliptisch und gedreht,
## damit keine zwei gleich aussehen.
func _pfuetzen_giessen() -> void:
	var wasser := StandardMaterial3D.new()
	# Ein Hauch Himmelston statt Schwarz — ganz dunkle Scheiben lasen
	# sich als Löcher im Gehweg, nicht als Wasser.
	wasser.albedo_color = Color(0.10, 0.12, 0.17)
	wasser.roughness = 0.03
	wasser.metallic = 0.15
	var rng := RandomNumberGenerator.new()
	rng.seed = 1904
	for daten: Array in [
		[-10.2, 12.5], [-9.5, -8.0], [-10.8, -28.0],
		[10.5, 3.0], [9.4, -18.0], [10.9, -39.0],
		[26.0, -44.8], [44.0, -45.6], [63.0, -44.2],
		[49.6, -92.0], [50.6, -118.0], [70.2, -84.0], [69.4, -108.0],
		[72.0, -145.8], [100.0, -144.4], [92.0, -124.4], [118.0, -125.8],
		[119.6, -164.0], [120.7, -190.0], [139.6, -185.0], [140.9, -218.0],
		[109.8, -226.0],
	]:
		var lache := MeshInstance3D.new()
		var scheibe := CylinderMesh.new()
		scheibe.top_radius = 1.0
		scheibe.bottom_radius = 1.0
		scheibe.height = 0.006
		scheibe.radial_segments = 20
		scheibe.material = wasser
		lache.mesh = scheibe
		lache.scale = Vector3(rng.randf_range(0.45, 1.05), 1.0,
			rng.randf_range(0.3, 0.75))
		lache.rotation.y = rng.randf() * TAU
		lache.position = Vector3(daten[0], 0.083, daten[1])
		add_child(lache)


func _prop(name: String, ort: Vector3, gier: float = 0.0) -> Node3D:
	var szene := load("res://assets/props/%s.glb" % name) as PackedScene
	if szene == null:
		return null
	var teil := szene.instantiate() as Node3D
	teil.position = ort
	teil.rotation.y = gier
	add_child(teil)
	return teil


## Ein Quaternius-Wagen (CC0, siehe assets/props/quaternius/HERKUNFT.txt).
## Echte Proportionen, Front nach +Z wie die Projekt-Konvention — keine
## Drehung, keine Skalierung. TRANSPARENT lässt die Kit-Farbe stehen
## (das Taxi bleibt Taxi). Die Tönung teilt sich die Regel mit der
## Frankfurt-Kulisse (KulisseFfm.auto_einfaerben).
func _strassen_auto(art: String, ort: Vector3, gier: float,
		ton: Color = Color.TRANSPARENT) -> Node3D:
	var szene := load("res://assets/props/quaternius/%s.glb" % art) as PackedScene
	if szene == null:
		return null
	var wagen := szene.instantiate() as Node3D
	add_child(wagen)
	wagen.position = ort
	wagen.rotation.y = gier
	if ton != Color.TRANSPARENT:
		KulisseFfm.auto_einfaerben(wagen, ton)
	return wagen


## Findet in einem Requisit das Material mit dem gegebenen Namen und ersetzt
## es durch eine eigene Kopie — die importierten Materialien teilen sich
## sonst alle Exemplare.
func _prop_material(teil: Node3D, name: String) -> StandardMaterial3D:
	for kind in teil.find_children("*", "MeshInstance3D", true, false):
		var mi := kind as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat != null and mat.resource_name.contains(name):
				var kopie := mat.duplicate() as StandardMaterial3D
				mi.set_surface_override_material(s, kopie)
				return kopie
	return null


## Der nächste Punkt auf den Mittelstreifen — dorthin hängen die Laternen
## ihren Kopf über die Fahrbahn.
func _richtung_zur_strasse(fuss: Vector3) -> float:
	var beste := Vector3(fuss.x + 1.0, 0, fuss.z)
	var abstand := 1e9
	for linie in MARKIERUNGEN:
		var von := Vector3(linie[0], 0, linie[1])
		var bis := Vector3(linie[2], 0, linie[3])
		var t := clampf((fuss - von).dot(bis - von) / maxf((bis - von).length_squared(), 0.01), 0.0, 1.0)
		var punkt := von + (bis - von) * t
		var d := fuss.distance_to(punkt)
		if d < abstand:
			abstand = d
			beste = punkt
	var richtung := (beste - fuss).normalized()
	return atan2(richtung.x, richtung.z)


func _laternen_anzuenden() -> void:
	var moebel := get_parent().get_node_or_null("StreetFurniture")
	if moebel == null:
		return
	# Die Blender-Bogenlaternen ersetzen die CSG-Masten; der Kopf hängt über
	# die Fahrbahn (Arm zeigt zum nächsten Mittelstreifen). Zwei Leuchtmittel
	# wie auf echten Straßen: warmweiß und Natriumdampf-orange. Laterne 5
	# flackert.
	for i in range(1, 11):
		var kopf := moebel.get_node_or_null("Kopf%d" % i) as CSGBox3D
		var mast := moebel.get_node_or_null("Mast%d" % i) as CSGCylinder3D
		if kopf == null or mast == null:
			continue
		kopf.visible = false
		mast.visible = false
		var fuss := Vector3(mast.position.x, 0.0, mast.position.z)
		var gier := _richtung_zur_strasse(fuss)
		var laterne := _prop("laterne", fuss, gier)

		var orange := i % 2 == 0
		var glas := _prop_material(laterne, "lampenglas")
		if glas != null and orange:
			glas.albedo_color = Color(1.0, 0.78, 0.45)
			glas.emission = Color(1.0, 0.62, 0.28)

		var arm := Vector3(sin(gier), 0.0, cos(gier)) * 0.85
		var licht := OmniLight3D.new()
		licht.position = fuss + arm + Vector3(0, 5.4, 0)
		licht.light_color = Color(1.0, 0.72, 0.4) if orange else Color(1.0, 0.82, 0.55)
		licht.light_energy = 3.4
		licht.omni_range = 15.0
		licht.omni_attenuation = 1.4
		add_child(licht)
		_lichtkegel(licht.position, licht.light_color)
		if i == 5 and glas != null:
			_flacker.append({
				"material": glas, "licht": licht, "basis": 2.4, "licht_basis": 3.4,
				"ruhe": 0.7, "hub": 0.35, "takt": 11.0, "aussetzer": true,
			})

		# Der orange Berliner Mülleimer, am Mast montiert.
		if i % 2 == 1:
			_prop("muelleimer",
				Vector3(mast.position.x + 0.24, 0.72, mast.position.z + 0.1), gier + PI)


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


## Geparkte Autos: die Blender-Karosserie mit gerundeten Kanten. Jeder
## dritte Wagen in hellerem Lack — eine eigene Materialkopie je Exemplar.
func _autos_parken() -> void:
	# Kenney-Modelle im Wechsel, in gedeckten Abendfarben — und ein
	# beiges Taxi darunter, denn eine Berliner Straße ohne Taxi gibt
	# es nicht. Das Taxi behält seine Kit-Farbe.
	var arten: Array[String] = ["NormalCar1", "SUV", "NormalCar2",
		"Taxi", "NormalCar2", "NormalCar1"]
	var toene: Array = [
		Color(0.30, 0.31, 0.34), Color(0.14, 0.16, 0.22),
		Color(0.55, 0.56, 0.58), Color.TRANSPARENT,
		Color(0.85, 0.85, 0.83), Color(0.32, 0.12, 0.12),
	]
	var nummer := 0
	for eintrag in AUTOS:
		var fuss := Vector3(eintrag[0], 0.0, eintrag[1])
		var drehung: float = eintrag[2]
		_strassen_auto(arten[nummer % arten.size()], fuss, drehung,
			toene[nummer % toene.size()])
		nummer += 1


## Poller, Verteilerkästen, eine rote Ampel über leerer Kreuzung, Plakate an
## den Litfaßsäulen — das leblose Inventar einer Stadt im Lockdown.
func _moeblieren() -> void:
	for z in [-4.0, -9.0, -14.0]:
		_prop("poller", Vector3(8.2, 0.0, z))
	for z in [-186.0, -190.0, -194.0]:
		_prop("poller", Vector3(121.9, 0.0, z))

	for eintrag in [[-8.3, -35.0, PI * 0.5], [51.4, -78.0, -PI * 0.5], [119.9, -152.0, -PI * 0.5]]:
		_kasten(&"kasten_grau", Vector3(eintrag[0], 0.65, eintrag[1]),
			Vector3(0.65, 1.15, 0.42), eintrag[2])

	_ampel(Vector3(10.6, 0.08, -44.3))
	_ampel(Vector3(70.8, 0.08, -133.2))


## Eine Ampel, die rot in die leere Straße leuchtet — 2020 in einem Bild.
## Das Blender-Requisit; die Linsen schauen zum nächsten Mittelstreifen.
func _ampel(fuss: Vector3) -> void:
	_prop("ampel", Vector3(fuss.x, 0.0, fuss.z), _richtung_zur_strasse(fuss))


## Straßenbäume entlang der Gehwege — jede Stadt braucht Grün, und nachts
## brechen die Kronen die geraden Dachlinien. Leichte Zufallsdrehung und
## -größe je Baum, gesät, damit jede Runde gleich aussieht.
func _baeume_pflanzen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1989
	for eintrag in BAEUME:
		var baum := _prop("baum", Vector3(eintrag[0], 0.0, eintrag[1]),
			rng.randf() * TAU)
		if baum != null:
			var groesse := rng.randf_range(0.85, 1.15)
			baum.scale = Vector3(groesse, groesse * rng.randf_range(0.9, 1.1), groesse)


## Ein paar Autos fahren durch die Nacht — mit Scheinwerferlicht, und sie
## halten an, wenn die Spielerin vor ihnen die Straße quert. Rein visuell,
## keine Physik: die Straßen gehören weiter den Fußgängern.
## Passanten auf den Gehwegen: sechs Menschen, die ihre Abendwege gehen —
## hin und zurück, nah an den Fassaden, mit Abstand zu den Baumreihen.
## Die Wege decken jede Etappe der Route ab, damit die Stadt nie leer
## wirkt. Alle tragen FFP2 — Berlin im Herbst 2020, und die Maske nimmt
## den beiden Basismodellen nebenbei jede Ähnlichkeit mit Anne und Oliver.
func _passanten_beleben() -> void:
	var leute: Array = [
		# [modell, wegpunkte, start, kleid, haar, maske, groesse]
		["anne", [Vector3(-9.4, 0.08, 16.0), Vector3(-9.4, 0.08, -38.0)],
			0.15, Color(0.55, 0.20, 0.20), Color(0.34, 0.24, 0.16), true, 1.66],
		["oliver", [Vector3(9.4, 0.08, -38.0), Vector3(9.4, 0.08, 14.0)],
			0.45, Color(0.30, 0.36, 0.28), Color(0.16, 0.15, 0.14), true, 1.84],
		["oliver", [Vector3(14.0, 0.08, -45.8), Vector3(68.0, 0.08, -45.8)],
			0.30, Color(0.24, 0.28, 0.40), Color(2.2, 2.1, 2.0), true, 1.72],
		["anne", [Vector3(50.9, 0.08, -72.0), Vector3(50.9, 0.08, -130.0)],
			0.60, Color(0.72, 0.58, 0.26), Color(0.42, 0.26, 0.14), true, 1.62],
		["anne", [Vector3(54.0, 0.08, -146.3), Vector3(114.0, 0.08, -146.3)],
			0.50, Color(0.30, 0.30, 0.33), Color(1.5, 1.35, 1.05), true, 1.75],
		["oliver", [Vector3(139.2, 0.08, -152.0), Vector3(139.2, 0.08, -238.0)],
			0.25, Color(0.38, 0.28, 0.20), Color(0.24, 0.20, 0.16), true, 1.78],
	]
	for eintrag in leute:
		var passant := Passant.new()
		passant.modell_pfad = "res://actors/models/%s.glb" % eintrag[0]
		passant.weg = PackedVector3Array(eintrag[1])
		passant.start_anteil = eintrag[2]
		passant.kleid_ton = eintrag[3]
		passant.haar_ton = eintrag[4]
		passant.maske_an = eintrag[5]
		passant.zielhoehe = eintrag[6]
		# Kein Mocap: die Passanten sollen schlicht gehen, nicht gestikulieren.
		passant.mocap_aktiv = false
		add_child(passant)


func _verkehr_starten() -> void:
	var arten: Array[String] = ["NormalCar1", "SUV", "Taxi", "NormalCar2"]
	var toene: Array = [Color(0.20, 0.22, 0.28), Color(0.12, 0.12, 0.13),
		Color.TRANSPARENT, Color(0.35, 0.36, 0.38)]
	var nummer := 0
	for eintrag in FAHRTEN:
		var wagen := _strassen_auto(arten[nummer % arten.size()],
			Vector3(eintrag[0], 0.0, eintrag[1]), 0.0,
			toene[nummer % toene.size()])
		nummer += 1
		if wagen == null:
			continue
		var von := Vector3(eintrag[0], 0.0, eintrag[1])
		var bis := Vector3(eintrag[2], 0.0, eintrag[3])
		var richtung := (bis - von).normalized()
		wagen.rotation.y = atan2(richtung.x, richtung.z)
		var scheinwerfer := SpotLight3D.new()
		scheinwerfer.position = Vector3(0, 0.75, 2.1)
		scheinwerfer.rotation.y = PI
		scheinwerfer.light_color = Color(1.0, 0.93, 0.78)
		scheinwerfer.light_energy = 5.0
		scheinwerfer.spot_range = 22.0
		scheinwerfer.spot_angle = 32.0
		scheinwerfer.spot_angle_attenuation = 0.6
		wagen.add_child(scheinwerfer)
		_verkehr.append({
			"wagen": wagen, "von": von, "bis": bis, "richtung": richtung,
			"laenge": von.distance_to(bis), "fortschritt": eintrag[4] * -6.0,
			"tempo": 7.5, "pause": 14.0,
		})


func _verkehr_pflegen(delta: float) -> void:
	var spieler := get_parent().get_node_or_null("Player") as Node3D
	for fahrt in _verkehr:
		var wagen: Node3D = fahrt["wagen"]
		# Negativer Fortschritt ist die Wartezeit vor der Abfahrt.
		var frei := true
		if spieler != null and fahrt["fortschritt"] >= 0.0:
			var voraus: Vector3 = spieler.global_position - wagen.global_position
			var entlang: float = fahrt["richtung"].dot(voraus)
			var seitlich: float = (voraus - fahrt["richtung"] * entlang).length()
			frei = entlang < 2.0 or entlang > 10.0 or seitlich > 3.0
		if frei:
			fahrt["fortschritt"] += fahrt["tempo"] * delta
		if fahrt["fortschritt"] > fahrt["laenge"]:
			fahrt["fortschritt"] = -fahrt["pause"] * fahrt["tempo"]
		var sichtbar: bool = fahrt["fortschritt"] >= 0.0
		wagen.visible = sichtbar
		if sichtbar:
			wagen.position = fahrt["von"] + fahrt["richtung"] * fahrt["fortschritt"]


## Feiner Nieselregen um die Kamera: Streifenpartikel in einer Box, die in
## `_process` der Kamera folgt. 2020 war ein nasses Frühjahr, und der nasse
## Asphalt braucht eine Quelle.
func _regen_bauen() -> void:
	_regen = CPUParticles3D.new()
	_regen.amount = 420
	_regen.lifetime = 1.5
	_regen.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_regen.emission_box_extents = Vector3(11, 0.5, 11)
	_regen.direction = Vector3(0.05, -1, 0.04)
	_regen.spread = 0.0
	_regen.gravity = Vector3.ZERO
	_regen.initial_velocity_min = 7.0
	_regen.initial_velocity_max = 9.0
	_regen.particle_flag_align_y = true
	var tropfen := BoxMesh.new()
	tropfen.size = Vector3(0.01, 0.32, 0.01)
	var nass := StandardMaterial3D.new()
	nass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nass.albedo_color = Color(0.62, 0.7, 0.85, 0.13)
	tropfen.material = nass
	_regen.mesh = tropfen
	_regen.position = Vector3(0, 9, 0)
	add_child(_regen)


## Eine ferne Tram quert die Gleisstraße — weit östlich der Stelle, an der
## der Spaziergang die Gleise kreuzt, damit sie niemandem durchs Bild fährt.
func _tram_bauen() -> void:
	_tram = Node3D.new()
	var wagen := MeshInstance3D.new()
	var kasten := BoxMesh.new()
	kasten.size = Vector3(13.5, 2.5, 2.3)
	kasten.material = _mat(Color(0.75, 0.72, 0.2), 0.5)
	wagen.mesh = kasten
	wagen.position = Vector3(0, 1.6, 0)
	_tram.add_child(wagen)
	var fenster := MeshInstance3D.new()
	var band := BoxMesh.new()
	band.size = Vector3(12.8, 0.75, 2.34)
	band.material = _mat(Color(0.95, 0.85, 0.6), 0.4, Color(1.0, 0.85, 0.55), 1.6)
	fenster.mesh = band
	fenster.position = Vector3(0, 2.0, 0)
	_tram.add_child(fenster)
	var buegel := MeshInstance3D.new()
	var stab := BoxMesh.new()
	stab.size = Vector3(0.08, 2.6, 1.4)
	stab.material = _mat(Color(0.1, 0.1, 0.12), 0.5)
	buegel.mesh = stab
	buegel.position = Vector3(-3.5, 4.1, 0)
	_tram.add_child(buegel)
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.9, 0.7)
	licht.light_energy = 2.2
	licht.omni_range = 9.0
	licht.position = Vector3(-7.0, 1.3, 0)
	_tram.add_child(licht)
	_tram.position = Vector3(120, 0, -55)
	_tram.visible = false
	add_child(_tram)


## Ein Flugzeug hoch über der Stadt: weißes Dauerlicht, rotes Blinklicht.
func _flugzeug_starten() -> void:
	_flugzeug = Node3D.new()
	var lampe := MeshInstance3D.new()
	var punkt := SphereMesh.new()
	punkt.radius = 1.2
	punkt.height = 2.4
	punkt.material = _mat(Color(1, 1, 1), 0.5, Color(1.0, 0.98, 0.9), 2.0)
	lampe.mesh = punkt
	_flugzeug.add_child(lampe)
	_flugzeug_blink = MeshInstance3D.new()
	var blink := SphereMesh.new()
	blink.radius = 1.0
	blink.height = 2.0
	blink.material = _mat(Color(0.4, 0.02, 0.02), 0.5, Color(1.0, 0.1, 0.05), 3.0)
	_flugzeug_blink.mesh = blink
	_flugzeug_blink.position = Vector3(0, 0, 3.5)
	_flugzeug.add_child(_flugzeug_blink)
	add_child(_flugzeug)


## Reflexionssonden für die Stellen, an denen die Kamera lange verweilt —
## im Forward+-Renderer ergänzen sie die Screen-Space-Reflexionen dort,
## wo deren Bildschirminformation endet.
func _spiegelsonden_setzen() -> void:
	for eintrag in [[Vector3(127, 4, -238), Vector3(30, 12, 26)],
			[Vector3(16, 5, -55), Vector3(44, 14, 32)]]:
		var sonde := ReflectionProbe.new()
		sonde.position = eintrag[0]
		sonde.size = eintrag[1]
		sonde.box_projection = true
		add_child(sonde)


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
		_prop("litfass", Vector3(stelle.x, 0.0, stelle.z))

		# Plakatreste, tangential angeklebt und leicht schief.
		for i in 3:
			var winkel := i * TAU / 3.0 + 0.4
			var lage := stelle + Vector3(cos(winkel), 0.0, sin(winkel)) * 0.64
			lage.y = 1.55 + 0.2 * i
			_kasten(&"plakat_a" if i % 2 == 0 else &"plakat_b", lage,
				Vector3(0.55, 0.85, 0.015), -winkel + PI * 0.5, 0.04 * (i - 1))


## Ersetzt die Sitzklötze der Parkbänke durch das Blender-Requisit. Der
## versteckte CSG-Klotz verliert seine Kollision mit der Sichtbarkeit,
## deshalb bekommt jede Bank einen eigenen unsichtbaren Kollisionskasten.
## Lehne zur Hauswand (+X), Sitz zur Straße — beide Bänke stehen östlich
## ihres Mittelstreifens.
func _baenke_ersetzen() -> void:
	for name in ["Bank1", "Bank2"]:
		var sitz := get_parent().get_node_or_null("%s/Sitz" % name) as CSGBox3D
		if sitz == null:
			continue
		sitz.visible = false
		var koerper := StaticBody3D.new()
		koerper.position = sitz.position
		var form := CollisionShape3D.new()
		var kasten := BoxShape3D.new()
		kasten.size = sitz.size
		form.shape = kasten
		koerper.add_child(form)
		add_child(koerper)
		_prop("bank", Vector3(sitz.position.x, 0.0, sitz.position.z), PI)


## Ein schwaches Licht an der Kamera. Nachts wären die Gesichter zwischen den
## Laternen sonst schwarz — das Fülllicht hält die beiden lesbar, ohne dass es
## als Lichtquelle auffällt.
func _fuelllicht_anbringen() -> void:
	var rig := get_parent().get_node_or_null("ThirdPersonCamera")
	if rig == null:
		return
	var licht := OmniLight3D.new()
	licht.light_color = Color(0.75, 0.78, 0.9)
	licht.light_energy = 0.36
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
