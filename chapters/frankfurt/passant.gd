class_name Passant
extends Figur

## Ein Mensch in der Gasse, der nicht Anne und nicht Oliver ist.
##
## Es gibt kein drittes Personenmodell und in dieser Arbeitsumgebung keinen
## Weg, eins zu besorgen (siehe `actors/models/README.md`). Ein Passant ist
## deshalb dasselbe `.glb` wie Anne oder Oliver — **umgefärbt und anders
## skaliert**. Das trägt, solange drei Regeln eingehalten werden:
##
##   1. Abstand. Aus 15 m und mehr liest das Auge Silhouette, Haltung und
##      Farbe — nicht das Gesicht. Passanten gehören an den Rand der Gasse,
##      nie in eine Nahaufnahme.
##   2. Körpergröße streuen. Zwei gleich große Menschen in einem Bild sind
##      derselbe Mensch, egal welche Jacke sie tragen.
##   3. Kleidung *und* Haar färben. Nur die Jacke zu tauschen reicht nicht,
##      der Kopf verrät die Kopie.
##
## Bewegung kommt gratis: `Figur` hängt die echte Mocap-Aufnahme
## „auf den Bus warten" an — Gewicht verlagern, umschauen, atmen. Ein
## Passant, der wie eine Statue steht, wäre schlimmer als keiner.

## Farbe für Oberteil/Jacke des Modells.
@export var kleidung: Color = Color(0.28, 0.30, 0.36)
## Farbe für das Haar.
@export var haar: Color = Color(0.24, 0.18, 0.13)
## Wen der Passant beiläufig ansieht (leer: niemanden).
@export var blickziel_pfad: NodePath
## Ab welchem Abstand er herschaut (Meter).
@export_range(0.0, 20.0, 0.5) var aufmerksamkeit: float = 6.0

var _blickziel: Node3D


func _ready() -> void:
	super()
	_blickziel = get_node_or_null(blickziel_pfad) as Node3D
	if modell == null:
		return
	_umfaerben()


func _physics_process(delta: float) -> void:
	super(delta)
	if _blickziel == null:
		return
	var nah := global_position.distance_to(_blickziel.global_position) < aufmerksamkeit
	schaue_an(_blickziel if nah else null)


## Färbt Haar und Kleidung um. Die Materialien der `.glb` hängen an allen
## Exemplaren desselben Modells — deshalb wird je Fläche eine Kopie gesetzt
## und nie das Original verändert, sonst färbt sich Anne im Kapitel mit.
func _umfaerben() -> void:
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
			# Die Modelle nennen ihre Flächen `haircut`, `outfit` und
			# `AvatarBody` — Letzteres ist die Haut. Nur exakt zugeordnet
			# färben: ein Stichwort wie „body" trifft sonst den Körper und
			# der Passant bekommt eine jeansfarbene Haut.
			var ton := Color.TRANSPARENT
			if "haircut" in kennung or "haar" in kennung:
				ton = haar
			elif "outfit" in kennung:
				ton = kleidung
			if ton == Color.TRANSPARENT:
				continue
			var kopie := material.duplicate() as BaseMaterial3D
			kopie.albedo_color = ton
			teil.set_surface_override_material(s, kopie)
