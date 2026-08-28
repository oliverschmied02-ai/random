# Werkzeug: rendert den Titelbildschirm — gesperrt und freigeschaltet.
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
	var titel := (load("res://ui/title_screen.tscn") as PackedScene).instantiate()
	root.add_child(titel)
	await create_timer(2.0).timeout
	await _schuss("titel_gesperrt")
	var stand := root.get_node_or_null("/root/Spielstand")
	print("Spielstand-Autoload vorhanden: ", stand != null)
	if stand != null:
		stand.erreicht = 3
	titel._kapitelwahl_bauen()
	await create_timer(0.3).timeout
	await _schuss("titel_frei")
	quit(0)
