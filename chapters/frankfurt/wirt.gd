class_name Wirt
extends Figur

## Der Wirt hinter dem Schanktresen der Apfelweinkneipe.
##
## Dasselbe Verfahren wie beim Dönermann in Kapitel 1 (`verkaeufer.gd`):
## kein eigenes Modell, sondern Olivers `.glb`, verkleidet — dunkleres
## Haar, blaue Schürze, ein Handtuch über der Schulter. Er steht hinter
## dem Tresen, im Halbdunkel der Stube, und sieht auf, wenn jemand
## nah genug ist. Aus der Wurfposition ist er sieben Meter weg; dort
## liest man Schürze und Haltung, nicht das Gesicht.
##
## Das Handtuch hängt am Schulterknochen, damit es mitgeht, wenn er den
## Kopf dreht — ein starr angeklebtes Tuch verrät die Puppe sofort.

## Wen er ansieht, sobald jemand nah genug am Tresen steht.
@export var blickziel_pfad: NodePath
## Ab welchem Abstand er von seiner Arbeit aufsieht (Meter).
@export_range(2.0, 20.0, 0.5) var aufmerksamkeit: float = 9.0

var _blickziel: Node3D
var _schuerzenstoff: StandardMaterial3D
var _tuchstoff: StandardMaterial3D


func _ready() -> void:
	super()
	_blickziel = get_node_or_null(blickziel_pfad) as Node3D
	if modell == null:
		return
	_schuerzenstoff = StandardMaterial3D.new()
	_schuerzenstoff.albedo_color = Color(0.18, 0.24, 0.38)
	_schuerzenstoff.roughness = 0.9
	_tuchstoff = StandardMaterial3D.new()
	_tuchstoff.albedo_color = Color(0.84, 0.82, 0.74)
	_tuchstoff.roughness = 0.95
	_haar_faerben()
	_schuerze_umbinden()
	_handtuch_auflegen()


func _physics_process(delta: float) -> void:
	super(delta)
	if _blickziel == null:
		return
	var nah := global_position.distance_to(_blickziel.global_position) < aufmerksamkeit
	schaue_an(_blickziel if nah else null)


func _haar_faerben() -> void:
	for kind in modell.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		if teil == null or teil.mesh == null:
			continue
		for s in teil.mesh.get_surface_count():
			var material := teil.get_active_material(s) as BaseMaterial3D
			if material == null:
				continue
			var kennung := String(teil.name).to_lower() + "|" \
				+ material.resource_name.to_lower()
			if not ("haircut" in kennung or "haar" in kennung):
				continue
			var kopie := material.duplicate() as BaseMaterial3D
			kopie.albedo_color = Color(0.22, 0.16, 0.12)
			teil.set_surface_override_material(s, kopie)


func _schuerze_umbinden() -> void:
	# Ein Stück, von der Brust bis unters Knie. Drei getrennte Platten
	# lasen sich als Klemmbrett vor dem Bauch, nicht als Schürze.
	_klotz(Vector3(0.0, 0.92, -0.155), Vector3(0.44, 0.96, 0.03),
		_schuerzenstoff)
	_klotz(Vector3(0.0, 1.06, -0.15), Vector3(0.46, 0.04, 0.028),
		_schuerzenstoff)


func _klotz(mitte: Vector3, masse: Vector3, stoff: Material) -> void:
	var teil := MeshInstance3D.new()
	var form := BoxMesh.new()
	form.size = masse
	form.material = stoff
	teil.mesh = form
	teil.position = mitte
	add_child(teil)


func _handtuch_auflegen() -> void:
	var skelett := skelett_finden()
	if skelett == null:
		return
	# Mixamo-Schema; fällt der Knochen weg, bleibt das Tuch einfach aus.
	var knochen := "LeftShoulder"
	if skelett.find_bone(knochen) < 0:
		knochen = "LeftArm"
	if skelett.find_bone(knochen) < 0:
		return
	var halter := BoneAttachment3D.new()
	skelett.add_child(halter)
	halter.bone_name = knochen
	var tuch := MeshInstance3D.new()
	var form := BoxMesh.new()
	form.size = Vector3(0.12, 0.26, 0.04)
	form.material = _tuchstoff
	tuch.mesh = form
	tuch.position = Vector3(0.0, -0.05, 0.0)
	tuch.rotation_degrees = Vector3(0.0, 0.0, 12.0)
	halter.add_child(tuch)
