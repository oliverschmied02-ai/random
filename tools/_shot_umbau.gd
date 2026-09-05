# Werkzeug: rendert den Kapitel-3-Umbau — Spreespeicher hinter dem Rasen,
# rosa Läufer mit Kerzenlaternen, und die gestellte Rede-Szene (Bank,
# sitzendes Paar, Redner). Nur für die Entwicklung.
extends SceneTree


func _schuss(name: String) -> void:
	await process_frame
	await process_frame
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/%s.png" % name)
	print("Schuss: ", name)


func _init() -> void:
	call_deferred("_los")


func _los() -> void:
	var szene := (load("res://chapters/hochzeit/hochzeit_chapter.tscn")
		as PackedScene).instantiate()
	szene.set_script(null)
	root.add_child(szene)
	await physics_frame
	var spieler: Node3D = szene.get_node("Player")
	spieler.set("input_enabled", false)
	var oliver: Node3D = szene.get_node("Oliver")
	if oliver.has_method("hold"):
		oliver.hold()
	var kamera: Camera3D = szene.get_node("Filmkamera")
	kamera.current = true
	await create_timer(1.2).timeout

	spieler.global_position = Vector3(6.0, 0.3, 20.0)
	oliver.global_position = Vector3(7.0, 0.25, 20.0)

	# 1. Vom Bogen landwärts: Stuhlreihen, Rasen, dahinter der Speicher.
	kamera.global_position = Vector3(0.0, 2.2, 0.5)
	kamera.look_at(Vector3(0.0, 6.0, 40.0))
	await _schuss("umbau_speicher_total")

	# 2. Schräg über das Fest: Läufer, Laternen, Speicher rechts.
	kamera.global_position = Vector3(-10.0, 1.6, 2.0)
	kamera.look_at(Vector3(6.0, 4.0, 30.0))
	await _schuss("umbau_fest_schraeg")

	# 3. Nah am Läufer: rosa Teppich, Kerzenlaternen, Bogen.
	kamera.global_position = Vector3(1.8, 1.1, 10.5)
	kamera.look_at(Vector3(-0.3, 0.5, 3.5))
	await _schuss("umbau_laeufer")

	# 4. Rede-Staging: Bank, sitzendes Paar, Redner — wie _rede_sequenz.
	var bank := (load("res://assets/props/bank.glb") as PackedScene).instantiate() as Node3D
	szene.add_child(bank)
	bank.position = Vector3(0.0, 0.06, 5.1)
	bank.rotation.y = PI

	spieler.global_position = Vector3(-0.38, 0.3, 5.0)
	spieler.rotation.y = PI
	oliver.global_position = Vector3(0.42, 0.25, 5.0)
	oliver.rotation.y = PI
	await physics_frame
	var figur_anne: Figur = spieler.get_node("Visual")
	var figur_oliver: Figur = oliver.get_node("Visual")
	# Kleid wie im Kapitel, damit das Sitzen im Rock beurteilbar ist.
	var skelett := figur_anne.skelett_finden()
	var kleid := (load("res://assets/hochzeit/kleid.glb") as PackedScene).instantiate()
	for kind in kleid.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		teil.get_parent().remove_child(teil)
		skelett.add_child(teil)
	kleid.queue_free()
	figur_anne.set_physics_process(false)
	figur_oliver.set_physics_process(false)
	for figur: Figur in [figur_anne, figur_oliver]:
		var sk := figur.skelett_finden()
		for seite in ["Left", "Right"]:
			var schenkel := sk.find_bone("%sUpLeg" % seite)
			var schienbein := sk.find_bone("%sLeg" % seite)
			var lage := sk.get_bone_global_pose(schenkel)
			sk.set_bone_global_pose(schenkel, Transform3D(
				Basis(Vector3.RIGHT, -PI * 0.46) * lage.basis, lage.origin))
			lage = sk.get_bone_global_pose(schienbein)
			sk.set_bone_global_pose(schienbein, Transform3D(
				Basis(Vector3.RIGHT, PI * 0.44) * lage.basis, lage.origin))
		var huefte := sk.find_bone("Hips")
		var hueft_welt := (sk.global_transform
			* sk.get_bone_global_pose(huefte).origin).y - figur.global_position.y
		figur.position.y -= hueft_welt - 0.47 - 0.05

	var redner := Hochzeitsgast.new()
	redner.modell_pfad = "res://actors/models/gast_7.glb"
	redner.zielhoehe = 1.84
	redner.mocap_aktiv = false
	redner.gangwerk_aktiv = false
	redner.position = Vector3(1.1, 0.0, 2.4)
	redner.rotation.y = atan2(-0.38 - 1.1, 5.0 - 2.4) + PI
	szene.add_child(redner)
	await create_timer(0.6).timeout

	kamera.global_position = Vector3(-2.6, 1.7, 8.8)
	kamera.look_at(Vector3(0.7, 1.15, 2.4))
	await _schuss("umbau_rede_hinten")

	kamera.global_position = Vector3(3.4, 1.5, 0.8)
	kamera.look_at(Vector3(-0.5, 0.95, 5.6))
	await _schuss("umbau_rede_vorn")
	quit(0)
