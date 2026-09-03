extends SceneTree
func _init() -> void:
	call_deferred("_los")
func _los() -> void:
	var szene: Node = load("res://chapters/hochzeit/hochzeit_chapter.tscn").instantiate()
	szene.set_script(null)
	root.add_child(szene)
	await physics_frame
	var spieler: Node3D = szene.get_node("Player")
	spieler.set("input_enabled", false)

	# 1. Mocap-Hüfte: Figur von Hand vorwärts schieben, Hüft-Y beobachten.
	var figur: Figur = spieler.get_node("Visual")
	var skelett := figur.skelett_finden()
	var hips := skelett.find_bone("Hips")
	var y_min := 99.0
	var y_max := -99.0
	var x_min := 99.0
	var x_max := -99.0
	for i in 90:
		spieler.global_position += Vector3(0, 0, -0.055)
		await physics_frame
		if i < 25:
			continue  # Intensität erst hochlaufen lassen
		var lage := skelett.get_bone_pose_position(hips)
		y_min = minf(y_min, lage.y); y_max = maxf(y_max, lage.y)
		x_min = minf(x_min, lage.x); x_max = maxf(x_max, lage.x)
	print("Hueft-Wippen: %.1f mm, seitlich: %.1f mm" %
		[(y_max - y_min) * 1000.0, (x_max - x_min) * 1000.0])

	# 2. Gäste-Idle: Kopf-Gier eines stehenden Gastes über 3 s beobachten.
	var kulisse: Node3D = szene.get_node("Kulisse")
	var gast: Node3D = null
	for g in kulisse.gaeste:
		if not g.get("sitzend"):
			gast = g
			break
	var gs: Skeleton3D = gast.skelett_finden()
	var kopf := gs.find_bone("Head")
	var g0: Basis = gs.get_bone_global_pose(kopf).basis
	await create_timer(3.0).timeout
	var g1: Basis = gs.get_bone_global_pose(kopf).basis
	var delta := (g0.inverse() * g1).get_euler()
	print("Gast-Kopf nach 3 s: Gier %.2f Grad, Nick %.2f Grad" %
		[rad_to_deg(delta.y), rad_to_deg(delta.x)])
	quit(0)
