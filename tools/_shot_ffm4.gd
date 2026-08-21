# Werkzeug: stellt die Sieg-Einstellung von Kapitel 2 direkt und knipst sie.
# Lädt die Szene ohne Kapitelskript — nichts läuft ab, alles wird gestellt.
extends SceneTree


func _init() -> void:
	call_deferred("_los")


func _los() -> void:
	var szene := (load("res://chapters/frankfurt/frankfurt_chapter.tscn")
		as PackedScene).instantiate()
	szene.set_script(null)
	root.add_child(szene)
	await physics_frame

	var spieler: Node3D = szene.get_node("Player")
	var oliver: Node3D = szene.get_node("Oliver")
	if oliver.has_method("hold"):
		oliver.hold()
	spieler.set("input_enabled", false)
	spieler.global_position = Vector3(399.2, 0.3, -98.4)
	spieler.rotation.y = -PI / 2.0
	oliver.global_position = Vector3(401.6, 0.25, -98.4)
	oliver.rotation.y = PI / 2.0

	var kamera: Camera3D = szene.get_node("Filmkamera")
	kamera.global_position = Vector3(400.4, 1.75, -95.6)
	kamera.look_at(Vector3(400.4, 1.25, -98.4))
	kamera.current = true

	var dialog = szene.get_node("UI/DialogueBox")
	dialog.play(FrankfurtDialogue.GEWONNEN)

	var uhr := create_timer(1.2)
	while uhr.time_left > 0.0:
		await process_frame
	await process_frame
	var bild := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://shots")
	bild.save_png("user://shots/ffm_gewonnen.png")
	print("Schuss: ffm_gewonnen")
	quit(0)
