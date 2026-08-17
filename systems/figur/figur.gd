class_name Figur
extends Node3D

## Das sichtbare Modell einer Person — mit Kapsel als Rückfallebene.
##
## Solange kein Modell vorliegt, bleibt der Platzhalter stehen. Liegt eines
## vor, wird es geladen, auf die richtige Höhe skaliert und der Platzhalter
## verschwindet. Das Spiel läuft in beiden Fällen unverändert: Bewegung,
## Kollision und Kamera hängen an der Figur selbst, nie an ihrem Aussehen.
##
## Der Weg für ein neues Modell ist damit: Datei nach `actors/models/` legen,
## `modell_pfad` eintragen, fertig. Kein Code, keine Szene umbauen.
##
## **Maßstab.** Modelle kommen in unterschiedlichen Größen aus den Werkzeugen,
## und ein Mensch, der einen Kopf zu groß ist, fällt sofort auf. Deshalb wird
## nicht auf gut Glück skaliert, sondern gemessen: aus den Ausmaßen aller
## sichtbaren Teile ergibt sich die tatsächliche Höhe, daraus der Faktor auf
## `zielhoehe`. Wer die Skalierung von Hand setzen will, stellt `zielhoehe`
## auf 0.
##
## **Blickrichtung.** glTF-Figuren schauen üblicherweise nach +Z, in Godot ist
## vorne −Z. Ein Modell, das rückwärts läuft, ist fast immer genau das.

## Ressource mit dem Modell — eine importierte `.glb` oder eine `.tscn`.
## Leer oder nicht vorhanden heißt: Platzhalter behalten.
@export var modell_pfad: String = ""
## Höhe der fertigen Figur in Metern, Sohle bis Scheitel. 0 = nicht skalieren.
@export_range(0.0, 2.5, 0.01) var zielhoehe: float = 1.75
## Modell um 180° drehen, weil glTF-Figuren nach +Z schauen.
@export var blickrichtung_drehen: bool = true
## Was ausgeblendet wird, sobald ein Modell steht.
@export var platzhalter_pfad: NodePath = ^"Platzhalter"

## Das geladene Modell, oder null solange die Kapsel steht.
var modell: Node3D


func _ready() -> void:
	if modell_pfad.is_empty() or not ResourceLoader.exists(modell_pfad):
		return

	var geladen := load(modell_pfad)
	var szene := geladen as PackedScene
	if szene == null:
		push_warning("Figur: '%s' ist keine Szene." % modell_pfad)
		return

	modell = szene.instantiate() as Node3D
	if modell == null:
		push_warning("Figur: '%s' enthält keinen 3D-Knoten." % modell_pfad)
		return

	add_child(modell)
	if blickrichtung_drehen:
		modell.rotate_y(PI)
	_auf_hoehe_bringen()

	var platzhalter := get_node_or_null(platzhalter_pfad) as Node3D
	if platzhalter != null:
		platzhalter.visible = false


## Skaliert das Modell so, dass es `zielhoehe` misst.
func _auf_hoehe_bringen() -> void:
	if zielhoehe <= 0.0:
		return
	var hoehe := gemessene_hoehe()
	if hoehe < 0.01:
		push_warning("Figur: Modell '%s' hat keine messbare Höhe." % modell_pfad)
		return
	modell.scale *= zielhoehe / hoehe


## Höhe des geladenen Modells in Metern, aus den Ausmaßen aller sichtbaren
## Teile. 0, wenn nichts Sichtbares da ist.
func gemessene_hoehe() -> float:
	if modell == null:
		return 0.0
	var kasten := _ausmasse(modell)
	return kasten.size.y if kasten.has_volume() else 0.0


## Sammelt die Ausmaße aller sichtbaren Teile, im Raum der Figur.
func _ausmasse(knoten: Node) -> AABB:
	var gesamt := AABB()
	var erster := true

	for kind in knoten.get_children():
		var teil := _ausmasse(kind)
		if not teil.has_volume():
			continue
		gesamt = teil if erster else gesamt.merge(teil)
		erster = false

	var sichtbar := knoten as VisualInstance3D
	if sichtbar != null:
		# `get_aabb()` liefert lokale Maße — erst im Raum der Figur sind sie
		# vergleichbar, sonst zählt eine gedrehte Hand als Körpergröße.
		var eigen := (global_transform.affine_inverse() * sichtbar.global_transform) \
			* sichtbar.get_aabb()
		gesamt = eigen if erster else gesamt.merge(eigen)

	return gesamt
