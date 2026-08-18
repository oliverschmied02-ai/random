extends Figur
## Der Mann hinter dem Dönertresen.
##
## Kein eigenes Modell: dieselbe `.glb` wie Oliver, nur verkleidet — dunkler
## getöntes Haar, weiße Schürze, Papiermütze. Aus Spielentfernung, hinter dem
## Tresen und im warmen Budenlicht, steht damit ein anderer Mensch da.
##
## Die Mütze hängt am Kopfknochen (`BoneAttachment3D`), damit sie mitdreht,
## wenn er jemanden ansieht. Die Schürze hängt starr an der Figur — der Rumpf
## bewegt sich im Stand kaum, dafür lohnt kein Knochen.

## Wen er ansieht, sobald sie nah genug am Tresen ist.
@export var spieler_pfad: NodePath
## Ab welchem Abstand er von seiner Arbeit aufsieht (Meter).
@export_range(2.0, 15.0, 0.5) var aufmerksamkeit: float = 7.0

var _spieler: Node3D
var _stoff: StandardMaterial3D


func _ready() -> void:
	super()
	_spieler = get_node_or_null(spieler_pfad)
	if modell == null:
		return
	_stoff = StandardMaterial3D.new()
	_stoff.albedo_color = Color(0.93, 0.92, 0.88)
	_stoff.roughness = 0.85
	_haar_faerben()
	_schuerze_umbinden()
	_muetze_aufsetzen()


func _physics_process(delta: float) -> void:
	super(delta)
	if _spieler == null:
		return
	var nah := global_position.distance_to(_spieler.global_position) < aufmerksamkeit
	schaue_an(_spieler if nah else null)


## Tönt das Haar dunkel. Nur als Überschreibung an diesem einen Exemplar —
## dieselben Materialien hängen auch an Olivers Figur im Kapitel.
func _haar_faerben() -> void:
	for kind in modell.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		if teil == null or teil.mesh == null:
			continue
		for s in teil.mesh.get_surface_count():
			var material := teil.get_active_material(s) as BaseMaterial3D
			if material == null:
				continue
			var name := String(teil.name).to_lower() + "|" + material.resource_name.to_lower()
			if not ("hair" in name or "haar" in name):
				continue
			var kopie := material.duplicate() as BaseMaterial3D
			kopie.albedo_color = Color(0.4, 0.29, 0.21)
			teil.set_surface_override_material(s, kopie)


func _schuerze_umbinden() -> void:
	# Dicht am Körper — ein Fingerbreit Abstand, sonst schwebt der Stoff.
	_klotz(Vector3(0.0, 1.24, -0.1), Vector3(0.28, 0.32, 0.025))    # Latz
	_klotz(Vector3(0.0, 0.82, -0.13), Vector3(0.38, 0.5, 0.03))     # Schurz
	_klotz(Vector3(0.0, 1.06, -0.12), Vector3(0.42, 0.03, 0.028))   # Bindeband


func _klotz(mitte: Vector3, masse: Vector3) -> void:
	var teil := MeshInstance3D.new()
	var form := BoxMesh.new()
	form.size = masse
	form.material = _stoff
	teil.mesh = form
	teil.position = mitte
	add_child(teil)


func _muetze_aufsetzen() -> void:
	var skelett := skelett_finden()
	if skelett == null or skelett.find_bone("Head") < 0:
		return
	var halter := BoneAttachment3D.new()
	skelett.add_child(halter)
	halter.bone_name = "Head"
	var kappe := MeshInstance3D.new()
	var form := CylinderMesh.new()
	form.top_radius = 0.1
	form.bottom_radius = 0.09
	form.height = 0.13
	form.material = _stoff
	kappe.mesh = form
	kappe.position = Vector3(0.0, 0.16, 0.01)
	halter.add_child(kappe)
