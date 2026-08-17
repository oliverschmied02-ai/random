extends Node3D

## Die Kulisse: macht aus den grauen Blöcken einen Berliner Abend.
##
## Alles hier ist **Anstrich, keine Architektur**: Fassaden, Gehwege, Lichter
## und Schilder werden beim Laden über die vorhandenen Blöcke gelegt. Die
## Blöcke selbst — und damit Kollision, Route und alle gemessenen Zeiten —
## bleiben unangetastet. Einzige Ausnahme: die Gehwege tragen eine 8 cm hohe
## Platte mit Kollision, genau die Bordsteinkante, für die das Stufen-Steigen
## gebaut wurde.
##
## Gebaut wird prozedural statt von Hand, aus zwei Gründen: die Fassaden
## müssen zu den Blöcken passen, auch wenn jemand einen Block verschiebt —
## sie lesen Lage und Maße zur Laufzeit. Und tausende Fenster von Hand zu
## setzen wäre Fleißarbeit ohne Urteil. Der Zufall ist gesät (je Wand aus
## ihrem Namen), damit jede Runde gleich aussieht.
##
## Alle Kleinteile landen in wenigen MultiMeshes — ein Zeichenaufruf je
## Materialgruppe, egal ob dreihundert oder dreitausend Fenster.

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

var _stapel: Dictionary = {}
var _materialien: Dictionary = {}


func _ready() -> void:
	_materialien_anlegen()
	_boden_umfaerben()
	_fassaden_bauen()
	_gehwege_bauen()
	_markierungen_bauen()
	_gleisbett_bauen()
	_laternen_anzuenden()
	_doenerbude_beleben()
	_cafe_beschildern()
	_buero_beschildern()
	_fernsehturm_beleuchten()
	_litfasssaeulen_stellen()
	_fuelllicht_anbringen()
	_stapel_absetzen()


# --- Materialien und Sammelbecken -------------------------------------------


func _materialien_anlegen() -> void:
	_materialien = {
		&"rahmen": _mat(Color(0.82, 0.78, 0.70), 0.8),
		&"glas_dunkel": _mat(Color(0.07, 0.09, 0.13), 0.25, Color(0.10, 0.13, 0.20), 0.35),
		&"glas_hell": _mat(Color(0.85, 0.68, 0.42), 0.6, Color(1.0, 0.72, 0.38), 1.9),
		&"sockel": _mat(Color(0.30, 0.29, 0.28), 0.95),
		&"tuer": _mat(Color(0.23, 0.17, 0.13), 0.7),
		&"laden": _mat(Color(0.36, 0.37, 0.39), 0.5),
		&"ladenschild": _mat(Color(0.42, 0.18, 0.16), 0.7),
		&"gitter": _mat(Color(0.14, 0.15, 0.17), 0.5),
		&"markierung": _mat(Color(0.75, 0.74, 0.70), 0.9),
		&"gleisbett": _mat(Color(0.10, 0.10, 0.11), 1.0),
		&"birne": _mat(Color(1.0, 0.75, 0.4), 0.5, Color(1.0, 0.62, 0.25), 3.2),
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


func _lege(gruppe: StringName, lage: Transform3D) -> void:
	if not _stapel.has(gruppe):
		_stapel[gruppe] = []
	_stapel[gruppe].append(lage)


## Baut aus jedem Sammelbecken genau eine MultiMesh-Instanz.
func _stapel_absetzen() -> void:
	for gruppe in _stapel:
		var mesh: Mesh
		if gruppe == &"birne":
			var kugel := SphereMesh.new()
			kugel.radius = 0.055
			kugel.height = 0.11
			mesh = kugel
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


func _kasten(gruppe: StringName, mitte: Vector3, masse: Vector3, drehung: float) -> void:
	var basis := Basis(Vector3.UP, drehung) * Basis.from_scale(masse)
	_lege(gruppe, Transform3D(basis, mitte))


# --- Fassaden ----------------------------------------------------------------


func _boden_umfaerben() -> void:
	var boden := get_parent().get_node_or_null("Ground") as CSGBox3D
	if boden != null:
		boden.material = _mat(Color(0.145, 0.150, 0.165), 1.0)


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
		block.material = _mat(PALETTE[nummer % PALETTE.size()], 0.9)
		nummer += 1
		for richtung in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			_fassade(block, richtung, rng)


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

	# Fensterraster: mittig verteilt, Ränder bleiben frei.
	var spalten := int((breite - 3.2) / fenster_raster) + 1
	var start := -(spalten - 1) * fenster_raster * 0.5
	var reihe := 0
	var y := unten + 2.2
	while y + 1.0 < oben - 0.9:
		for i in spalten:
			var u := start + i * fenster_raster
			_kasten(&"rahmen", ort.call(u, y + 0.8, 0.045), Vector3(1.15, 1.75, 0.07), drehung)
			var gruppe := &"glas_hell" if rng.randf() < fenster_an_anteil else &"glas_dunkel"
			_kasten(gruppe, ort.call(u, y + 0.8, 0.06), Vector3(0.95, 1.55, 0.05), drehung)
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


func _grund_verboten(stelle: Vector3) -> bool:
	for feld in GRUND_FREI:
		if stelle.x >= feld[0] and stelle.z >= feld[1] and stelle.x <= feld[2] and stelle.z <= feld[3]:
			return true
	return false


# --- Straßenraum -------------------------------------------------------------


func _gehwege_bauen() -> void:
	var material := _mat(Color(0.40, 0.40, 0.42), 0.95)
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


func _laternen_anzuenden() -> void:
	var moebel := get_parent().get_node_or_null("StreetFurniture")
	if moebel == null:
		return
	var glas := _mat(Color(1.0, 0.85, 0.6), 0.4, Color(1.0, 0.78, 0.45), 2.4)
	for i in range(1, 11):
		var kopf := moebel.get_node_or_null("Kopf%d" % i) as CSGBox3D
		if kopf == null:
			continue
		kopf.material = glas
		var licht := OmniLight3D.new()
		licht.position = kopf.position + Vector3(0, -0.35, 0)
		licht.light_color = Color(1.0, 0.82, 0.55)
		licht.light_energy = 3.4
		licht.omni_range = 15.0
		licht.omni_attenuation = 1.4
		add_child(licht)


# --- Schauplätze ---------------------------------------------------------------


func _doenerbude_beleben() -> void:
	var bude := get_parent().get_node_or_null("Doenerbude")
	if bude == null:
		return
	var schild := bude.get_node_or_null("Schild") as CSGBox3D
	if schild != null:
		schild.material = _mat(Color(0.95, 0.79, 0.29), 0.5, Color(1.0, 0.76, 0.2), 2.2)
	var spiess := bude.get_node_or_null("Spiess") as CSGBox3D
	if spiess != null:
		spiess.material = _mat(Color(0.62, 0.42, 0.24), 0.6, Color(0.9, 0.5, 0.2), 0.5)

	_schrift("DÖNER", Vector3(122.0, 3.86, -237.4), 0.0, Color(0.5, 0.1, 0.08), 260)
	_schrift("IMBISS · SPÄTKAUF", Vector3(122.0, 3.32, -237.4), 0.0, Color(0.32, 0.09, 0.08), 84)

	# Lichterkette unter dem Vordach — neun warme Punkte.
	for i in 9:
		_lege(&"birne", Transform3D(Basis.IDENTITY,
			Vector3(119.9 + i * 0.53, 2.58 - 0.04 * (i % 2), -234.35)))

	var licht := get_parent().get_node_or_null("Lichter/Doener") as OmniLight3D
	if licht != null:
		licht.light_energy = 3.4
		licht.omni_range = 15.0
		licht.shadow_enabled = true


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
	for stelle in [Vector3(-10.2, 0.08, -18.0), Vector3(70.3, 0.08, -112.0)]:
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
