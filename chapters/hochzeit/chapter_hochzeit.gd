class_name HochzeitChapter
extends Node3D

## Kapitel 3 — die Hochzeit an der Spree. Das **Finale** des Spiels.
##
## Ablauf:
##
##   Kapitelkarte → kurzer Dialog am Traubogen → spielbarer Weg zu den
##   Gästen → Regeln → Brautstrauß-Fangen (10 fliegen, 5 fangen) →
##   Sieg-Dialog → **Truhen-Finale** (Zahlenpad, Code 42, der Rucksack
##   schwebt heraus) → **Geschenkbildschirm** → Abspann → Titel.
##
## Der Geschenkbildschirm löst ein, was die Widmung am Anfang verspricht.
## Die Texte dazu stehen in `dialogue_lines_hochzeit.gd` und sind bewusst
## als Platzhalter markiert — sie gehören Oliver, nicht dem Code.

signal kapitel_abgeschlossen

## Für Prüfläufe: rafft alle Warte- und Blendzeiten.
@export var test_schnell: bool = false
## Für Prüfläufe: bleibt nach dem Abspann in der Szene.
@export var weiter_nach_abspann: bool = true

const _START_ANNE := Vector3(-6.5, 0.3, 16.0)
const _START_OLIVER := Vector3(-5.0, 0.25, 16.8)
## Wo Anne beim Fangen steht (die Spielkamera schaut über ihre Schulter).
const _SPIEL_ANNE := Vector3(0.0, 0.3, 9.0)
const _SPIEL_OLIVER := Vector3(3.6, 0.25, 2.6)
## Das Schlussbild: die beiden am Wasser, die Brücke hinter ihnen.
const _SCHLUSS_ANNE := Vector3(-0.9, 0.3, 1.5)
const _SCHLUSS_OLIVER := Vector3(0.9, 0.25, 1.5)

@onready var _player: Player = $Player
@onready var _oliver: Companion = $Oliver
@onready var _kamera_rig: Node3D = $ThirdPersonCamera
@onready var _filmkamera: Camera3D = $Filmkamera
@onready var _dialogue: DialogueBox = $UI/DialogueBox
@onready var _objective = $UI/ObjectiveLabel
@onready var _karte = $UI/ChapterCard
@onready var _strauss: StraussSpiel = $StraussSpiel
@onready var _kulisse: Node3D = $Kulisse
@onready var _menge: AudioStreamPlayer = $Klang/Menge
@onready var _jubel: AudioStreamPlayer = $Klang/Jubel

## Die Kapitelmusik (Kanon in D), wird im Finale abgelöst.
var _musik: AudioStreamPlayer

var _bogen_erreicht := false
var _blendschicht: CanvasLayer
var _blende: ColorRect
## Das Truhen-Finale — entsteht erst nach dem Sieg; für Prüfläufe lesbar.
var truhe: TruhenFinale


const _KLEID := preload("res://assets/hochzeit/kleid.glb")
const _STRAUSS := preload("res://assets/props/strauss.glb")


func _ready() -> void:
	_player.input_enabled = false
	_kleid_anziehen()
	_blendschicht_bauen()
	# Die Spree unterm Fest: Wellen und Möwen als leiser Loop neben der
	# Menge (synthetisiert, tools/make_ambience.py).
	var wasser := AudioStreamPlayer.new()
	wasser.stream = load("res://audio/wellen_moewen.wav")
	wasser.volume_db = -14.0
	add_child(wasser)
	wasser.play()
	# Kapitelmusik: der Kanon in D (Klavier, CC0) — DAS Hochzeitsstück.
	_musik = AudioStreamPlayer.new()
	_musik.stream = load("res://audio/musik/hochzeit.ogg")
	_musik.volume_db = -13.0
	_musik.bus = &"Musik" if AudioServer.get_bus_index("Musik") >= 0 else &"Master"
	add_child(_musik)
	_musik.play()
	var zone := $Triggers/BogenZone as Area3D
	zone.body_entered.connect(func(koerper: Node3D) -> void:
		if koerper == _player:
			_bogen_erreicht = true)
	_ablauf.call_deferred()


func _wartezeit(sekunden: float) -> float:
	return 0.05 if test_schnell else sekunden


# --- Der rote Faden -----------------------------------------------------------


func _ablauf() -> void:
	# 1. Nach der Trauung: die beiden abseits, die Gäste am Bogen.
	_player.global_position = _START_ANNE
	_player.rotation.y = 2.5
	_oliver.hold()
	_oliver.global_position = _START_OLIVER
	_oliver.rotation.y = -0.7
	_film(Vector3(-9.6, 1.75, 18.4), Vector3(-5.4, 1.35, 16.2))
	_menge.play()
	await _karte.auftakt(HochzeitDialogue.KARTE_TITEL,
		HochzeitDialogue.KARTE_ZEILE)
	await _dialogue.play(HochzeitDialogue.AUFTAKT)

	# 2. Spielbarer Weg zum Traubogen.
	(_kamera_rig.get_node("SpringArm3D/Camera3D") as Camera3D).current = true
	_player.input_enabled = true
	_oliver.activate()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_objective.show_objective(HochzeitDialogue.ZIEL_BOGEN)
	while not _bogen_erreicht:
		await get_tree().process_frame
	_player.input_enabled = false
	_oliver.hold()
	_objective.clear()

	# 3. Die Regeln, dann das Spiel.
	_player.global_position = _SPIEL_ANNE
	_player.rotation.y = PI
	_oliver.global_position = _SPIEL_OLIVER
	_oliver.rotation.y = 0.35
	_film(Vector3(2.6, 1.7, 6.4), Vector3(0.4, 1.4, 8.6))
	await _dialogue.play(HochzeitDialogue.REGELN)
	_strauss.runde_geschafft.connect(_auf_runde_geschafft, CONNECT_ONE_SHOT)
	_strauss.starten()


func _auf_runde_geschafft() -> void:
	Spielstand.freischalten(3)
	_jubel.play()
	# Der Moment gehört gefeiert: Blütenkonfetti über den Gästen, und die
	# Stehenden hüpfen ein paar Sekunden mit.
	_konfetti_werfen()
	_gaeste_jubeln(4.0)
	await get_tree().create_timer(_wartezeit(2.6)).timeout
	_strauss.abschluss_uebernehmen()
	# Den gefangenen Strauß trägt sie ab jetzt in der rechten Hand —
	# durchs Schlussbild und bis zur Truhe.
	_strauss_in_die_hand()

	# 4. Schlussbild am Wasser: die beiden vor der Brücke.
	_player.global_position = _SCHLUSS_ANNE
	_player.rotation.y = PI * 0.92
	_oliver.global_position = _SCHLUSS_OLIVER
	_oliver.rotation.y = -PI * 0.92
	_film(Vector3(0.0, 1.90, 6.4), Vector3(0.0, 1.62, 1.5))
	await _dialogue.play(HochzeitDialogue.GEWONNEN)

	# 5. Das Truhen-Finale: der Code öffnet das eigentliche Geschenk.
	await _truhen_finale()

	# 6. Der Geschenktext, dann der Abspann.
	await _geschenk_zeigen()
	await _karte.abspann(HochzeitDialogue.ABSPANN_TITEL,
		HochzeitDialogue.ABSPANN_ZEILE)
	kapitel_abgeschlossen.emit()
	if weiter_nach_abspann:
		get_tree().change_scene_to_file("res://ui/title_screen.tscn")


## Das Finale: eine verschlossene Truhe erscheint auf dem roten Teppich,
## Anne läuft hin, das Zahlenpad übernimmt (zwei Stellen, Hinweis auf die
## 42), und nach dem Öffnen schwebt der Rucksack heraus. Erst danach
## kommt der Geschenktext.
func _truhen_finale() -> void:
	await _abblenden(0.8)
	truhe = TruhenFinale.new()
	truhe.ort = Vector3(0.0, 0.06, 5.2)
	add_child(truhe)

	# Oliver tritt beiseite und schaut zu; Anne startet ein Stück entfernt.
	_oliver.global_position = Vector3(2.6, 0.25, 2.2)
	_oliver.rotation.y = -0.6
	_player.global_position = Vector3(0.0, 0.3, 13.0)
	_player.rotation.y = PI
	(_kamera_rig.get_node("SpringArm3D/Camera3D") as Camera3D).current = true
	var auf := create_tween()
	auf.tween_property(_blende, ^"color:a", 0.0, _wartezeit(0.8))
	await auf.finished

	_player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_objective.show_objective(HochzeitDialogue.ZIEL_TRUHE)
	while not truhe.erreicht():
		await get_tree().process_frame
	_player.input_enabled = false
	_objective.clear()

	# Anne neben die Truhe, Kamera nah — dann übernimmt das Zahlenpad.
	_player.global_position = Vector3(0.9, 0.3, 6.9)
	_player.rotation.y = 2.6
	_film(Vector3(-1.4, 1.35, 7.6), Vector3(0.2, 0.5, 5.2))
	truhe.pad_zeigen()
	await truhe.geoeffnet
	# Musikwechsel zum Geschenk: der Kanon blendet aus, „Romantic
	# Inspiration" trägt Rucksack, Geschenktext und Abspann.
	var wechsel := create_tween()
	wechsel.tween_property(_musik, ^"volume_db", -50.0, 2.0)
	wechsel.tween_callback(func() -> void:
		_musik.stream = load("res://audio/musik/finale.ogg")
		_musik.volume_db = -12.0
		_musik.play())
	# Den schwebenden Rucksack einen Moment wirken lassen.
	await get_tree().create_timer(_wartezeit(3.2)).timeout


## Das Hochzeitskleid: Mieder, Rock und Taillenband aus `kleid.glb`
## (gebaut auf Annes eigenem Avatar, `tools/make_kleid.py`) werden an
## das Skelett ihrer geladenen Figur gehängt — gleiche Knochennamen,
## gleiche Bindposen, die Godot-Skins finden ihre Knochen über den
## Namen. Das Kleid liegt über dem Alltagsoutfit; sichtbar bleiben von
## ihm nur Arme, Schultern und die Schuhe unterm bodenlangen Rock.
func _kleid_anziehen() -> void:
	var figur := _player.get_node_or_null("Visual") as Figur
	if figur == null:
		return
	var skelett := figur.skelett_finden()
	if skelett == null:
		return
	var kleid := _KLEID.instantiate() as Node3D
	for kind in kleid.find_children("*", "MeshInstance3D", true, false):
		var teil := kind as MeshInstance3D
		teil.get_parent().remove_child(teil)
		skelett.add_child(teil)
		# Die leichten Lagen — Tüll-Überrock und Schleier — bekommen einen
		# Wind-Shader: unten stärker als oben, damit der Stoff lebt statt
		# wie gegossen zu stehen.
		if teil.name == "kleid_tuell":
			teil.material_override = _windstoff(0.95, 0.10, 0.030)
		elif teil.name == "kleid_schleier":
			teil.material_override = _windstoff(1.55, 0.95, 0.022)
	kleid.queue_free()


## Ein durchscheinender Stoff, den der Spree-Wind bewegt. `oben`/`unten`
## grenzen die Höhenspanne ein (Skelettraum), dazwischen wächst der
## Ausschlag zum Saum hin an.
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


## Blütenkonfetti beim gewonnenen Fangen: drei Salven über den Stuhlreihen,
## rosa und weiße Blättchen, die trudelnd zu Boden segeln.
func _konfetti_werfen() -> void:
	for ort in [Vector3(-4.5, 2.4, 8.2), Vector3(0.0, 2.7, 9.0),
			Vector3(4.5, 2.4, 8.2)]:
		var salve := CPUParticles3D.new()
		salve.one_shot = true
		salve.amount = 70
		salve.lifetime = 3.4
		salve.explosiveness = 0.92
		salve.direction = Vector3.UP
		# Eng gebündelt und nicht zu schnell — eine weite, schnelle Salve
		# las sich im Bild wie Schneetreiben über der ganzen Szene.
		salve.spread = 40.0
		salve.initial_velocity_min = 1.4
		salve.initial_velocity_max = 2.8
		salve.gravity = Vector3(0.0, -1.4, 0.0)
		salve.damping_min = 0.6
		salve.damping_max = 1.4
		salve.angular_velocity_min = -220.0
		salve.angular_velocity_max = 220.0
		salve.scale_amount_min = 0.7
		salve.scale_amount_max = 1.3
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
		salve.color_ramp = _konfetti_farben()
		add_child(salve)
		salve.global_position = ort
		salve.emitting = true
		# Räumt sich selbst weg, wenn alles gelandet ist.
		get_tree().create_timer(salve.lifetime + 1.0).timeout.connect(
			salve.queue_free)


func _konfetti_farben() -> Gradient:
	var verlauf := Gradient.new()
	verlauf.set_color(0, Color(1.0, 0.72, 0.80))
	verlauf.set_color(1, Color(1.0, 0.98, 0.94))
	return verlauf


## Die stehenden Gäste hüpfen ein paar Sekunden — jeder mit eigenem
## Rhythmus und Versatz, damit es nach Jubel aussieht, nicht nach Ballett.
func _gaeste_jubeln(dauer: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 92023
	var gaeste: Array[Node3D] = _kulisse.gaeste
	for gast in gaeste:
		if gast.get("sitzend"):
			continue
		# Nicht alle: gut zwei Drittel springen, der Rest freut sich still.
		if rng.randf() < 0.3:
			continue
		var boden := gast.position.y
		var hop := create_tween()
		hop.tween_interval(rng.randf_range(0.0, 0.5))
		var takt := rng.randf_range(0.30, 0.42)
		var hoehe := rng.randf_range(0.12, 0.22)
		var spruenge := int(dauer / (takt * 2.0))
		for i in spruenge:
			hop.tween_property(gast, ^"position:y", boden + hoehe, takt) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			hop.tween_property(gast, ^"position:y", boden, takt) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## Der gefangene Brautstrauß wandert in Annes rechte Hand — ein
## BoneAttachment am Handknochen, der Strauß leicht gekippt, damit die
## Blüten nach vorn-oben zeigen, während der Arm hängt.
func _strauss_in_die_hand() -> void:
	var figur := _player.get_node_or_null("Visual") as Figur
	if figur == null:
		return
	var skelett := figur.skelett_finden()
	if skelett == null or skelett.find_bone("RightHand") < 0:
		return
	var halter := BoneAttachment3D.new()
	halter.bone_name = "RightHand"
	skelett.add_child(halter)
	var strauss := _STRAUSS.instantiate() as Node3D
	halter.add_child(strauss)
	strauss.scale = Vector3.ONE * 0.8
	strauss.position = Vector3(0.0, 0.09, 0.02)
	strauss.rotation = Vector3(0.5, 0.0, 0.25)


# --- Blenden und Bildschirme ---------------------------------------------------


func _blendschicht_bauen() -> void:
	_blendschicht = CanvasLayer.new()
	_blendschicht.layer = 14
	add_child(_blendschicht)
	_blende = ColorRect.new()
	_blende.color = Color(0, 0, 0, 0)
	_blende.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blendschicht.add_child(_blende)


func _film(ort: Vector3, blick: Vector3) -> void:
	_filmkamera.global_position = ort
	_filmkamera.look_at(blick)
	_filmkamera.current = true


func _abblenden(dauer: float) -> void:
	var lauf := create_tween()
	lauf.tween_property(_blende, ^"color:a", 1.0, _wartezeit(dauer))
	await lauf.finished


## Der Geschenkbildschirm — das Ende des Versprechens aus der Widmung.
##
## Bewusst ruhig gebaut: schwarz, drei Zeilen, kein Klang außer der
## Menge, die weit weg weiterfeiert. Er wartet auf einen Tastendruck und
## läuft nicht von selbst weiter — hier soll man lesen können.
func _geschenk_zeigen() -> void:
	await _abblenden(1.4)
	var mitte := VBoxContainer.new()
	mitte.set_anchors_preset(Control.PRESET_FULL_RECT)
	mitte.alignment = BoxContainer.ALIGNMENT_CENTER
	mitte.add_theme_constant_override("separation", 26)
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mitte.modulate.a = 0.0
	_blendschicht.add_child(mitte)

	var titel := Label.new()
	titel.text = HochzeitDialogue.GESCHENK_TITEL
	titel.add_theme_font_size_override("font_size", 58)
	titel.add_theme_color_override("font_color", Color(0.97, 0.93, 0.85))
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(titel)
	for zeile in HochzeitDialogue.GESCHENK_ZEILEN:
		var feld := Label.new()
		feld.text = zeile
		feld.add_theme_font_size_override("font_size", 28)
		feld.add_theme_color_override("font_color", Color(0.80, 0.78, 0.74))
		feld.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feld.custom_minimum_size = Vector2(760, 0)
		mitte.add_child(feld)
	var fuss := Label.new()
	fuss.text = HochzeitDialogue.GESCHENK_FUSS
	fuss.add_theme_font_size_override("font_size", 22)
	fuss.add_theme_color_override("font_color", Color(0.64, 0.62, 0.58))
	fuss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mitte.add_child(fuss)

	var auftritt := create_tween()
	auftritt.tween_property(mitte, ^"modulate:a", 1.0, _wartezeit(1.6))
	await auftritt.finished
	# Warten, bis gelesen wurde — mit großzügiger Frist, falls niemand
	# drückt.
	var uhr := 0.0
	while uhr < _wartezeit(22.0) and not Input.is_anything_pressed():
		uhr += get_process_delta_time()
		await get_tree().process_frame
	var abgang := create_tween()
	abgang.tween_property(mitte, ^"modulate:a", 0.0, _wartezeit(1.0))
	await abgang.finished
	mitte.queue_free()
