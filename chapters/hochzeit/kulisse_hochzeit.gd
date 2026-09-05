extends Node3D

## Die Kulisse für Kapitel 3 — die Hochzeit an der Spree.
##
## Ein einziger Schauplatz, gebaut wie ein Bühnenbild: die Kamera schaut
## immer über das Wasser auf die **Oberbaumbrücke**, alles andere rahmt
## dieses Bild ein.
##
## Aufteilung (Weltkoordinaten):
##
## * **Ufer** — der Spielraum, z von 0 bis 14, Uferkante bei z = 0.
##   Hier stehen Traubogen, Stuhlreihen, Stehtische und die Gäste.
## * **Wasser** — z von 0 bis -120, eine große Fläche mit dem
##   Wellen-Shader (`wasser.gdshader`).
## * **Die Brücke** — quer über den Fluss bei z = -95, mit den beiden
##   Türmen, dem Bogengang und der Bahntrasse darüber.
## * **Das andere Ufer** — dahinter bei z = -150: Speicher aus Klinker,
##   der Glasbau, ein paar Bäume. Reine Silhouette.
##
## Vorlage ist ein Foto vom Südufer: Brücke im Mittelgrund, links die
## moderne Bebauung, rechts eine Trauerweide, die ins Bild hängt. Genau
## diese Weide steht deshalb rechts vorn — sie gibt dem Bild seinen Rahmen.

const _WEIDE := preload("res://assets/props/trauerweide.glb")
const _BOGEN := preload("res://assets/props/traubogen.glb")
const _STUHL := preload("res://assets/props/stuhl_weiss.glb")
const _STEHTISCH := preload("res://assets/props/biertisch.glb")
const _GIRLANDE := preload("res://assets/props/girlande.glb")
const _BAUM := preload("res://assets/props/baum_tag.glb")
const _LATERNE := preload("res://assets/props/laterne.glb")
const _GERIPPTE := preload("res://assets/props/gerippte.glb")

## Wo die Brücke über den Fluss geht.
const BRUECKE_Z := -95.0
## Wasserspiegel.
const WASSER_Y := -0.6

## Die Gäste — vom Kapitel für Blickrichtung und Jubel gebraucht.
var gaeste: Array[Node3D] = []
## Ort und Drehung jedes Stuhls — gefüllt beim Möblieren, gelesen beim
## Setzen der Gäste.
var _stuhlplaetze: Array = []



func _ready() -> void:
	_wasser_bauen()
	_ufer_bauen()
	_bruecke_bauen()
	_gegenueber_bauen()
	_spreespeicher_bauen()
	_fest_bauen()
	_gaeste_setzen()


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


## Foto-PBR aus `assets/texturen/<satz>` — dieselben ambientCG-Sätze wie in
## Kapitel 1 und 2.
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


func _bande(mitte: Vector3, masse: Vector3) -> void:
	var koerper := StaticBody3D.new()
	var form := CollisionShape3D.new()
	var kasten := BoxShape3D.new()
	kasten.size = masse
	form.shape = kasten
	koerper.add_child(form)
	add_child(koerper)
	koerper.position = mitte


## Ein liegender Zylinder als Bogen-Laibung: die Rundung eines Brückenbogens
## ist der halbe Mantel eines Zylinders, der quer im Mauerwerk liegt.
func _tonne(mitte: Vector3, radius: float, laenge: float,
		material: Material, seiten: int = 16) -> MeshInstance3D:
	var teil := MeshInstance3D.new()
	var form := CylinderMesh.new()
	form.top_radius = radius
	form.bottom_radius = radius
	form.height = laenge
	form.radial_segments = seiten
	form.material = material
	teil.mesh = form
	add_child(teil)
	teil.position = mitte
	teil.rotation.z = PI / 2.0
	return teil


# --- Wasser -------------------------------------------------------------------


func _wasser_bauen() -> void:
	var flaeche := MeshInstance3D.new()
	var netz := PlaneMesh.new()
	netz.size = Vector2(400.0, 240.0)
	# Unterteilung nur fürs Vertex-Wogen; 60 x 40 reicht bei 6 m Rastermaß.
	netz.subdivide_width = 60
	netz.subdivide_depth = 40
	var stoff := ShaderMaterial.new()
	stoff.shader = load("res://chapters/hochzeit/wasser.gdshader")
	netz.material = stoff
	flaeche.mesh = netz
	add_child(flaeche)
	flaeche.position = Vector3(0.0, WASSER_Y, -110.0)

	# Der Flussgrund als dunkle Fläche darunter — ohne sie schimmert bei
	# flachem Blick der Himmel durch die halbdurchsichtigen Kämme.
	_kasten(Vector3(0.0, WASSER_Y - 1.2, -110.0), Vector3(400.0, 0.4, 240.0),
		_mat(Color(0.04, 0.07, 0.09), 1.0))


# --- Ufer ---------------------------------------------------------------------


func _ufer_bauen() -> void:
	var pflaster := _foto_mat("beton_platten", Color(0.50, 0.49, 0.46), 0.34, 0.7)
	var beton := _foto_mat("beton_rau", Color(0.38, 0.37, 0.35), 0.26, 0.8)
	# Echter Rasen statt grüner Farbfläche (kachelbarer Satz aus
	# tools/make_rasen.py — Halm-Strichel, Farbflecken, Normal-Map).
	var wiese := _foto_mat("rasen", Color(1.0, 1.0, 1.0), 0.5, 1.1)

	# Uferpromenade und Wiese dahinter.
	_kasten(Vector3(0.0, -0.02, 7.0), Vector3(200.0, 0.16, 14.0), pflaster)
	_kasten(Vector3(0.0, -0.03, 26.0), Vector3(200.0, 0.14, 24.0), wiese)
	# Die Kaimauer: Kante, Abdeckplatte, und die Wand hinunter ins Wasser.
	_kasten(Vector3(0.0, -0.08, 0.25), Vector3(200.0, 0.30, 0.9), beton)
	_kasten(Vector3(0.0, -1.6, -0.1), Vector3(200.0, 3.0, 0.7), beton)
	# Graffiti-Streifen auf der Kaimauer, wie auf der Vorlage.
	for i in 7:
		var x := -30.0 + i * 11.0
		_kasten(Vector3(x, -0.55, -0.46), Vector3(6.5, 0.75, 0.04),
			_mat(Color(0.30, 0.34, 0.42).lerp(
				Color(0.52, 0.30, 0.36), float(i) / 6.0), 0.95))

	# Poller am Kai. Keiner auf der Mittelachse: dort schaut beim
	# Fangspiel die Kamera durch — ein dunkler Poller mitten im Fangring
	# las sich als Teil der Hände.
	for i in 9:
		var x := -34.0 + i * 8.5
		if absf(x) < 2.0:
			continue
		var poller := MeshInstance3D.new()
		var form := CylinderMesh.new()
		form.top_radius = 0.14
		form.bottom_radius = 0.17
		form.height = 0.55
		form.material = _mat(Color(0.16, 0.16, 0.17), 0.7)
		poller.mesh = form
		add_child(poller)
		poller.position = Vector3(x, 0.32, 1.1)

	# Die Weide rechts vorn — der Rahmen des Bildes.
	_prop(_WEIDE, Vector3(15.5, 0.0, 3.2), 0.6, 1.05)
	_prop(_WEIDE, Vector3(24.0, 0.0, 6.0), 2.3, 0.85)
	# Ein paar Bäume weiter hinten links.
	for daten in [[-26.0, 9.0, 1.0], [-18.0, 12.5, 1.15], [-33.0, 14.0, 0.95]]:
		_prop(_BAUM, Vector3(daten[0], 0.0, daten[1]), daten[0] * 0.4, daten[2])
	_prop(_LATERNE, Vector3(-12.0, 0.0, 5.4), PI)
	_prop(_LATERNE, Vector3(9.0, 0.0, 5.4), PI)

	# Unsichtbare Banden: nicht ins Wasser, nicht aus dem Bild.
	_bande(Vector3(0.0, 1.6, -0.8), Vector3(200.0, 3.2, 0.6))
	_bande(Vector3(0.0, 1.6, 34.0), Vector3(200.0, 3.2, 0.6))
	_bande(Vector3(-42.0, 1.6, 16.0), Vector3(0.6, 3.2, 40.0))
	_bande(Vector3(42.0, 1.6, 16.0), Vector3(0.6, 3.2, 40.0))


# --- Die Oberbaumbrücke -------------------------------------------------------


func _bruecke_bauen() -> void:
	## Die Brücke ist der Hintergrund des ganzen Kapitels, also lohnt sie
	## Aufwand.
	##
	## **Die Bögen sind echte Löcher**, kein aufgemaltes Dunkel: jede
	## Flussöffnung ist ein CSG-Körper — eine Wand, aus der ein liegender
	## Zylinder und ein Kasten herausgeschnitten werden. Der erste Versuch
	## legte stattdessen Zylinder *vor* das Mauerwerk und füllte die Zwickel
	## mit Kästen; heraus kam eine Backsteinwand mit Beulen. Ein Bogen ist
	## eine Öffnung, und Öffnungen muss man schneiden.
	##
	## Die Höhen sind an der Vorlage abgeschätzt: Fahrbahn gut sechs Meter
	## über dem Wasser, darüber der Bogengang mit der Bahntrasse.
	var klinker := _foto_mat("klinker", Color(0.78, 0.44, 0.35), 0.14, 1.0)
	var klinker_dunkel := _foto_mat("klinker", Color(0.56, 0.31, 0.25), 0.14, 1.0)
	var sandstein := _mat(Color(0.78, 0.74, 0.66), 0.85)
	var schiefer := _mat(Color(0.36, 0.33, 0.33), 0.7)

	const BREITE := 19.0        # Tiefe der Brücke in z
	const SPANNE := 24.0        # Abstand der Pfeilermitten in x
	const PFEILER := 4.2        # Pfeilerbreite in x
	const KAEMPFER := 2.1       # Höhe, in der die Bögen ansetzen
	const STICH := 3.2          # Bogenstich
	const DECK_UNTEN := 5.8     # Unterkante Fahrbahnplatte
	const DECK_OBEN := 6.9
	const MITTE_X := 0.0
	var laenge := SPANNE * 5.0

	# Pfeiler mit angeschrägtem Vorkopf.
	for i in 6:
		var x := MITTE_X - laenge / 2.0 + i * SPANNE
		_kasten(Vector3(x, (WASSER_Y - 1.5 + DECK_UNTEN) / 2.0, BRUECKE_Z),
			Vector3(PFEILER, DECK_UNTEN - WASSER_Y + 1.5, BREITE),
			klinker_dunkel)
		for z in [BRUECKE_Z - BREITE / 2.0 - 1.1, BRUECKE_Z + BREITE / 2.0 + 1.1]:
			_kasten(Vector3(x, WASSER_Y + 0.5, z), Vector3(PFEILER, 2.2, 2.4),
				sandstein)

	# Die fünf Flussöffnungen als CSG-Wände mit ausgeschnittenem Bogen.
	var halb := (SPANNE - PFEILER) / 2.0
	var radius := (halb * halb + STICH * STICH) / (2.0 * STICH)
	for i in 5:
		var mitte_x := MITTE_X - laenge / 2.0 + SPANNE * (i + 0.5)
		var wand := CSGCombiner3D.new()
		wand.operation = CSGShape3D.OPERATION_UNION
		add_child(wand)
		wand.position = Vector3(mitte_x, 0.0, BRUECKE_Z)

		var block := CSGBox3D.new()
		block.size = Vector3(SPANNE - PFEILER + 0.2, DECK_UNTEN - WASSER_Y + 1.0,
			BREITE)
		block.position = Vector3(0.0,
			(WASSER_Y - 1.0 + DECK_UNTEN) / 2.0, 0.0)
		block.material = klinker
		wand.add_child(block)

		# Der Bogen: ein liegender Zylinder, dessen Mittelpunkt so tief
		# sitzt, dass nur das Segment über dem Kämpfer schneidet.
		var bogen := CSGCylinder3D.new()
		bogen.radius = radius
		bogen.height = BREITE + 2.0
		bogen.sides = 28
		bogen.operation = CSGShape3D.OPERATION_SUBTRACTION
		bogen.rotation.z = PI / 2.0
		bogen.position = Vector3(0.0, KAEMPFER + STICH - radius, 0.0)
		wand.add_child(bogen)

		# Und der Teil unter dem Kämpfer.
		var unten := CSGBox3D.new()
		unten.size = Vector3(halb * 2.0, KAEMPFER - WASSER_Y + 2.0, BREITE + 2.0)
		unten.position = Vector3(0.0,
			(WASSER_Y - 2.0 + KAEMPFER) / 2.0, 0.0)
		unten.operation = CSGShape3D.OPERATION_SUBTRACTION
		wand.add_child(unten)

		# Bogenlaibung als heller Sandsteinring über der Öffnung.
		var stirn := CSGCylinder3D.new()
		stirn.radius = radius + 0.35
		stirn.height = 0.5
		stirn.sides = 28
		stirn.rotation.z = PI / 2.0
		stirn.position = Vector3(0.0, KAEMPFER + STICH - radius,
			BREITE / 2.0 + 0.2)
		stirn.material = sandstein
		var stirnring := CSGCombiner3D.new()
		stirnring.position = Vector3(mitte_x, 0.0, BRUECKE_Z)
		add_child(stirnring)
		stirnring.add_child(stirn)
		var loch := CSGCylinder3D.new()
		loch.radius = radius
		loch.height = 0.8
		loch.sides = 28
		loch.operation = CSGShape3D.OPERATION_SUBTRACTION
		loch.rotation.z = PI / 2.0
		loch.position = stirn.position
		stirnring.add_child(loch)
		var wegschnitt := CSGBox3D.new()
		wegschnitt.size = Vector3(SPANNE, KAEMPFER - WASSER_Y + 2.0, 1.2)
		wegschnitt.position = Vector3(0.0, (WASSER_Y - 2.0 + KAEMPFER) / 2.0,
			BREITE / 2.0 + 0.2)
		wegschnitt.operation = CSGShape3D.OPERATION_SUBTRACTION
		stirnring.add_child(wegschnitt)

	# Fahrbahnplatte, Gesims und Brüstung.
	_kasten(Vector3(MITTE_X, (DECK_UNTEN + DECK_OBEN) / 2.0, BRUECKE_Z),
		Vector3(laenge + PFEILER, DECK_OBEN - DECK_UNTEN, BREITE), klinker)
	_kasten(Vector3(MITTE_X, DECK_UNTEN - 0.25, BRUECKE_Z),
		Vector3(laenge + PFEILER, 0.5, BREITE + 1.0), sandstein)
	for z in [BRUECKE_Z - BREITE / 2.0 + 0.5, BRUECKE_Z + BREITE / 2.0 - 0.5]:
		_kasten(Vector3(MITTE_X, DECK_OBEN + 0.55, z),
			Vector3(laenge + PFEILER, 1.1, 0.7), sandstein)

	_bogengang_bauen(klinker, sandstein, laenge + PFEILER, DECK_OBEN)
	_tuerme_bauen(klinker, sandstein, schiefer, DECK_OBEN)


## Der Bogengang: die Bahntrasse liegt auf einer Reihe kleiner Rundbögen.
## Das ist das Merkmal, an dem man die Brücke erkennt.
func _bogengang_bauen(klinker: Material, sandstein: Material,
		laenge: float, deck: float) -> void:
	const BREITE := 8.6
	var fuss := deck + 1.1
	var hoehe := 5.0

	# Die Pfeilerreihe: alle 3 m ein Pfeiler, dazwischen bleibt die Öffnung.
	var pfeiler := MultiMesh.new()
	pfeiler.transform_format = MultiMesh.TRANSFORM_3D
	var saeule := BoxMesh.new()
	saeule.size = Vector3(0.85, hoehe, BREITE)
	saeule.material = klinker
	pfeiler.mesh = saeule
	var orte: Array[Vector3] = []
	var x := -laenge / 2.0 + 0.5
	while x < laenge / 2.0:
		orte.append(Vector3(x, fuss + hoehe / 2.0, BRUECKE_Z))
		x += 3.0
	pfeiler.instance_count = orte.size()
	for i in orte.size():
		pfeiler.set_instance_transform(i, Transform3D(Basis.IDENTITY, orte[i]))
	var traeger := MultiMeshInstance3D.new()
	traeger.multimesh = pfeiler
	add_child(traeger)

	# Rückwand hinter den Pfeilern: dadurch sind die Öffnungen dunkel und
	# der Bogengang liest sich als Gang, nicht als Zaun.
	_kasten(Vector3(0.0, fuss + hoehe / 2.0, BRUECKE_Z - BREITE / 2.0 + 0.3),
		Vector3(laenge, hoehe, 0.6), _mat(Color(0.20, 0.13, 0.11), 0.95))

	# Rundbogen-Köpfe zwischen den Pfeilern: halbe Zylinder, oben bündig.
	var boegen := MultiMesh.new()
	boegen.transform_format = MultiMesh.TRANSFORM_3D
	var kopf := CylinderMesh.new()
	kopf.top_radius = 1.05
	kopf.bottom_radius = 1.05
	kopf.height = 1.2
	kopf.radial_segments = 12
	kopf.material = klinker
	boegen.mesh = kopf
	var bogen_orte: Array[Vector3] = []
	for i in orte.size() - 1:
		bogen_orte.append(Vector3((orte[i].x + orte[i + 1].x) / 2.0,
			fuss + hoehe - 1.0, BRUECKE_Z + BREITE / 2.0 - 0.6))
	boegen.instance_count = bogen_orte.size()
	for i in bogen_orte.size():
		boegen.set_instance_transform(i, Transform3D(
			Basis(Vector3.RIGHT, PI / 2.0), bogen_orte[i]))
	var bogentraeger := MultiMeshInstance3D.new()
	bogentraeger.multimesh = boegen
	add_child(bogentraeger)

	# Die Trasse obendrauf, mit Gesims und Zinnenkranz.
	_kasten(Vector3(0.0, fuss + hoehe + 0.9, BRUECKE_Z),
		Vector3(laenge, 1.8, BREITE + 1.4), klinker)
	_kasten(Vector3(0.0, fuss + hoehe + 1.95, BRUECKE_Z),
		Vector3(laenge, 0.45, BREITE + 2.2), sandstein)
	var zinnen := MultiMesh.new()
	zinnen.transform_format = MultiMesh.TRANSFORM_3D
	var zahn := BoxMesh.new()
	zahn.size = Vector3(1.1, 1.0, 0.7)
	zahn.material = klinker
	zinnen.mesh = zahn
	var zinnen_orte: Array[Vector3] = []
	x = -laenge / 2.0 + 0.9
	while x < laenge / 2.0:
		for z in [BRUECKE_Z - BREITE / 2.0 - 0.7, BRUECKE_Z + BREITE / 2.0 + 0.7]:
			zinnen_orte.append(Vector3(x, fuss + hoehe + 2.6, z))
		x += 2.2
	zinnen.instance_count = zinnen_orte.size()
	for i in zinnen_orte.size():
		zinnen.set_instance_transform(i,
			Transform3D(Basis.IDENTITY, zinnen_orte[i]))
	var zinnentraeger := MultiMeshInstance3D.new()
	zinnentraeger.multimesh = zinnen
	add_child(zinnentraeger)


## Die beiden Türme: achteckiger Schaft, Galerie, Spitzhelm, Wetterfahne.
## Auf der Vorlage stehen sie versetzt, und der rechte ist der breitere.
func _tuerme_bauen(klinker: Material, sandstein: Material,
		schiefer: Material, deck: float) -> void:
	for daten in [[-12.0, 0.94, false], [12.0, 1.14, true]]:
		var x: float = daten[0]
		var wuchs: float = daten[1]
		var mit_uhr: bool = daten[2]
		var fuss := deck
		var schaft := 13.5 * wuchs

		var turm := MeshInstance3D.new()
		var form := CylinderMesh.new()
		form.top_radius = 2.5 * wuchs
		form.bottom_radius = 2.8 * wuchs
		form.height = schaft
		form.radial_segments = 8
		form.material = klinker
		turm.mesh = form
		add_child(turm)
		turm.position = Vector3(x, fuss + schaft / 2.0, BRUECKE_Z)
		turm.rotation.y = PI / 8.0

		# Galerie mit Zinnen.
		var galerie := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = 3.2 * wuchs
		ring.bottom_radius = 3.0 * wuchs
		ring.height = 1.0
		ring.radial_segments = 8
		ring.material = sandstein
		galerie.mesh = ring
		add_child(galerie)
		galerie.position = Vector3(x, fuss + schaft + 0.45, BRUECKE_Z)
		galerie.rotation.y = PI / 8.0
		for i in 8:
			var w := TAU * i / 8.0 + PI / 8.0
			_kasten(Vector3(x + cos(w) * 2.9 * wuchs, fuss + schaft + 1.35,
					BRUECKE_Z + sin(w) * 2.9 * wuchs),
				Vector3(0.95, 0.9, 0.95), klinker, w)

		# Spitzhelm mit Wetterfahne.
		var helm := MeshInstance3D.new()
		var spitze := CylinderMesh.new()
		spitze.top_radius = 0.02
		spitze.bottom_radius = 2.6 * wuchs
		spitze.height = 6.8 * wuchs
		spitze.radial_segments = 8
		spitze.material = schiefer
		helm.mesh = spitze
		add_child(helm)
		helm.position = Vector3(x, fuss + schaft + 1.8 + 3.4 * wuchs, BRUECKE_Z)
		helm.rotation.y = PI / 8.0
		var fahnenfuss := fuss + schaft + 1.8 + 6.8 * wuchs
		_kasten(Vector3(x, fahnenfuss + 0.7, BRUECKE_Z),
			Vector3(0.08, 1.4, 0.08), _mat(Color(0.20, 0.19, 0.18), 0.5))
		_kasten(Vector3(x + 0.32, fahnenfuss + 1.25, BRUECKE_Z),
			Vector3(0.64, 0.3, 0.05), _mat(Color(0.20, 0.19, 0.18), 0.5))

		# Spitzbogenfenster im Schaft.
		for etage in 3:
			for i in 4:
				var w := TAU * i / 4.0 + PI / 8.0
				_kasten(Vector3(x + cos(w) * 2.5 * wuchs,
						fuss + 2.6 + etage * 3.8,
						BRUECKE_Z + sin(w) * 2.5 * wuchs),
					Vector3(0.7, 1.7, 0.3),
					_mat(Color(0.10, 0.09, 0.10), 0.6), w)

		if mit_uhr:
			# Der Giebel mit der Uhr steht neben dem Turm, nicht am Turm.
			var giebel_x := x - 5.4
			_kasten(Vector3(giebel_x, deck + 5.6, BRUECKE_Z),
				Vector3(4.6, 11.2, 9.4), klinker)
			var scheibe := MeshInstance3D.new()
			var uhr := CylinderMesh.new()
			uhr.top_radius = 0.95
			uhr.bottom_radius = 0.95
			uhr.height = 0.22
			uhr.radial_segments = 20
			uhr.material = _mat(Color(0.92, 0.90, 0.84), 0.5)
			scheibe.mesh = uhr
			add_child(scheibe)
			scheibe.position = Vector3(giebel_x, deck + 8.6, BRUECKE_Z + 4.8)
			scheibe.rotation.x = PI / 2.0
			for zeiger in [[0.68, 0.07, 1.1], [0.44, 0.09, -0.6]]:
				var arm := _kasten(
					Vector3(giebel_x, deck + 8.6, BRUECKE_Z + 4.93),
					Vector3(zeiger[1], zeiger[0], 0.05),
					_mat(Color(0.15, 0.14, 0.14), 0.6))
				arm.rotation.z = zeiger[2]
				arm.position += Vector3(sin(zeiger[2]) * -zeiger[0] / 2.0,
					cos(zeiger[2]) * zeiger[0] / 2.0, 0.0)


# --- Das andere Ufer ----------------------------------------------------------


func _gegenueber_bauen() -> void:
	## Nur Silhouette: hinter der Brücke liegt Friedrichshain im Dunst.
	## Links der große Rasterbau mit der Glasfront (wie auf der Vorlage),
	## daneben Klinkerspeicher, dahinter Bäume.
	var klinker := _foto_mat("klinker", Color(0.58, 0.36, 0.30), 0.10, 0.8)
	var raster := _mat(Color(0.66, 0.60, 0.46), 0.7)
	var glas := _mat(Color(0.52, 0.62, 0.70), 0.15, Color(0.5, 0.6, 0.7), 0.15)

	_kasten(Vector3(-58.0, 11.0, -122.0), Vector3(34.0, 22.0, 22.0), raster)
	_kasten(Vector3(-38.0, 9.5, -120.0), Vector3(16.0, 19.0, 18.0), glas)
	_kasten(Vector3(-84.0, 6.0, -126.0), Vector3(26.0, 12.0, 20.0), klinker)
	_kasten(Vector3(28.0, 7.5, -124.0), Vector3(30.0, 15.0, 20.0), klinker)
	_kasten(Vector3(58.0, 5.0, -128.0), Vector3(24.0, 10.0, 18.0), klinker)
	# Ein Turm weiter hinten rechts.
	_kasten(Vector3(74.0, 22.0, -140.0), Vector3(11.0, 44.0, 11.0),
		_mat(Color(0.60, 0.62, 0.66), 0.4))
	# Baumreihe am Gegenufer.
	for i in 12:
		_prop(_BAUM, Vector3(-70.0 + i * 13.0, 0.0, -112.0),
			float(i) * 0.9, 1.1)
	# Das Gegenufer selbst.
	_kasten(Vector3(0.0, -0.4, -124.0), Vector3(520.0, 1.6, 40.0),
		_foto_mat("beton_rau", Color(0.50, 0.49, 0.46), 0.2, 0.8))
	# Ein breiter, dunkler Streifen ganz hinten: er schließt den Horizont,
	# damit dort kein weißes Nichts steht.
	_kasten(Vector3(0.0, 3.0, -168.0), Vector3(620.0, 12.0, 30.0),
		_mat(Color(0.44, 0.48, 0.50), 0.95))


# --- Der Spreespeicher --------------------------------------------------------


## Das Backstein-Lagerhaus hinter dem Fest — nach den Fotos vom echten
## Ort: lange Klinkerfassade mit Reihen von Bogenfenstern, dunkles
## Mansarddach mit Gaubenreihe und zwei Zwerchgiebeln, offene Loggien an
## den Ecken, unten Terrassenbögen mit Schirmen. Steht hinter dem Rasen
## (Front bei z = 38), außerhalb der Banden — reine Kulisse.
func _spreespeicher_bauen() -> void:
	var klinker := _foto_mat("klinker", Color(0.72, 0.52, 0.42), 0.14, 0.9)
	var dunkel := _mat(Color(0.10, 0.11, 0.12), 0.4)
	var fasche := _mat(Color(0.78, 0.70, 0.58), 0.85)
	var dach := _mat(Color(0.26, 0.23, 0.21), 0.9)
	var weiss := _mat(Color(0.88, 0.86, 0.82), 0.7)

	# Baugrund hinter dem Rasen, sonst schwebte der Speicher im Nichts.
	_kasten(Vector3(0.0, -0.02, 47.0), Vector3(200.0, 0.16, 18.0),
		_foto_mat("beton_platten", Color(0.48, 0.47, 0.44), 0.3, 0.7))

	# Hauptkorpus.
	_kasten(Vector3(0.0, 10.5, 46.0), Vector3(116.0, 21.0, 16.0), klinker)

	# Ein Bogenfenster: Fasche, dunkles Glas, runder Sturz (Zylinder mit
	# Achse in die Fassade).
	var bogenfenster := func(x: float, y: float, breit: float, hoch: float) -> void:
		_kasten(Vector3(x, y, 37.94), Vector3(breit + 0.34, hoch + 0.3, 0.12), fasche)
		_kasten(Vector3(x, y - 0.1, 37.90), Vector3(breit, hoch, 0.14), dunkel)
		var bogen := MeshInstance3D.new()
		var form := CylinderMesh.new()
		form.top_radius = breit * 0.5
		form.bottom_radius = breit * 0.5
		form.height = 0.14
		form.radial_segments = 14
		form.material = dunkel
		bogen.mesh = form
		add_child(bogen)
		bogen.position = Vector3(x, y + hoch * 0.5 - 0.1, 37.90)
		bogen.rotation.x = PI / 2.0

	# Fensterraster: fünf Geschosse, die Eck-Loggien bleiben frei.
	for geschoss in 5:
		var y := 5.4 + geschoss * 3.0
		for spalte in 24:
			var x := -48.3 + spalte * 4.2
			if absf(x) > 45.0:
				continue
			bogenfenster.call(x, y, 1.15, 1.9)

	# Erdgeschoss: Terrassenbögen, doppelt so breit.
	for i in 12:
		var x := -49.5 + i * 9.0
		bogenfenster.call(x, 1.9, 2.2, 2.6)

	# Eck-Loggien: dunkle, offene Nischen mit hellen Balkonplatten.
	for sx: float in [-1.0, 1.0]:
		var x := sx * 51.5
		_kasten(Vector3(x, 10.5, 37.95), Vector3(6.0, 19.0, 0.5), dunkel)
		for geschoss in 6:
			var y := 3.4 + geschoss * 3.0
			_kasten(Vector3(x, y, 37.55), Vector3(6.2, 0.22, 1.1), weiss)
			_kasten(Vector3(x, y + 0.55, 37.15), Vector3(6.2, 0.06, 0.06), weiss)

	# Mansarddach als Prisma, darüber nichts mehr — der Himmel gehört
	# der Brücke. Gauben und zwei Zwerchgiebel wie auf dem Foto.
	var first := MeshInstance3D.new()
	var prisma := PrismMesh.new()
	prisma.size = Vector3(117.0, 6.5, 17.5)
	prisma.material = dach
	first.mesh = prisma
	add_child(first)
	first.position = Vector3(0.0, 24.25, 46.0)
	for i in 11:
		var x := -45.0 + i * 9.0
		if absf(absf(x) - 18.0) < 2.5:
			continue  # Platz für die Zwerchgiebel
		_kasten(Vector3(x, 23.2, 41.4), Vector3(1.5, 1.7, 1.4), fasche)
		_kasten(Vector3(x, 23.15, 40.65), Vector3(0.9, 1.0, 0.1), dunkel)
	for sx: float in [-1.0, 1.0]:
		var x := sx * 18.0
		_kasten(Vector3(x, 22.9, 40.6), Vector3(5.2, 3.8, 1.6), fasche)
		_kasten(Vector3(x, 22.7, 39.75), Vector3(2.6, 2.0, 0.1), dunkel)
		var giebel := MeshInstance3D.new()
		var gform := PrismMesh.new()
		gform.size = Vector3(5.4, 1.8, 1.7)
		gform.material = dach
		giebel.mesh = gform
		add_child(giebel)
		giebel.position = Vector3(x, 25.7, 40.6)

	# Terrasse: Schirme vor den Bögen — überwiegend weiß, zwei dunkle.
	var schirm := func(x: float, hell: bool) -> void:
		var stiel := MeshInstance3D.new()
		var sform := CylinderMesh.new()
		sform.top_radius = 0.03
		sform.bottom_radius = 0.03
		sform.height = 2.4
		sform.material = dunkel
		stiel.mesh = sform
		add_child(stiel)
		stiel.position = Vector3(x, 1.2, 36.4)
		var dachteil := MeshInstance3D.new()
		var dform := CylinderMesh.new()
		dform.top_radius = 0.03
		dform.bottom_radius = 1.35
		dform.height = 0.55
		dform.radial_segments = 8
		dform.material = weiss if hell else _mat(Color(0.16, 0.17, 0.18), 0.8)
		dachteil.mesh = dform
		add_child(dachteil)
		dachteil.position = Vector3(x, 2.45, 36.4)
	for daten: Array in [[-40.0, true], [-27.0, true], [-13.5, false],
			[4.5, true], [17.5, true], [31.0, false], [43.0, true]]:
		schirm.call(daten[0], daten[1])


# --- Der Hochzeitsaufbau ------------------------------------------------------


func _fest_bauen() -> void:
	## Traubogen am Wasser, zwei Stuhlreihen davor, Stehtische hinten,
	## Lichterketten über der Fläche. Alles so gestellt, dass die Kamera
	## über den Bogen hinweg auf die Brücke sieht.
	_prop(_BOGEN, Vector3(0.0, 0.0, 2.6), 0.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2023
	# Zwei Stuhlreihen mit Mittelgang, den Rücken zum Wasser. Jeder Stuhl
	# merkt sich Ort und Drehung — die Gäste setzen sich später auf einen
	# Teil davon (gleiche Streuung, sonst sitzt jemand schräg zum Stuhl).
	for reihe in 2:
		for platz in 10:
			if platz == 4 or platz == 5:
				continue                       # Mittelgang
			var x := -7.2 + platz * 1.6
			var z := 7.4 + reihe * 1.7
			var gier := PI + rng.randf_range(-0.14, 0.14)
			_prop(_STUHL, Vector3(x, 0.06, z), gier)
			_stuhlplaetze.append({"ort": Vector3(x, 0.0, z), "gier": gier})
	# Rosa Läufer vom Gang zum Bogen — wie auf den Fotos vom echten Ort.
	_kasten(Vector3(0.0, 0.055, 5.6), Vector3(1.9, 0.03, 7.6),
		_mat(Color(0.76, 0.52, 0.55), 0.92))
	# Kerzenlaternen am Läufer: Metallrahmen, warm glimmender Kern.
	var metall := _mat(Color(0.55, 0.56, 0.58), 0.35)
	var kerze := _mat(Color(1.0, 0.85, 0.55), 0.6, Color(1.0, 0.75, 0.4), 1.4)
	for ort: Vector3 in [Vector3(-1.35, 0.0, 9.0), Vector3(1.35, 0.0, 9.0),
			Vector3(-1.35, 0.0, 3.6), Vector3(1.35, 0.0, 3.6)]:
		_kasten(ort + Vector3(0, 0.02, 0), Vector3(0.24, 0.03, 0.24), metall)
		_kasten(ort + Vector3(0, 0.22, 0), Vector3(0.09, 0.20, 0.09), kerze)
		for ecke: Vector3 in [Vector3(-0.1, 0, -0.1), Vector3(0.1, 0, -0.1),
				Vector3(-0.1, 0, 0.1), Vector3(0.1, 0, 0.1)]:
			_kasten(ort + ecke + Vector3(0, 0.21, 0),
				Vector3(0.02, 0.38, 0.02), metall)
		_kasten(ort + Vector3(0, 0.43, 0), Vector3(0.26, 0.04, 0.26), metall)
		_kasten(ort + Vector3(0, 0.49, 0), Vector3(0.05, 0.09, 0.05), metall)

	# Empfang: Stehtische mit Gläsern, etwas abseits.
	for daten in [[-13.0, 12.0], [-9.5, 15.5], [12.5, 12.5], [16.0, 15.0]]:
		var ort := Vector3(daten[0], 0.0, daten[1])
		_prop(_STEHTISCH, ort)
		for i in 3:
			var w := TAU * i / 3.0 + rng.randf()
			_prop(_GERIPPTE, ort + Vector3(cos(w) * 0.26, 1.10, sin(w) * 0.26),
				rng.randf() * TAU)

	# Lichterketten: genau **zwischen** den Masten, ein Bogen je Feld. Die
	# erste Fassung hängte sie im Sechs-Meter-Raster über die ganze Fläche,
	# unabhängig von den Masten — das sah aus wie eine Freileitung.
	# Die Masten stehen **außerhalb** der Wurfbahn. Ein Mast auf x = 0 stand
	# der Fangkamera einen halben Meter vor der Nase und verdeckte die halbe
	# Szene — die Bahn der Sträuße läuft genau dort.
	var masten := [-14.0, -8.0, 8.0, 14.0]
	var holz := _mat(Color(0.30, 0.26, 0.22), 0.8)
	# Und **hinter** der Fangkamera (die sitzt bei z = 11,6): eine Kette,
	# die vor der Linse durchhängt, verdeckt das halbe Spiel.
	for reihe in [13.5, 18.5]:
		for x: float in masten:
			_kasten(Vector3(x, 1.9, reihe), Vector3(0.11, 3.8, 0.11), holz)
			# Kleiner Querarm oben, an dem die Kette hängt.
			_kasten(Vector3(x, 3.74, reihe), Vector3(0.5, 0.09, 0.09), holz)
		# Außenfelder je ein Bogen, die Mitte überspannt ein langer.
		# Nicht in der Breite skalieren: der Maßstab zieht den Durchhang mit,
		# und eine 2,6-fach gestreckte Kette hing bis auf Kopfhöhe.
		for mitte in [-11.0, -5.3, 0.0, 5.3, 11.0]:
			_prop(_GIRLANDE, Vector3(mitte, 3.72, reihe), 0.0, 1.0)
	# Warmes Licht von den Ketten.
	for daten in [[-6.0, 13.5], [4.0, 13.5], [0.0, 18.5]]:
		var licht := OmniLight3D.new()
		licht.light_color = Color(1.0, 0.85, 0.62)
		licht.light_energy = 1.1
		licht.omni_range = 12.0
		add_child(licht)
		licht.position = Vector3(daten[0], 3.6, daten[1])


# --- Die Gäste ----------------------------------------------------------------


## Wie viele Menschen auf der Hochzeit stehen.
const GAESTE_GESAMT := 50

## Tönungen für Oberteile — gedeckt und sommerlich, als Multiplikator über
## der Stofftextur. Reines Weiß heißt: Original lassen.
const _OBEN_TOENE: Array[Color] = [
	Color(0.55, 0.62, 0.78), Color(0.60, 0.70, 0.60), Color(0.95, 0.90, 0.80),
	Color(0.75, 0.45, 0.50), Color(0.70, 0.70, 0.72), Color(0.42, 0.47, 0.62),
	Color(0.85, 0.62, 0.52), Color(1.0, 1.0, 1.0),
]
const _HOSEN_TOENE: Array[Color] = [
	Color(0.45, 0.45, 0.48), Color(0.80, 0.74, 0.62), Color(0.40, 0.44, 0.55),
	Color(0.52, 0.44, 0.38), Color(1.0, 1.0, 1.0),
]
## Haartönungen — Werte über 1 hellen auf (grau, blond).
const _HAAR_TOENE: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.55, 0.50, 0.45), Color(1.10, 0.88, 0.62),
	Color(0.35, 0.33, 0.30), Color(1.25, 1.20, 1.15), Color(0.85, 0.60, 0.42),
]


func _gaeste_setzen() -> void:
	## Fünfzig Gäste aus acht Mixamo-Modellen (`gast_1`–`gast_8`, Pipeline
	## siehe ASSET_REQUIREMENTS). Zehn **sitzen** auf den Stühlen
	## (Knochenpose in `Hochzeitsgast._hinsetzen`), sechs stehen fest an
	## Stehtischen und Reihenrändern, der Rest verteilt sich per Zufall
	## (fester Seed) über die Terrasse — variiert über Tönung, Größe und
	## Drehung, damit die Wiederholung nicht auffällt.
	var rng := RandomNumberGenerator.new()
	rng.seed = 815

	# Zehn der sechzehn Stühle sind besetzt — ein paar leere Stühle
	# erzählen mehr als volle Reihen (jemand holt Getränke, jemand steht
	# am Wasser). Die Auswahl kommt aus dem gesäten Zufall.
	var sitze: Array = _stuhlplaetze.duplicate()
	while sitze.size() > 10:
		sitze.remove_at(rng.randi() % sitze.size())

	# Feste Stehplätze: die Stehtische und zwei an den Reihenrändern.
	var staende: Array[Vector3] = [
		Vector3(-9.6, 0.0, 8.2), Vector3(9.2, 0.0, 8.4),
		Vector3(-12.4, 0.0, 12.6), Vector3(-9.0, 0.0, 15.0),
		Vector3(12.0, 0.0, 12.9), Vector3(15.4, 0.0, 14.6),
	]
	# Weitere Plätze hinter den Stuhlreihen und über die Terrasse
	# verstreut. Die Gasse hinter der Braut (x um 0, bis z 14) bleibt frei —
	# dort läuft man selbst, und beim Spiel steht die Kamera davor.
	while sitze.size() + staende.size() < GAESTE_GESAMT:
		var ort := Vector3(rng.randf_range(-16.5, 16.5), 0.0,
			rng.randf_range(10.5, 19.5))
		if absf(ort.x) < 2.6 and ort.z < 14.0:
			continue
		var eng := false
		for p in staende:
			if p.distance_to(ort) < 1.15:
				eng = true
				break
		if not eng:
			staende.append(ort)

	for i in GAESTE_GESAMT:
		var gast := Hochzeitsgast.new()
		var modell_nr := (i % 8) + 1
		gast.modell_pfad = "res://actors/models/gast_%d.glb" % modell_nr
		gast.zielhoehe = rng.randf_range(1.58, 1.92)
		# Mocap und Gangwerk sind auf das RPM-Rig geeicht; auf dem Mixamo-
		# Skelett verbiegen sie Kopf und Rumpf. Die Gäste stehen still —
		# Armsenkung und Höhenskalierung funktionieren rein über Knochennamen
		# und bleiben an.
		gast.mocap_aktiv = false
		gast.gangwerk_aktiv = false
		if i >= 8:
			# Ab der zweiten Runde durch die Modelle wird getönt; die ersten
			# acht zeigen die Originale.
			gast.oberteil = _OBEN_TOENE[rng.randi() % _OBEN_TOENE.size()]
			gast.hose = _HOSEN_TOENE[rng.randi() % _HOSEN_TOENE.size()]
			if modell_nr >= 7:
				gast.hose = gast.oberteil  # Anzug: Jackett und Hose gleich
			gast.haar_ton = _HAAR_TOENE[rng.randi() % _HAAR_TOENE.size()]
		# Ort und Drehung **vor** add_child: das Hinsetzen senkt die Figur
		# in _ready ab — eine danach gesetzte Position überschriebe das.
		if i < sitze.size():
			var platz: Dictionary = sitze[i]
			gast.sitzend = true
			# Der Stuhl schaut mit Modell-Gier PI nach −Z; die Figur schaut
			# mit Gier 0 nach −Z — gleiche Streuung, um PI versetzt. Und ein
			# Stück zur Lehne gerückt, sonst sitzt jeder auf der Vorderkante.
			var gier_gast := (platz["gier"] as float) - PI
			gast.rotation.y = gier_gast
			gast.position = (platz["ort"] as Vector3) \
				+ Vector3(sin(gier_gast), 0.0, cos(gier_gast)) * 0.12
		else:
			var ort: Vector3 = staende[i - sitze.size()]
			gast.position = ort
			# Zum Traubogen schauen — vorn andächtig, hinten beiläufiger.
			var zum_bogen := Vector3(0.0, 0.0, 2.6) - ort
			gast.rotation.y = atan2(zum_bogen.x, zum_bogen.z) + PI \
				+ (rng.randf_range(-0.7, 0.7) if i >= 8 else rng.randf_range(-0.15, 0.15))
		add_child(gast)
		gaeste.append(gast)
