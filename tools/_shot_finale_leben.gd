# Werkzeug: rendert das lebendige Hochzeitsfinale — Wind im Tüll,
# Blütenkonfetti, hüpfende Gäste. Die Effekte werden hier direkt
# ausgelöst (das Kapitel-Skript ist abgeklemmt), mit denselben
# Parametern wie in chapter_hochzeit.gd.
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


func _windstoff(oben: float, unten: float, staerke: float) -> ShaderMaterial:
	var wind := Shader.new()
	wind.code = """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform vec4 farbe : source_color = vec4(1.0, 1.0, 1.0, 0.30);
uniform float staerke = 0.03;
uniform float oben = 1.0;
uniform float unten = 0.1;
void vertex() {
	float saum = clamp((oben - VERTEX.y) / max(oben - unten, 0.001), 0.0, 1.0);
	float boee = sin(TIME * 1.7 + VERTEX.y * 4.0 + VERTEX.x * 2.3) * 0.6
		+ sin(TIME * 2.9 + VERTEX.z * 5.1) * 0.4;
	VERTEX.x += boee * staerke * saum;
	VERTEX.z += cos(TIME * 1.3 + VERTEX.y * 3.2) * staerke * 0.6 * saum;
}
void fragment() {
	ALBEDO = farbe.rgb;
	ALPHA = farbe.a;
	ROUGHNESS = 0.9;
}
"""
	var stoff := ShaderMaterial.new()
	stoff.shader = wind
	stoff.set_shader_parameter("oben", oben)
	stoff.set_shader_parameter("unten", unten)
	stoff.set_shader_parameter("staerke", staerke)
	return stoff


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
	await create_timer(1.0).timeout

	# Kleid samt Wind-Shader — wie chapter_hochzeit._kleid_anziehen.
	var figur: Figur = spieler.get_node("Visual")
	var skelett := figur.skelett_finden()
	var kleid := (load("res://assets/hochzeit/kleid.glb") as PackedScene).instantiate()
	for kind in kleid.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		teil.get_parent().remove_child(teil)
		skelett.add_child(teil)
		if teil.name == "kleid_tuell":
			teil.material_override = _windstoff(0.95, 0.10, 0.030)
		elif teil.name == "kleid_schleier":
			teil.material_override = _windstoff(1.55, 0.95, 0.022)
	kleid.queue_free()

	spieler.global_position = Vector3(0.0, 0.3, 5.5)
	spieler.rotation.y = 0.0
	oliver.global_position = Vector3(1.4, 0.25, 3.2)
	oliver.rotation.y = -0.5
	await create_timer(0.5).timeout

	# 1. Das Kleid im Wind — Nahaufnahme, der Shader verschiebt die Säume.
	kamera.global_position = Vector3(1.8, 1.2, 7.4)
	kamera.look_at(Vector3(0.0, 0.9, 5.5))
	await _schuss("leben_kleid_wind")

	# 2. Konfetti + hüpfende Gäste — wie _konfetti_werfen/_gaeste_jubeln.
	var kulisse: Node3D = szene.get_node("Kulisse")
	for ort: Vector3 in [Vector3(-4.5, 2.4, 8.2), Vector3(0.0, 2.7, 9.0),
			Vector3(4.5, 2.4, 8.2)]:
		var salve := CPUParticles3D.new()
		salve.one_shot = true
		salve.amount = 70
		salve.lifetime = 3.4
		salve.explosiveness = 0.92
		salve.direction = Vector3.UP
		salve.spread = 40.0
		salve.initial_velocity_min = 1.4
		salve.initial_velocity_max = 2.8
		salve.gravity = Vector3(0.0, -1.4, 0.0)
		salve.angular_velocity_min = -220.0
		salve.angular_velocity_max = 220.0
		var verlauf := Gradient.new()
		verlauf.set_color(0, Color(1.0, 0.72, 0.80))
		verlauf.set_color(1, Color(1.0, 0.98, 0.94))
		salve.color_ramp = verlauf
		var blatt := QuadMesh.new()
		blatt.size = Vector2(0.06, 0.06)
		var stoff := StandardMaterial3D.new()
		stoff.albedo_color = Color(1.0, 0.62, 0.72)
		stoff.vertex_color_use_as_albedo = true
		stoff.roughness = 1.0
		stoff.cull_mode = BaseMaterial3D.CULL_DISABLED
		stoff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		blatt.material = stoff
		salve.mesh = blatt
		szene.add_child(salve)
		salve.global_position = ort
		salve.emitting = true

	var rng := RandomNumberGenerator.new()
	rng.seed = 92023
	var gaeste: Array[Node3D] = kulisse.gaeste
	var springer := 0
	for gast in gaeste:
		if gast.get("sitzend"):
			continue
		if rng.randf() < 0.3:
			continue
		springer += 1
		var boden: float = gast.position.y
		var hop := root.create_tween()
		hop.tween_interval(rng.randf_range(0.0, 0.2))
		for i in 6:
			hop.tween_property(gast, ^"position:y", boden + 0.18, 0.34)
			hop.tween_property(gast, ^"position:y", boden, 0.34)
	print("Springende Gaeste: ", springer)

	# Mitten in der Salve und im Sprung.
	await create_timer(0.65).timeout
	kamera.global_position = Vector3(0.0, 2.2, 14.5)
	kamera.look_at(Vector3(0.0, 1.6, 8.0))
	await _schuss("leben_konfetti_gaeste")

	await create_timer(0.8).timeout
	kamera.global_position = Vector3(-6.0, 1.6, 13.0)
	kamera.look_at(Vector3(-2.0, 1.7, 9.0))
	await _schuss("leben_konfetti_seite")
	quit(0)
