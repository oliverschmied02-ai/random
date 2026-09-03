extends SceneTree
func _init() -> void:
	call_deferred("_los")
func _los() -> void:
	var szene: Node = load("res://chapters/berlin/berlin_chapter.tscn").instantiate()
	szene.set_script(null)
	root.add_child(szene)
	await physics_frame
	for kind in root.find_children("*", "Node3D", true, false):
		var knoten := kind as Node3D
		if knoten.scene_file_path != null and knoten.scene_file_path.contains("fahrrad"):
			var hoch: Vector3 = knoten.global_transform.basis.y.normalized()
			print("Rad ", knoten.global_position, " Wrapper-Neigung ",
				snappedf(rad_to_deg(hoch.angle_to(Vector3.UP)), 0.1))
			for teil in knoten.find_children("*", "MeshInstance3D", true, false):
				var m := teil as MeshInstance3D
				var mhoch: Vector3 = m.global_transform.basis.y.normalized()
				print("   Netz ", m.name, " Neigung ",
					snappedf(rad_to_deg(mhoch.angle_to(Vector3.UP)), 0.1),
					" aabb ", m.get_aabb().size)
	quit(0)
