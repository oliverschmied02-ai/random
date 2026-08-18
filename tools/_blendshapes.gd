# Werkzeug: listet die Blendshapes der Figurenmodelle.
extends SceneTree


func _init() -> void:
	call_deferred("_los")


func _los() -> void:
	for pfad in ["res://actors/models/anne.glb", "res://actors/models/oliver.glb"]:
		var szene: Node = (load(pfad) as PackedScene).instantiate()
		print("== ", pfad)
		for kind in szene.find_children("*", "MeshInstance3D", true, false):
			var mi := kind as MeshInstance3D
			if mi.mesh == null:
				continue
			var netz := mi.mesh as ArrayMesh
			if netz == null:
				continue
			var anzahl: int = netz.get_blend_shape_count()
			if anzahl > 0:
				var namen: PackedStringArray = []
				for i in anzahl:
					namen.append(String(netz.get_blend_shape_name(i)))
				print("  ", mi.name, ": ", ", ".join(namen))
		szene.free()
	quit(0)
