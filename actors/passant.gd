class_name Passant
extends Figur

## Ein Mensch, der nicht Anne und nicht Oliver ist — stehend (Frankfurt)
## oder auf einem Weg unterwegs (Berlin).
##
## Es gibt kein drittes Personenmodell und in dieser Arbeitsumgebung keinen
## Weg, eins zu besorgen (siehe `actors/models/README.md`). Ein Passant ist
## deshalb dasselbe `.glb` wie Anne oder Oliver — **umgefärbt und anders
## skaliert**. Das trägt, solange drei Regeln eingehalten werden:
##
##   1. Abstand. Aus 15 m und mehr liest das Auge Silhouette, Haltung und
##      Farbe — nicht das Gesicht. Passanten gehören an den Rand, nie in
##      eine Nahaufnahme. In Kapitel 1 hilft zusätzlich die FFP2-Maske:
##      2020 ist sie schlicht wahr, und sie nimmt dem Gesicht jede
##      Ähnlichkeit.
##   2. Körpergröße streuen. Zwei gleich große Menschen in einem Bild sind
##      derselbe Mensch, egal welche Jacke sie tragen.
##   3. Kleidung *und* Haar färben. Nur die Jacke zu tauschen reicht nicht,
##      der Kopf verrät die Kopie.
##
## **Stehen** kommt gratis: `Figur` hängt Mocap bzw. Gangwerk an — Gewicht
## verlagern, umschauen, atmen. **Gehen** kostet ebenfalls keine eigene
## Animationszeile: sind Wegpunkte gesetzt, schiebt dieser Knoten die Figur
## am Gehwegrand entlang (hin und zurück, am Ende wird gewendet, nichts
## teleportiert), und das Gangwerk liest die tatsächlich zurückgelegte
## Strecke und schreitet von selbst aus.

## Wegpunkte in Weltkoordinaten (y = Gehwegoberkante). Leer = stehen.
@export var weg: PackedVector3Array = PackedVector3Array()
## Gehtempo in m/s — Stadtbummel, kein Marsch.
@export var tempo: float = 1.3
## Wo auf dem Weg die Figur startet (0 = erster, 1 = letzter Punkt).
@export_range(0.0, 1.0, 0.01) var start_anteil: float = 0.0
## Tönung für das Outfit (multipliziert über die Textur). TRANSPARENT
## lässt das Original.
@export var kleid_ton: Color = Color.TRANSPARENT
## Tönung fürs Haar.
@export var haar_ton: Color = Color.TRANSPARENT
## FFP2-Maske aufsetzen (Berlin 2020).
@export var maske_an: bool = false
## Wen der Passant beiläufig ansieht (leer: niemanden).
@export var blickziel_pfad: NodePath
## Ab welchem Abstand er herschaut (Meter).
@export_range(0.0, 20.0, 0.5) var aufmerksamkeit: float = 6.0

const _MASKE := preload("res://assets/props/atemmaske.glb")

var _blickziel: Node3D
var _ziel: int = 1
var _vorwaerts: bool = true


func _ready() -> void:
	super()
	_blickziel = get_node_or_null(blickziel_pfad) as Node3D
	if modell == null:
		return
	_toenen()
	if maske_an:
		_maske_aufsetzen()
	if weg.size() >= 2:
		_auf_weg_setzen()
	if weg.size() >= 2 or _blickziel != null:
		set_physics_process(true)


func _physics_process(delta: float) -> void:
	if weg.size() >= 2:
		_schreiten(delta)
	if _blickziel != null:
		var nah := global_position.distance_to(
			_blickziel.global_position) < aufmerksamkeit
		schaue_an(_blickziel if nah else null)
	if gangwerk != null:
		super(delta)


## Einen Schritt Richtung nächster Wegpunkt; am Ende des Weges wenden.
func _schreiten(delta: float) -> void:
	var ziel := weg[_ziel]
	var diff := ziel - global_position
	diff.y = 0.0
	var strecke := tempo * delta
	if diff.length() <= strecke:
		global_position = Vector3(ziel.x, global_position.y, ziel.z)
		if _vorwaerts and _ziel >= weg.size() - 1:
			_vorwaerts = false
		elif not _vorwaerts and _ziel <= 0:
			_vorwaerts = true
		_ziel += 1 if _vorwaerts else -1
		return
	var richtung := diff.normalized()
	global_position += richtung * strecke
	# Die Figur schaut nach −Z; weich in die Laufrichtung drehen.
	var soll := atan2(-richtung.x, -richtung.z)
	global_rotation.y = lerp_angle(global_rotation.y, soll,
		1.0 - exp(-6.0 * delta))


func _auf_weg_setzen() -> void:
	# Startpunkt: `start_anteil` entlang der Gesamtstrecke abtragen, damit
	# die Passanten nicht alle synchron an den Wegenden loslaufen.
	var gesamt := 0.0
	for i in weg.size() - 1:
		gesamt += (weg[i + 1] - weg[i]).length()
	var rest := gesamt * clampf(start_anteil, 0.0, 1.0)
	for i in weg.size() - 1:
		var stueck := (weg[i + 1] - weg[i]).length()
		if rest <= stueck or i == weg.size() - 2:
			var t := clampf(rest / maxf(stueck, 0.001), 0.0, 1.0)
			global_position = weg[i].lerp(weg[i + 1], t)
			_ziel = i + 1
			var richtung := (weg[i + 1] - weg[i]).normalized()
			global_rotation.y = atan2(-richtung.x, -richtung.z)
			break
		rest -= stueck
	_letzte_lage = global_position


## Kleidung und Haar tönen — multiplikativ über die vorhandene Textur,
## wie bei den Hochzeitsgästen: Falten und Muster bleiben erhalten.
## RPM-Avatare tragen ihr Outfit in einem Material („outfit"), das Haar
## in einem zweiten („haircut"); Haut („AvatarBody") bleibt unangetastet.
## Die Materialien hängen an allen Exemplaren desselben Modells — deshalb
## je Fläche eine Kopie, nie das Original anfassen, sonst färbt sich Anne
## im Kapitel mit.
func _toenen() -> void:
	for kind in modell.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		if teil == null or teil.mesh == null:
			continue
		for s in teil.mesh.get_surface_count():
			var material := teil.get_active_material(s) as BaseMaterial3D
			if material == null:
				continue
			var ton := Color.TRANSPARENT
			if material.resource_name == "outfit":
				ton = kleid_ton
			elif material.resource_name == "haircut":
				ton = haar_ton
			if ton == Color.TRANSPARENT:
				continue
			var kopie := material.duplicate() as BaseMaterial3D
			kopie.albedo_color = ton
			teil.set_surface_override_material(s, kopie)


## Die FFP2-Maske ans Kopfknochen-Gelenk hängen. Sie folgt damit jedem
## Nicken und Umherschauen des Gangwerks. Maskensitz ist gemessen, nicht
## geraten: das Gesicht liegt im Frame des Kopfknochens bei +Z, die
## Gesichtsfläche bei z ≈ +0,13 (AABB des Kopf-Meshes). Das Maskenmodell
## schaut selbst nach +Z — es muss nur sitzen, nicht gedreht werden.
## Skaliert wird über die gemessene Breite, nicht über einen Faktor: das
## Modell stammt aus dem Minispiel und ist dort größer.
func _maske_aufsetzen() -> void:
	var skelett := skelett_finden()
	if skelett == null:
		return
	var idx := skelett.find_bone("Head")
	if idx < 0:
		return
	var halter := BoneAttachment3D.new()
	halter.bone_name = "Head"
	skelett.add_child(halter)
	var maske := _MASKE.instantiate() as Node3D
	halter.add_child(maske)
	var breite := 0.0
	for kind in maske.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		breite = maxf(breite, teil.get_aabb().size.x * teil.scale.x)
	if breite > 0.001:
		maske.scale = Vector3.ONE * (0.155 / breite)
	maske.position = Vector3(0.0, -0.026, 0.10)
